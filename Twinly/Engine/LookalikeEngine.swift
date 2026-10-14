// LookalikeEngine — the app-side entry point to the face pipeline: photo →
// largest face → ArcFace embedding → nearest celebrities, optionally limited
// to chosen universes (franchise casts). Everything runs on-device; nothing
// is stored or sent. Also vends bundled celebrity face crops (cached).

import CoreGraphics
import Foundation
import UIKit

struct LookalikeResult: Identifiable, Sendable {
    let id = UUID()
    /// Square crop of the user's face, for display.
    let selfie: UIImage
    /// The user's face embedding, kept so changing universes re-ranks
    /// instantly without re-analysing the photo.
    let embedding: [Float]
    /// Best first.
    let matches: [Match]
}

/// A franchise ("universe") the user can limit matching to, resolved to the
/// index rows of its cast that are in this build.
struct Universe: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let kind: String          // "Film series", "TV series", …
    /// Index rows, ascending — so the first few are the most famous.
    let rows: [Int]
}

private struct FranchiseRecord: Decodable {
    let id, name, kind: String
    let actors: [String]
}

final class LookalikeEngine: @unchecked Sendable {
    let index: CelebrityIndex
    private let encoder: FaceEncoder
    private let faceCache = NSCache<NSString, UIImage>()
    /// Memory-mapped faces.pack + where each celebrity's JPEG sits in it.
    private let facePack: Data
    private let faceRange: [String: Range<Int>]

    /// Universes with enough of their cast in this build to be worth offering.
    let universes: [Universe]

    var celebrityCount: Int { index.celebrities.count }

    init() throws {
        guard let modelURL = Bundle.main.url(forResource: "FaceEmbedder", withExtension: "mlmodelc"),
              let celebs = Bundle.main.url(forResource: "Celebs", withExtension: nil)
        else { throw CocoaError(.fileNoSuchFile) }
        encoder = try FaceEncoder(compiledModelURL: modelURL)
        index = try CelebrityIndex(manifestURL: celebs.appendingPathComponent("celebs.json"),
                                   embeddingsURL: celebs.appendingPathComponent("embeddings.bin"))
        facePack = try Data(contentsOf: celebs.appendingPathComponent("faces.pack"), options: .alwaysMapped)
        faceRange = Dictionary(uniqueKeysWithValues: zip(
            index.celebrities.map(\.id),
            index.manifest.faceRanges.map { $0[0] ..< $0[0] + $0[1] }))
        faceCache.countLimit = 400

        let rowOf = Dictionary(uniqueKeysWithValues: index.celebrities.enumerated().map { ($1.id, $0) })
        let records = (Bundle.main.url(forResource: "franchises", withExtension: "json"))
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode([FranchiseRecord].self, from: $0) } ?? []
        universes = records
            .map { Universe(id: $0.id, name: $0.name, kind: $0.kind,
                            rows: $0.actors.compactMap { rowOf[$0] }.sorted()) }
            .filter { $0.rows.count >= 5 }
            .sorted { $0.rows.count > $1.rows.count }
    }

    /// Index rows to search for a scope; nil means everyone. Unknown or
    /// unavailable universe ids are ignored (an all-unknown scope = everyone).
    func rows(for scope: Set<String>) -> [Int]? {
        let chosen = universes.filter { scope.contains($0.id) }
        guard !chosen.isEmpty else { return nil }
        return Array(Set(chosen.flatMap(\.rows))).sorted()
    }

    func candidateCount(for scope: Set<String>) -> Int {
        rows(for: scope)?.count ?? celebrityCount
    }

    func matches(for embedding: [Float], scope: Set<String>) -> [Match] {
        index.search(embedding, k: 6, among: rows(for: scope))
    }

    func analyze(_ photo: UIImage, scope: Set<String> = []) throws -> LookalikeResult {
        guard let image = Self.upright(photo, maxSide: 1600) else { throw FaceError.noFace }
        let face = try FaceAligner.detect(in: image, minSide: 40)
        let embedding = try encoder.embedding(of: image, face: face)
        #if DEBUG
        NSLog("Twinly: %dx%d bpc=%d landmarks=%@", image.width, image.height, image.bitsPerComponent,
              face.landmarks.map { "(\(Int($0.x)),\(Int($0.y)))" }.joined(separator: " "))
        #endif
        let crop = FaceAligner.portraitCrop(image, face: face, side: 600).map { UIImage(cgImage: $0) } ?? photo
        let matches = matches(for: embedding, scope: scope)
        #if DEBUG
        NSLog("Twinly: top %@", matches.prefix(3).map { "\($0.celebrity.name) \($0.similarity)" }.joined(separator: ", "))
        #endif
        return LookalikeResult(selfie: crop, embedding: embedding, matches: matches)
    }

    func face(for celebrity: Celebrity) -> UIImage? {
        let key = celebrity.id as NSString
        if let hit = faceCache.object(forKey: key) { return hit }
        guard let range = faceRange[celebrity.id],
              let image = UIImage(data: facePack.subdata(in: range)) else { return nil }
        faceCache.setObject(image, forKey: key)
        return image
    }

    /// Bakes orientation in and caps resolution (Vision is fast either way,
    /// but there's no benefit past ~1600px for a face).
    static func upright(_ image: UIImage, maxSide: CGFloat) -> CGImage? {
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format)
            .image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            .cgImage
    }
}

extension FaceError {
    var title: String {
        switch self {
        case .noFace, .landmarksMissing: "We couldn't spot a face"
        case .faceTooSmall: "Your face is too small"
        case .ambiguous: "Too many faces"
        case .engineUnavailable: "Celebrity faces not installed"
        }
    }

    var tip: String {
        switch self {
        case .noFace, .landmarksMissing: "Face the camera in good light, with nothing covering your eyes or mouth."
        case .faceTooSmall: "Move closer, or pick a photo where your face fills more of the frame."
        case .ambiguous: "Pick a photo with just you in it."
        case .engineUnavailable: "This build is missing Twinly's face data. Reinstall the latest build."
        }
    }
}
