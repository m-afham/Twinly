#!/usr/bin/env python3
"""Build Twinly/Resources/franchises.json — the "match within" universes.

For each curated franchise (one or more Wikidata items), collect the cast
(P161) of every work that belongs to it: the item itself (TV series), and
anything linked to it through "part of the series" (P179) or "media
franchise" (P8345), transitively (films in a sub-series, etc.). The cast is
kept only where it intersects tools/cache/celebs/people.json, so the app can
show how many matchable actors each universe has.

    python3 tools/fetch_franchises.py

Stdlib only; queries QLever's Wikidata mirror. Re-run after people.json
changes. The app further filters to actors present in its bundled index.
"""
import json
import time
import urllib.parse
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
PEOPLE = HERE / "cache" / "celebs" / "people.json"
OUT = HERE.parent / "Twinly" / "Resources" / "franchises.json"
UA = "TwinlyDataFetcher/1.0 (non-commercial portfolio app; python-urllib)"

# (id, display name, kind, Wikidata roots)
FRANCHISES = [
    ("harry-potter", "Harry Potter", "Film series", ["Q216930"]),
    ("marvel", "Marvel Cinematic Universe", "Film universe", ["Q642878"]),
    ("star-wars", "Star Wars", "Franchise", ["Q462"]),
    ("middle-earth", "The Lord of the Rings & The Hobbit", "Film series", ["Q190214", "Q74331"]),
    ("james-bond", "James Bond", "Film series", ["Q2484680", "Q26451486"]),
    ("pirates", "Pirates of the Caribbean", "Film series", ["Q194318"]),
    ("fast-furious", "Fast & Furious", "Film series", ["Q1576873"]),
    ("twilight", "The Twilight Saga", "Film series", ["Q652599"]),
    ("hunger-games", "The Hunger Games", "Film series", ["Q11885031"]),
    ("mission-impossible", "Mission: Impossible", "Film series", ["Q1356213"]),
    ("dc", "DC Extended Universe", "Film universe", ["Q18281265"]),
    ("x-men", "X-Men", "Film series", ["Q2006869"]),
    ("jurassic", "Jurassic Park", "Franchise", ["Q2336369"]),
    ("matrix", "The Matrix", "Franchise", ["Q13014087"]),
    ("indiana-jones", "Indiana Jones", "Franchise", ["Q2562640"]),
    ("back-to-the-future", "Back to the Future", "Film series", ["Q91558"]),
    ("game-of-thrones", "Game of Thrones", "TV series", ["Q23572", "Q72930269"]),
    ("friends", "Friends", "TV series", ["Q79784"]),
    ("breaking-bad", "Breaking Bad", "TV series", ["Q1079"]),
    ("stranger-things", "Stranger Things", "TV series", ["Q19798734"]),
    ("big-bang", "The Big Bang Theory", "TV series", ["Q8539"]),
    ("himym", "How I Met Your Mother", "TV series", ["Q147235"]),
    ("the-office", "The Office (US)", "TV series", ["Q23831"]),
    ("greys", "Grey's Anatomy", "TV series", ["Q438406"]),
    ("sherlock", "Sherlock", "TV series", ["Q192837"]),
    ("peaky-blinders", "Peaky Blinders", "TV series", ["Q14944179"]),
    ("the-crown", "The Crown", "TV series", ["Q20707362"]),
    ("downton", "Downton Abbey", "TV series", ["Q83071"]),
    ("the-witcher", "The Witcher", "TV series", ["Q47500433"]),
    ("the-boys", "The Boys", "TV series", ["Q48796994"]),
    ("bridgerton", "Bridgerton", "TV series", ["Q85748936"]),
    ("euphoria", "Euphoria", "TV series", ["Q56275505"]),
    ("squid-game", "Squid Game", "TV series", ["Q106582931"]),
    ("money-heist", "Money Heist", "TV series", ["Q29647346"]),
    ("ertugrul", "Resurrection: Ertuğrul", "TV series", ["Q18338011"]),
    ("dhoom", "Dhoom", "Film series", ["Q5269743"]),
    ("krrish", "Krrish", "Film series", ["Q6439144"]),
]


def cast_of(roots):
    values = " ".join(f"wd:{q}" for q in roots)
    q = f"""
    PREFIX wd: <http://www.wikidata.org/entity/>
    PREFIX wdt: <http://www.wikidata.org/prop/direct/>
    SELECT DISTINCT ?a WHERE {{
      VALUES ?root {{ {values} }}
      ?w (wdt:P179|wdt:P8345)* ?root .
      ?w wdt:P161 ?a .
    }}"""
    req = urllib.request.Request(
        "https://qlever.dev/api/wikidata?query=" + urllib.parse.quote(q),
        headers={"User-Agent": UA, "Accept": "application/sparql-results+json"})
    with urllib.request.urlopen(req, timeout=180) as r:
        rows = json.loads(r.read())["results"]["bindings"]
    return {b["a"]["value"].rsplit("/", 1)[1] for b in rows}


def main():
    known = {p["id"] for p in json.loads(PEOPLE.read_text())}
    out = []
    for fid, name, kind, roots in FRANCHISES:
        cast = cast_of(roots)
        actors = sorted(cast & known)
        print(f"{name:38} cast {len(cast):5}  in our set {len(actors):4}")
        if len(actors) >= 5:
            out.append({"id": fid, "name": name, "kind": kind, "actors": actors})
        time.sleep(0.5)
    OUT.write_text(json.dumps(out, indent=1, ensure_ascii=False))
    print(f"DONE: {len(out)} franchises → {OUT}")


if __name__ == "__main__":
    main()
