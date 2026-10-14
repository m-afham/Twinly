#!/usr/bin/env python3
"""Fetch the reference set: movie actors worldwide, from Wikidata + Commons.

Queries Wikidata (via the QLever mirror) for every actor / film actor born
after 1925 who has a portrait (P18) and articles in at least MIN_SITELINKS
Wikipedia language editions (fame proxy that also reaches national film
industries), pulls licence / author metadata for each portrait, and
downloads a 500px thumbnail (file metadata via en.wikipedia.org's API).

Outputs (everything resumable — cached metadata and existing files are reused):

    tools/cache/celebs/people.json     the query result (frozen; reused offline)
    tools/cache/celebs/metadata.json   Commons file metadata cache
    tools/cache/celebs/raw/<QID>.jpg   portraits
    tools/cache/celebs/manifest.json   ready entries; checkpointed while downloading

    python3 tools/fetch_celebs.py              # full run (hours; rate-limited)
    python3 tools/fetch_celebs.py --requery    # refresh people.json first
    python3 tools/fetch_celebs.py --offline    # manifest from what's on disk

Stdlib only. tools/build_index.sh turns the manifest into the app bundle.
"""
import json
import re
import sys
import time
import html
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent / "cache" / "celebs"
RAW = ROOT / "raw"
UA = "TwinlyDataFetcher/1.0 (non-commercial portfolio app; python-urllib)"
MIN_SITELINKS = 10
# Keep the most famous N (people.json is sorted by sitelinks, so this is a
# fame cut). 10k keeps the download to a few hours under Wikimedia's limits.
MAX_PEOPLE = 10_000
OFFLINE = "--offline" in sys.argv
REQUERY = "--requery" in sys.argv
FREE = re.compile(r"^(cc0|cc[ -]by|public domain|pd|attribution|gfdl|fal)", re.I)
# Wikidata tags anyone with a film cameo as "actor" (popes, heads of state,
# musicians, athletes). Their English description is the reliable tell.
SCREEN = re.compile(r"\b(actor|actress|actors|film|films|cinema|movie|filmmaker|entertainer|"
                    r"comedian|comedienne|performer|voice artist|dubbing)\b", re.I)


def get(url, tries=6):
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code in (400, 404):
                break  # won't change on retry (e.g. a thumb wider than its original)
            if e.code == 429:
                # Rate limited: honour Retry-After, and otherwise back off for
                # a full minute (growing) rather than retrying within seconds.
                retry_after = e.headers.get("Retry-After", "")
                wait = int(retry_after) if retry_after.isdigit() else 60 * (i + 1)
            else:
                wait = 2 ** i
            print(f"  retry {i + 1} in {wait}s: HTTP {e.code}", file=sys.stderr)
            time.sleep(wait)
        except Exception as e:  # timeouts, DNS blips
            wait = 2 ** i
            print(f"  retry {i + 1} in {wait}s: {e}", file=sys.stderr)
            time.sleep(wait)
    raise RuntimeError(f"giving up on {url}")


def query_people():
    # QLever's mirror: query.wikidata.org times out on whole-occupation
    # rankings. One row per person (GROUP BY + SAMPLE). Politicians are
    # dropped unless they're tagged *film actor* — that keeps star-politicians
    # (Bachchan, Reagan, Schwarzenegger) but not people Wikidata merely tags
    # "actor".
    q = f"""
    PREFIX wd: <http://www.wikidata.org/entity/>
    PREFIX wdt: <http://www.wikidata.org/prop/direct/>
    PREFIX wikibase: <http://wikiba.se/ontology#>
    PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
    PREFIX schema: <http://schema.org/>
    SELECT ?p (SAMPLE(?l) AS ?name) (SAMPLE(?d) AS ?desc) (SAMPLE(?i) AS ?img) (MAX(?links) AS ?sl) WHERE {{
      VALUES ?occ {{ wd:Q33999 wd:Q10800557 }}
      ?p wdt:P106 ?occ ; wdt:P31 wd:Q5 ; wdt:P18 ?i ; wikibase:sitelinks ?links ; wdt:P569 ?dob .
      # One combined FILTER: QLever returns nothing for VALUES + a lone
      # sitelinks FILTER (engine quirk), but handles the conjunction.
      FILTER(?links >= {MIN_SITELINKS} && YEAR(?dob) > 1925)
      FILTER NOT EXISTS {{ ?p wdt:P106 wd:Q82955 . FILTER NOT EXISTS {{ ?p wdt:P106 wd:Q10800557 }} }}
      ?p rdfs:label ?l . FILTER(LANG(?l) = "en")
      OPTIONAL {{ ?p schema:description ?d . FILTER(LANG(?d) = "en") }}
    }} GROUP BY ?p ORDER BY DESC(?sl)"""
    req = urllib.request.Request(
        "https://qlever.dev/api/wikidata?query=" + urllib.parse.quote(q),
        headers={"User-Agent": UA, "Accept": "application/sparql-results+json"})
    with urllib.request.urlopen(req, timeout=300) as r:
        rows = json.loads(r.read())["results"]["bindings"]

    people, seen_files = [], set()
    for b in rows:
        name = b.get("name", {}).get("value", "")
        file = urllib.parse.unquote(b["img"]["value"].rsplit("/", 1)[1])
        # A portrait shared by two people is a duo shot: keep the more famous.
        desc = b.get("desc", {}).get("value", "")
        if not name or re.fullmatch(r"Q\d+", name) or file in seen_files:
            continue
        if desc and not SCREEN.search(desc):
            continue
        seen_files.add(file)
        people.append({
            "id": b["p"]["value"].rsplit("/", 1)[1],
            "name": name,
            "description": desc,
            "occupation": "Actor",
            "sitelinks": int(b["sl"]["value"]),
            "file": file,
        })
    return people


