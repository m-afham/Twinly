// CameraView — full-screen selfie capture: live preview, an oval guide that
// turns into a gradient ring when the face is right, a coaching label, and
// a shutter whose ring fills during the auto-capture hold. Falls back to
// "choose a photo" when there's no camera (Simulator) or no permission.

import AVFoundation
import SwiftUI

struct CameraView: View {
    let onCapture: (UIImage) -> Void
    let onChoosePhoto: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var camera = CameraModel()
    @State private var flash = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch camera.availability {
            case .ready:
                CameraPreview(session: camera.session).ignoresSafeArea()
                overlay
            case .unknown:
                ProgressView().tint(.white)
            case .denied:
                fallback(icon: "camera.badge.ellipsis",
                         title: "Camera access is off",
                         message: "Allow camera access in Settings to take a selfie, or choose a photo instead.",
                         showSettings: true)
            case .unavailable:
                fallback(icon: "camera.fill",
                         title: "No camera here",
                         message: "This device has no front camera. You can choose a photo instead.",
                         showSettings: false)
            }
            Color.white.opacity(flash ? 0.85 : 0).ignoresSafeArea().allowsHitTesting(false)
        }
        .overlay(alignment: .topLeading) {
            CircleIconButton(systemName: "xmark", label: "Close") { dismiss() }
                .padding(Theme.Space.m)
        }
        .task {
            camera.onCapture = { image in
                withAnimation(.easeOut(duration: 0.12)) { flash = true }
                Task {
                    try? await Task.sleep(for: .milliseconds(140))
                    onCapture(image)
                }
            }
            await camera.start()
        }
        .onDisappear { camera.stop() }
        .statusBarHidden()
    }

    private var isGood: Bool { camera.guidance == .hold }

    private var overlay: some View {
        GeometryReader { geo in
            let w = geo.size.width * 0.72
            let oval = CGSize(width: w, height: w * 1.32)
            ZStack {
                // Dim everything outside the oval.
                Rectangle()
                    .fill(.black.opacity(0.55))
                    .mask {
                        Rectangle()
                            .overlay(Ellipse().frame(width: oval.width, height: oval.height)
                                .offset(y: -geo.size.height * 0.06)
                                .blendMode(.destinationOut))
                            .compositingGroup()
                    }
                    .ignoresSafeArea()

                Ellipse()
                    .strokeBorder(isGood ? AnyShapeStyle(Theme.Palette.accent)
                                         : AnyShapeStyle(Color.white.opacity(0.7)),
                                  style: StrokeStyle(lineWidth: isGood ? 5 : 2, dash: isGood ? [] : [8, 8]))
                    .frame(width: oval.width, height: oval.height)
                                        .offset(y: -geo.size.height * 0.06)
                    .animation(Theme.Motion.snappy, value: isGood)

                VStack {
                    Text(camera.guidance.text)
                        .font(Theme.Font.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: camera.guidance)
                        .padding(.top, geo.safeAreaInsets.top + 64)
                    Spacer()
                    shutter.padding(.bottom, Theme.Space.xl)
                }
            }
        }
    }

    private var shutter: some View {
        HStack {
            Button { onChoosePhoto() } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Choose a photo instead")
            .frame(maxWidth: .infinity)

            Button { camera.capture() } label: {
                ZStack {
                    Circle().stroke(.white.opacity(0.35), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: camera.holdProgress)
                        .stroke(Theme.Palette.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: camera.holdProgress)
                    Circle().fill(.white).padding(9)
                }
                .frame(width: 82, height: 82)
            }
            .accessibilityLabel("Take selfie")

            Text(isGood ? "Auto" : "")
                .font(Theme.Font.overline)
                .foregroundStyle(Theme.Palette.accent)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Theme.Space.l)
    }

    private func fallback(icon: String, title: String, message: String, showSettings: Bool) -> some View {
        VStack(spacing: Theme.Space.m) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Theme.Palette.accent)
            Text(title).font(Theme.Font.title).foregroundStyle(Theme.Palette.textPrimary)
            Text(message)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
            VStack(spacing: Theme.Space.s + 4) {
                Button { onChoosePhoto() } label: { Label("Choose a photo", systemImage: "photo.on.rectangle") }
                    .buttonStyle(PrimaryButtonStyle())
                if showSettings {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(.top, Theme.Space.m)
        }
        .padding(Theme.Space.xl)
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
