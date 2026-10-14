// FaceAligner — finds the main face in an image and warps it onto the
// canonical ArcFace 112×112 five-point template (eyes, nose tip, mouth
// corners). Shared verbatim by the app and the macOS indexer, so the
// celebrity embeddings and the user's selfie go through identical geometry.
// Platform-neutral: Vision + CoreGraphics only.

import CoreGraphics
import CoreML
import Foundation
import Vision

struct DetectedFace: Sendable {
    /// Face bounds in image pixels, top-left origin.
    let bounds: CGRect
    /// Left eye, right eye, nose tip, left mouth, right mouth — image pixels,
    /// top-left origin, "left" meaning the left of the image.
    let landmarks: [CGPoint]
    /// Head turn in radians (0 = facing camera), if Vision reported it.
    let yaw: Double
    let roll: Double
}

enum FaceError: Error, Sendable {
    case noFace
    case faceTooSmall
    case ambiguous      // several faces of similar size
    case landmarksMissing
    case engineUnavailable  // model / celebrity index missing from the bundle
}

enum FaceAligner {
    static let outputSize = 112

    /// ArcFace reference landmarks for a 112×112 crop.
    static let template: [CGPoint] = [
        CGPoint(x: 38.2946, y: 51.6963), CGPoint(x: 73.5318, y: 51.5014),
        CGPoint(x: 56.0252, y: 71.7366),
        CGPoint(x: 41.5493, y: 92.3655), CGPoint(x: 70.7299, y: 92.2041),
    ]

    /// Detects the largest face. `strict` rejects group shots where a second
    /// face is nearly as large (used when indexing, where the wrong person
    /// would poison the reference set).
    static func detect(in image: CGImage, minSide: CGFloat = 48, strict: Bool = false) throws -> DetectedFace {
        let request = VNDetectFaceLandmarksRequest()
        pinToCPUInSimulator(request)
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        let w = CGFloat(image.width), h = CGFloat(image.height)
        let faces = (request.results ?? []).sorted {
            $0.boundingBox.width * $0.boundingBox.height > $1.boundingBox.width * $1.boundingBox.height
        }
        guard let face = faces.first else { throw FaceError.noFace }
        if strict, faces.count > 1 {
            let a0 = face.boundingBox.width * face.boundingBox.height
            let a1 = faces[1].boundingBox.width * faces[1].boundingBox.height
            if a1 > a0 * 0.5 { throw FaceError.ambiguous }
        }

        let bb = face.boundingBox
        let bounds = CGRect(x: bb.minX * w, y: (1 - bb.maxY) * h, width: bb.width * w, height: bb.height * h)
        guard min(bounds.width, bounds.height) >= minSide else { throw FaceError.faceTooSmall }

        guard let lm = face.landmarks,
              let lp = lm.leftPupil, let rp = lm.rightPupil,
              let lips = lm.outerLips, let crest = lm.noseCrest
        else { throw FaceError.landmarksMissing }

        let size = CGSize(width: w, height: h)
        func pts(_ r: VNFaceLandmarkRegion2D) -> [CGPoint] {
            r.pointsInImage(imageSize: size).map { CGPoint(x: $0.x, y: h - $0.y) }
        }
        guard let p1 = pts(lp).first, let p2 = pts(rp).first,
              let tip = pts(crest).max(by: { $0.y < $1.y })
        else { throw FaceError.landmarksMissing }
        let lipPts = pts(lips)
        guard let ml = lipPts.min(by: { $0.x < $1.x }), let mr = lipPts.max(by: { $0.x < $1.x })
        else { throw FaceError.landmarksMissing }

        let eyes = p1.x < p2.x ? [p1, p2] : [p2, p1]
        return DetectedFace(
            bounds: bounds,
            landmarks: [eyes[0], eyes[1], tip, ml, mr],
            yaw: face.yaw?.doubleValue ?? 0,
            roll: face.roll?.doubleValue ?? 0
        )
    }

    /// The iOS Simulator can't create Vision's GPU/ANE inference context
    /// ("Could not create inference context", code 9); devices are unaffected.
    static func pinToCPUInSimulator(_ request: VNRequest) {
        #if targetEnvironment(simulator)
        let cpu = MLComputeDevice.allComputeDevices.first { if case .cpu = $0 { true } else { false } }
        if let cpu { request.setComputeDevice(cpu, for: .main) }
        #endif
    }

    /// Least-squares similarity transform (rotation + uniform scale +
    /// translation) taking `src` onto `dst`.
    static func similarity(from src: [CGPoint], to dst: [CGPoint]) -> CGAffineTransform {
        let n = CGFloat(src.count)
        let sm = src.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x / n, y: $0.y + $1.y / n) }
        let dm = dst.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x / n, y: $0.y + $1.y / n) }
        var num1: CGFloat = 0, num2: CGFloat = 0, den: CGFloat = 0
        for (s, d) in zip(src, dst) {
            let sx = s.x - sm.x, sy = s.y - sm.y, dx = d.x - dm.x, dy = d.y - dm.y
            num1 += sx * dx + sy * dy
            num2 += sx * dy - sy * dx
            den += sx * sx + sy * sy
        }
        let a = num1 / den, b = num2 / den
        let tx = dm.x - (a * sm.x - b * sm.y)
        let ty = dm.y - (b * sm.x + a * sm.y)
        // x' = a·x − b·y + tx ;  y' = b·x + a·y + ty
        return CGAffineTransform(a: a, b: b, c: -b, d: a, tx: tx, ty: ty)
    }

    /// Renders the aligned 112×112 face (optionally mirrored for test-time
    /// flip augmentation).
    static func align(_ image: CGImage, face: DetectedFace, mirrored: Bool = false) -> CGImage? {
        let s = outputSize
        guard let ctx = CGContext(
            data: nil, width: s, height: s, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .high
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))

        // Work in a top-left output space.
        ctx.translateBy(x: 0, y: CGFloat(s))
        ctx.scaleBy(x: 1, y: -1)
        if mirrored {
            ctx.translateBy(x: CGFloat(s), y: 0)
            ctx.scaleBy(x: -1, y: 1)
        }
        ctx.concatenate(similarity(from: face.landmarks, to: template))
        // Draw the image so its top row sits at image-space y = 0.
        let h = CGFloat(image.height)
        ctx.translateBy(x: 0, y: h)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(image.width), height: h))
        return ctx.makeImage()
    }

    /// A square portrait crop around the face (with room for hair), used for
    /// display rather than recognition.
    static func portraitCrop(_ image: CGImage, face: DetectedFace, side: Int) -> CGImage? {
        let w = CGFloat(image.width), h = CGFloat(image.height)
        var edge = max(face.bounds.width, face.bounds.height) * 1.9
        edge = min(edge, w, h)
        var rect = CGRect(x: face.bounds.midX - edge / 2, y: face.bounds.midY - edge * 0.55,
                          width: edge, height: edge)
        rect.origin.x = min(max(0, rect.origin.x), w - edge)
        rect.origin.y = min(max(0, rect.origin.y), h - edge)
        guard let cropped = image.cropping(to: rect.integral) else { return nil }
        guard let ctx = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: side, height: side))
        return ctx.makeImage()
    }
}