def strip_html(s):
    return html.unescape(re.sub(r"<[^>]+>", "", s or "")).strip()


def fetch_metadata(people):
    """Commons file metadata, 50 files per request, cached in metadata.json.
    Asked via en.wikipedia's API (it serves Commons files too) because
    commons.wikimedia.org is unreachable from some networks."""
    cache = ROOT / "metadata.json"
    by_title = json.loads(cache.read_text()) if cache.exists() else {}
    todo = [p for p in people if p["file"].replace("_", " ") not in by_title]
    print(f"metadata: {len(people) - len(todo)} cached, {len(todo)} to fetch")
    for i in range(0, len(todo), 50):
        chunk = todo[i : i + 50]
        params = urllib.parse.urlencode({
            "action": "query", "format": "json", "prop": "imageinfo",
            "iiprop": "url|extmetadata", "iiurlwidth": 500,
            "iiextmetadatafilter": "LicenseShortName|Artist|LicenseUrl",
            "titles": "|".join("File:" + p["file"] for p in chunk),
        })
        data = json.loads(get("https://en.wikipedia.org/w/api.php?" + params))["query"]
        norm = {n["to"]: n["from"] for n in data.get("normalized", [])}
        for page in data["pages"].values():
            if "imageinfo" not in page:
                continue
            info = page["imageinfo"][0]
            meta = info.get("extmetadata") or {}
            if not isinstance(meta, dict):
                meta = {}
            title = norm.get(page["title"], page["title"])
            by_title[title[5:].replace("_", " ")] = {
                "thumb": info.get("thumburl") or info["url"],
                "source": info.get("descriptionurl", ""),
                "license": strip_html(meta.get("LicenseShortName", {}).get("value")),
                "licenseUrl": meta.get("LicenseUrl", {}).get("value", ""),
                "artist": strip_html(meta.get("Artist", {}).get("value"))[:120],
            }
        if (i // 50) % 10 == 0 or i + 50 >= len(todo):
            cache.write_text(json.dumps(by_title))
            print(f"  metadata {min(i + 50, len(todo))}/{len(todo)}")
        time.sleep(1.5)
    return by_title


def write_manifest(manifest):
    (ROOT / "manifest.json").write_text(json.dumps(manifest, indent=1, ensure_ascii=False))


def candidates(url):
    """Standard-size thumbnail URLs first, the original file last.

    When a file is narrower than 500 px the API hands back the original
    ("thumbnail_unscaled"), and Wikimedia throttles original-file downloads far
    harder than thumbnails in its standard sizes (https://w.wiki/GHai).
    """
    if "unscaled" not in url:
        return [url]
    base = url.split("?")[0]
    head, _, name = base.partition("/wikipedia/commons/")
    if not name:
        return [base]
    thumbs = [f"{head}/wikipedia/commons/thumb/{name}/{w}px-{name.rsplit('/', 1)[-1]}"
              for w in (330, 250)]
    return thumbs + [base]


def download(url):
    for candidate in candidates(url):
        try:
            return get(candidate, tries=5)
        except RuntimeError:
            last = candidate
    raise RuntimeError(f"giving up on {last}")


def main():
    RAW.mkdir(parents=True, exist_ok=True)
    people_file = ROOT / "people.json"
    if REQUERY or not people_file.exists():
        people = query_people()
        people_file.write_text(json.dumps(people, ensure_ascii=False))
    people = json.loads(people_file.read_text())[:MAX_PEOPLE]
    print(f"{len(people)} actors (≥{MIN_SITELINKS} language editions, top {MAX_PEOPLE:,} by fame)")

    by_title = fetch_metadata(people)

    manifest, downloaded = [], 0
    for n, p in enumerate(people):
        meta = by_title.get(p["file"].replace("_", " "))
        if not meta or not FREE.match(meta["license"]):
            continue
        out = RAW / f"{p['id']}.jpg"
        if not out.exists():
            if OFFLINE:
                continue
            try:
                out.write_bytes(download(meta["thumb"]))
                downloaded += 1
                time.sleep(2.5)  # polite steady pace; Wikimedia rate-limits bursts (HTTP 429)
            except RuntimeError as e:
                print(f"  skip {p['name']}: {e}", file=sys.stderr)
                continue
        manifest.append({**p, **meta})
        if n % 250 == 0:
            write_manifest(manifest)   # checkpoint: interim indexes can use it
            print(f"  images {n}/{len(people)} ready {len(manifest)} (new {downloaded})")

    write_manifest(manifest)
    print(f"DONE: {len(manifest)} actors → {ROOT / 'manifest.json'}")


if __name__ == "__main__":
    main()
