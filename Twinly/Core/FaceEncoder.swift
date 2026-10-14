// FaceEncoder — runs the ArcFace MobileFaceNet Core ML model on an aligned
// 112×112 face and returns an L2-normalised 512-d embedding. Uses flip
// test-time augmentation (embedding + mirrored embedding) for stability.
// Loads the compiled model by URL so the app and the indexer share it.

import CoreGraphics
import CoreML
import Foundation

final class FaceEncoder: @unchecked Sendable {
    static let dimension = 512
    private let model: MLModel
    private let constraint: MLImageConstraint

    init(compiledModelURL url: URL, computeUnits: MLComputeUnits = .all) throws {
        let config = MLModelConfiguration()
        #if targetEnvironment(simulator)
        config.computeUnits = .cpuOnly
        #else
        config.computeUnits = computeUnits
        #endif
        model = try MLModel(contentsOf: url, configuration: config)
        constraint = model.modelDescription.inputDescriptionsByName["face"]!.imageConstraint!
    }

    func embedding(of image: CGImage, face: DetectedFace) throws -> [Float] {
        guard let a = FaceAligner.align(image, face: face),
              let b = FaceAligner.align(image, face: face, mirrored: true)
        else { throw FaceError.landmarksMissing }
        let e1 = try raw(a), e2 = try raw(b)
        var sum = zip(e1, e2).map(+)
        let norm = sqrt(sum.reduce(0) { $0 + $1 * $1 })
        if norm > 0 { sum = sum.map { $0 / norm } }
        return sum
    }

    private func raw(_ aligned: CGImage) throws -> [Float] {
        let value = try MLFeatureValue(cgImage: aligned, constraint: constraint, options: nil)
        let input = try MLDictionaryFeatureProvider(dictionary: ["face": value])
        let out = try model.prediction(from: input)
        guard let array = out.featureValue(for: "embedding")?.multiArrayValue else {
            throw FaceError.landmarksMissing
        }
        return (0..<array.count).map { array[$0].floatValue }
    }
}
