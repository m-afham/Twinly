// Twinly indexer (macOS CLI) — turns tools/cache/celebs (from fetch_celebs.py)
// into the app's bundled reference set, using the *same* FaceAligner +
// FaceEncoder sources the app compiles, so embeddings are directly comparable.
//
//   tools/build_index.sh
//
// Writes Twinly/Resources/Celebs/{celebs.json, embeddings.bin, faces.pack}.

import Accelerate
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct RawEntry: Decodable {
    let id, name, description, occupation, license, licenseUrl, artist, source: String
}

let args = CommandLine.arguments
let repo = URL(fileURLWithPath: args.count > 1 ? args[1] : FileManager.default.currentDirectoryPath)
let cache = repo.appendingPathComponent("tools/cache")
let out = repo.appendingPathComponent("Twinly/Resources/Celebs")
try? FileManager.default.removeItem(at: out)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let packURL = out.appendingPathComponent("faces.pack")
FileManager.default.createFile(atPath: packURL.path, contents: nil)
let pack = try FileHandle(forWritingTo: packURL)
var packOffset = 0
var faceRanges: [[Int]] = []

let encoder = try FaceEncoder(compiledModelURL: cache.appendingPathComponent("FaceEmbedder.mlmodelc"))
let entries = try JSONDecoder().decode(
    [RawEntry].self, from: Data(contentsOf: cache.appendingPathComponent("celebs/manifest.json")))

func load(_ url: URL) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    let opts: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: 1000,
    ]
    return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
}

func jpegData(_ image: CGImage) -> Data? {
    let data = NSMutableData()
    guard let dst = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)
    else { return nil }
    CGImageDestinationAddImage(dst, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
    return CGImageDestinationFinalize(dst) ? data as Data : nil
}

var kept: [Celebrity] = []
var matrix: [Float] = []
var rejected: [String: Int] = [:]

for (i, e) in entries.enumerated() {
    let raw = cache.appendingPathComponent("celebs/raw/\(e.id).jpg")
    guard let image = load(raw) else { rejected["unreadable", default: 0] += 1; continue }
    do {
        let face = try FaceAligner.detect(in: image, minSide: 60, strict: true)
        // Vision reports yaw in 45° steps: keep ¾ views, drop true profiles.
        guard abs(face.yaw) < 1.0 else { rejected["profile", default: 0] += 1; continue }
        let emb = try encoder.embedding(of: image, face: face)
        guard let crop = FaceAligner.portraitCrop(image, face: face, side: 256),
              let jpeg = jpegData(crop) else { continue }
        pack.write(jpeg)
        faceRanges.append([packOffset, jpeg.count])
        packOffset += jpeg.count
        kept.append(Celebrity(id: e.id, name: e.name, description: e.description, occupation: e.occupation,
                              license: e.license, licenseUrl: e.licenseUrl, artist: e.artist, source: e.source))
        matrix += emb
    } catch {
        rejected["\(error)", default: 0] += 1
    }
    if i % 1000 == 0 { print("  \(i)/\(entries.count) kept \(kept.count)") }
}
try pack.close()

// Leave-one-out best-match distribution → quantiles for the % mapping.
// Blocked so the n×n similarity matrix never exists in full (n² floats is
// gigabytes at tens of thousands of people).
let n = kept.count, d = FaceEncoder.dimension
let matrixT = transposed(matrix, n, d)
let blockRows = 1024
var best = [Float](repeating: -1, count: n)
var suspicious: [(String, String, Float)] = []
var sims = [Float](repeating: 0, count: blockRows * n)
for start in stride(from: 0, to: n, by: blockRows) {
    let rows = min(blockRows, n - start)
    matrix.withUnsafeBufferPointer { m in
        vDSP_mmul(m.baseAddress! + start * d, 1, matrixT, 1, &sims, 1,
                  vDSP_Length(rows), vDSP_Length(n), vDSP_Length(d))
    }
    for r in 0..<rows {
        let row = start + r
        for c in 0..<n where c != row {
            let s = sims[r * n + c]
            if s > best[row] { best[row] = s }
            if c > row, s > 0.6 { suspicious.append((kept[row].name, kept[c].name, s)) }
        }
    }
}
best.sort()
let quantiles = (0...100).map { best[min(n - 1, Int(Float($0) / 100 * Float(n - 1)))] }

func transposed(_ m: [Float], _ rows: Int, _ cols: Int) -> [Float] {
    var t = [Float](repeating: 0, count: m.count)
    vDSP_mtrans(m, 1, &t, 1, vDSP_Length(cols), vDSP_Length(rows))
    return t
}

let manifest = IndexManifest(dimension: d, celebrities: kept, quantiles: quantiles, faceRanges: faceRanges)
let enc = JSONEncoder()
enc.outputFormatting = [.sortedKeys]
try enc.encode(manifest).write(to: out.appendingPathComponent("celebs.json"))
try matrix.withUnsafeBufferPointer { Data(buffer: $0) }.write(to: out.appendingPathComponent("embeddings.bin"))

print("kept \(n)/\(entries.count); rejected: \(rejected)")
print(String(format: "best-match similarity  p5 %.3f  p50 %.3f  p95 %.3f  max %.3f",
             quantiles[5], quantiles[50], quantiles[95], quantiles[100]))
for (a, b, s) in suspicious.prefix(20) { print(String(format: "  near-duplicate? %.3f  %@ ↔ %@", s, a, b)) }
