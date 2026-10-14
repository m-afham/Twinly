// RevealView — the "moment". The user's photo gets a scanning sweep while
// the twin circle flicks through celebrity faces like a slot machine,
// decelerating (with a haptic tick per face) until it lands on the match.
// Analysis itself takes a fraction of a second; the reel is pure theatre and
// keeps spinning until the result exists, then lands. Failure shows a card.

import SwiftUI

struct RevealView: View {
    @Environment(AppModel.self) private var model
    @State private var reelFace: UIImage?
    @State private var scan = false
    @State private var landed = false
    @State private var statusIndex = 0

    private var statuses: [String] {
        let count = model.engine?.candidateCount(for: model.scope).formatted() ?? "thousands of"
        return ["Finding your face…", "Mapping 512 facial features…", "Comparing with \(count) stars…", "Almost there…"]
    }

    var body: some View {
        VStack(spacing: Theme.Space.xl) {
            Spacer()
            ZStack {
                TwinPortraits(left: model.photo.map(Self.square), right: reelFace, size: 156)
                scanSweep
                if landed {
                    Sparkle(size: 34).offset(y: -156 * 0.45).transition(.scale.combined(with: .opacity))
                }
            }

            if let failure = model.failure {
                failureCard(failure).transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Text(landed ? "Found your twin!" : statuses[statusIndex % statuses.count])
                    .font(Theme.Font.title)
                    .foregroundStyle(landed ? Theme.Palette.accent : Theme.Palette.textPrimary)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: statusIndex)
                    .animation(.easeInOut(duration: 0.25), value: landed)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, Theme.Space.l)
        .animation(Theme.Motion.soft, value: model.failure != nil)
        .task { await runReel() }
        .task { await cycleStatus() }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { scan = true }
        }
    }

    /// A thin champagne scan line sweeping over the user's circle.
    private var scanSweep: some View {
        Theme.Palette.accent
            .frame(width: 156, height: 2)
            .offset(y: scan ? 64 : -64)
            .frame(width: 156, height: 156)
            .clipShape(Circle())
            .offset(x: -156 * 0.39)
            .opacity(landed || model.failure != nil ? 0 : 1)
            .allowsHitTesting(false)
    }

    private func runReel() async {
        // On a cold start the engine may still be loading.
        while model.engine == nil, model.failure == nil, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(50))
        }
        guard let engine = model.engine else { return }
        // Flick through the faces actually being compared (the chosen universes).
        let pool = (engine.rows(for: model.scope).map { $0.map { engine.index.celebrities[$0] } }
                    ?? engine.index.celebrities).shuffled()
        guard !pool.isEmpty else { return }
        var i = 0
        let start = Date()
        // Fast spin until the result is in (and at least ~1.4s have passed)…
        while !Task.isCancelled, model.failure == nil,
              model.result == nil || Date().timeIntervalSince(start) < 1.4 {
            reelFace = engine.face(for: pool[i % pool.count]); i += 1
            Haptics.tick()
            try? await Task.sleep(for: .milliseconds(70))
        }
        guard let top = model.result?.matches.first, !Task.isCancelled else { return }
        // …then decelerate onto the match.
        for delay in [90, 115, 145, 185, 235, 300, 380] {
            reelFace = engine.face(for: pool[i % pool.count]); i += 1
            Haptics.tick()
            try? await Task.sleep(for: .milliseconds(delay))
        }
        withAnimation(Theme.Motion.bouncy) {
            reelFace = engine.face(for: top.celebrity)
            landed = true
        }
        Haptics.success()
        try? await Task.sleep(for: .milliseconds(900))
        model.showResult()
    }

    private func cycleStatus() async {
        while !Task.isCancelled, !landed {
            try? await Task.sleep(for: .milliseconds(650))
            if statusIndex < statuses.count - 1 { statusIndex += 1 }
        }
    }

    private func failureCard(_ failure: FaceError) -> some View {
        VStack(spacing: Theme.Space.m) {
            Text(failure.title).font(Theme.Font.title).foregroundStyle(Theme.Palette.textPrimary)
            Text(failure.tip)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
            VStack(spacing: Theme.Space.s + 4) {
                Button { model.retake() } label: { Label("Retake selfie", systemImage: "camera.fill") }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Back") { model.reset() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.top, Theme.Space.s)
        }
        .padding(Theme.Space.l)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.l))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l).strokeBorder(Theme.Palette.stroke))
    }

    /// Center-square crop so a raw photo reads well in the circle until the
    /// face crop arrives.
    static func square(_ image: UIImage) -> UIImage {
        let side = min(image.size.width, image.size.height)
        let rect = CGRect(x: (image.size.width - side) / 2, y: (image.size.height - side) / 2, width: side, height: side)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 600, height: 600), format: format).image { _ in
            image.draw(in: CGRect(x: -rect.minX * 600 / side, y: -rect.minY * 600 / side,
                                  width: image.size.width * 600 / side, height: image.size.height * 600 / side))
        }
    }
}
