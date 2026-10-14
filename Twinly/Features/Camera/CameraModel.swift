// CameraModel — front-camera session plus live face guidance. Frames arrive
// upright and mirrored (like the preview); every few frames Vision checks
// size, centring and head pose, and once the face has been "good" for a
// short hold the model auto-captures that frame. No photo output needed.

import AVFoundation
import CoreImage
import Observation
import UIKit
import Vision

@MainActor
@Observable
final class CameraModel {
    enum Availability { case unknown, ready, denied, unavailable }

    enum Guidance: Equatable {
        case searching, closer, farther, center, straight, hold

        var text: String {
            switch self {
            case .searching: "Fit your face in the oval"
            case .closer: "Move a little closer"
            case .farther: "Move back a bit"
            case .center: "Center your face"
            case .straight: "Look straight ahead"
            case .hold: "Perfect, hold still"
            }
        }
    }

    private(set) var availability: Availability = .unknown
    private(set) var guidance: Guidance = .searching
    /// 0…1 while the face is held in a good position; capture fires at 1.
    private(set) var holdProgress: Double = 0

    let session = AVCaptureSession()
    @ObservationIgnored var onCapture: ((UIImage) -> Void)?
    @ObservationIgnored private let processor = FrameProcessor()
    @ObservationIgnored private var holdStart: Date?
    @ObservationIgnored private var captured = false

    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { availability = .denied; return }
        default:
            availability = .denied; return
        }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device)
        else { availability = .unavailable; return }

        processor.onGuidance = { [weak self] g in Task { @MainActor in self?.update(g) } }
        let session = session
        let processor = processor
        await Task.detached {
            session.beginConfiguration()
            session.sessionPreset = .hd1920x1080
            if session.canAddInput(input) { session.addInput(input) }
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(processor, queue: processor.queue)
            if session.canAddOutput(output) { session.addOutput(output) }
            if let c = output.connection(with: .video) {
                if c.isVideoRotationAngleSupported(90) { c.videoRotationAngle = 90 }
                if c.isVideoMirroringSupported { c.isVideoMirrored = true }
            }
            session.commitConfiguration()
            session.startRunning()
        }.value
        availability = .ready
    }

    func stop() {
        let session = session
        Task.detached { session.stopRunning() }
    }

    func capture() {
        guard !captured, let image = processor.latestImage() else { return }
        captured = true
        Haptics.thump(1)
        onCapture?(image)
    }

    private func update(_ g: Guidance) {
        guard !captured else { return }
        if g != guidance {
            if g == .hold { Haptics.tick() }
            guidance = g
        }
        if g == .hold {
            let start = holdStart ?? Date()
            holdStart = start
            holdProgress = min(1, Date().timeIntervalSince(start) / 1.1)
            if holdProgress >= 1 { capture() }
        } else {
            holdStart = nil
            holdProgress = 0
        }
    }
}

/// Runs on the capture queue: keeps the latest frame and evaluates guidance.
private final class FrameProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let queue = DispatchQueue(label: "twinly.camera.frames")
    var onGuidance: ((CameraModel.Guidance) -> Void)?
    private var latest: CVPixelBuffer?
    private var frame = 0
    private let lock = NSLock()
    private let context = CIContext()

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lock.withLock { latest = buffer }
        frame += 1
        guard frame % 3 == 0 else { return }

        let request = VNDetectFaceRectanglesRequest()
        try? VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up).perform([request])
        onGuidance?(Self.evaluate(request.results ?? []))
    }

    func latestImage() -> UIImage? {
        guard let buffer = lock.withLock({ latest }),
              let cg = context.createCGImage(CIImage(cvPixelBuffer: buffer), from: CGRect(
                x: 0, y: 0, width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer)))
        else { return nil }
        return UIImage(cgImage: cg)
    }

    /// Vision coords: normalised, origin bottom-left, frame is portrait.
    private static func evaluate(_ faces: [VNFaceObservation]) -> CameraModel.Guidance {
        guard let f = faces.max(by: { $0.boundingBox.width < $1.boundingBox.width }) else { return .searching }
        let box = f.boundingBox
        if box.width < 0.34 { return .closer }
        if box.width > 0.78 { return .farther }
        if abs(box.midX - 0.5) > 0.14 || abs(box.midY - 0.54) > 0.16 { return .center }
        if abs(f.yaw?.doubleValue ?? 0) > 0.3 || abs(f.roll?.doubleValue ?? 0) > 0.3 { return .straight }
        return .hold
    }
}
