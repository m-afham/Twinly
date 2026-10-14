// CelebrityIndex — the bundled reference set: celebrity metadata
// (celebs.json) plus a row-major Float32 matrix of their face embeddings
// (embeddings.bin). Search is a single matrix–vector product (cosine
// similarity on unit vectors), then a top-k. Also maps raw similarity to the
// friendly "% match" using the similarity distribution measured at index
// time. Face crops live in one packed file, faces.pack.

import Accelerate
import Foundation

struct Celebrity: Codable, Identifiable, Hashable, Sendable {
    let id: String          // Wikidata QID
    let name: String
    let description: String
    let occupation: String
    let license: String
    let licenseUrl: String
    let artist: String
    let source: String      // Commons file page
}

struct IndexManifest: Codable, Sendable {
    let dimension: Int
    let celebrities: [Celebrity]
    /// 101 ascending quantiles of each celebrity's best match among the
    /// *other* celebrities — the reference for what a "good" lookalike is.
    let quantiles: [Float]
    /// [offset, length] of each celebrity's JPEG face crop in faces.pack
    /// (parallel to `celebrities`). One packed file instead of tens of
    /// thousands of loose ones keeps installs and App Store processing fast.
    let faceRanges: [[Int]]
}

struct Match: Identifiable, Hashable, Sendable {
    let celebrity: Celebrity
    let similarity: Float
    let percent: Int
    var id: String { celebrity.id }
}

final class CelebrityIndex: @unchecked Sendable {
    let manifest: IndexManifest
    private let matrix: [Float]

    var celebrities: [Celebrity] { manifest.celebrities }

    init(manifestURL: URL, embeddingsURL: URL) throws {
        manifest = try JSONDecoder().decode(IndexManifest.self, from: Data(contentsOf: manifestURL))
        let data = try Data(contentsOf: embeddingsURL)
        matrix = data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        precondition(matrix.count == manifest.celebrities.count * manifest.dimension, "index size mismatch")
    }

    /// Top-k celebrities for an embedding. `rows` limits the search to those
    /// index positions (e.g. one franchise's cast); nil searches everyone.
    func search(_ query: [Float], k: Int = 5, among rows: [Int]? = nil) -> [Match] {
        let n = manifest.celebrities.count, d = manifest.dimension
        var scores = [Float](repeating: 0, count: n)
        vDSP_mmul(matrix, 1, query, 1, &scores, 1, vDSP_Length(n), 1, vDSP_Length(d))
        return (rows ?? Array(scores.indices))
            .sorted { scores[$0] > scores[$1] }
            .prefix(k)
            .map { Match(celebrity: manifest.celebrities[$0], similarity: scores[$0],
                         percent: Self.percent(for: scores[$0], quantiles: manifest.quantiles)) }
    }

    /// 64–99% across the observed range of real lookalike pairs, tapering
    /// below it. Monotonic, so ranking is never contradicted by the number.
    static func percent(for s: Float, quantiles q: [Float]) -> Int {
        guard let lo = q.first, let hi = q.last, hi > lo else { return Int(max(0, s) * 100) }
        if s <= lo { return Int((40 + 24 * max(0, s) / max(lo, 0.01)).rounded()) }
        if s >= hi { return 99 }
        let i = q.lastIndex { $0 <= s } ?? 0
        let span = q[i + 1] - q[i]
        let rank = (Float(i) + (span > 0 ? (s - q[i]) / span : 0)) / Float(q.count - 1)
        return Int((64 + 35 * rank).rounded())
    }
}
