// OnboardingView — first-run experience. Four full-bleed pages, each led by
// motion: a drifting wall of famous faces, a face mesh drawing itself, two
// portraits colliding into a match, and the privacy promise. The bloom
// behind them re-tints per page. The last CTA goes straight to the camera.

import SwiftUI

struct OnboardingView: View {
    /// `true` when the user tapped the final CTA (open the camera next).
    let onFinish: (_ startSelfie: Bool) -> Void

    @Environment(AppModel.self) private var model
    @State private var page = 0
    @State private var faces: [UIImage] = []

    private let pageCount = 4

    var body: some View {
        ZStack {
            TabView(selection: $page) {
                FaceWallPage(faces: faces, count: model.engine?.celebrityCount).tag(0)
                MeshPage(active: page == 1).tag(1)
                CollisionPage(active: page == 2, celebFace: faces.first).tag(2)
                PrivacyPage(active: page == 3).tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button("Skip") { finish(false) }
                        .font(Theme.Font.headline)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.Palette.surface, in: Capsule())
                        .opacity(page == pageCount - 1 ? 0 : 1)
                        .animation(.easeInOut(duration: 0.2), value: page)
                }
                .padding(.horizontal, Theme.Space.l)
                Spacer()
                controls
            }
        }
        // As a background, the oversized blooms can't widen the layout.
        .background { background }
        .onChange(of: page) { Haptics.tick() }
        .task(id: model.engine == nil) {
            guard faces.isEmpty, let engine = model.engine else { return }
            faces = engine.index.celebrities.shuffled().prefix(48).compactMap { engine.face(for: $0) }
        }
    }

    private var background: some View {
        Theme.Palette.night.ignoresSafeArea()
    }

    private var controls: some View {
        VStack(spacing: Theme.Space.l) {
            PageDots(count: pageCount, current: page)
            Button {
                if page < pageCount - 1 {
                    Haptics.tap()
                    withAnimation(Theme.Motion.soft) { page += 1 }
                } else {
                    finish(true)
                }
            } label: {
                Label(page < pageCount - 1 ? "Continue" : "Find my twin",
                      systemImage: page < pageCount - 1 ? "arrow.right" : "camera.fill")
                    .contentTransition(.opacity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .animation(.easeInOut(duration: 0.2), value: page)
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.bottom, Theme.Space.m)
    }

    private func finish(_ startSelfie: Bool) {
        Haptics.success()
        onFinish(startSelfie)
    }
}

/// Capsule-style page indicator: the current page stretches into a pill.
private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Theme.Palette.accent : Theme.Palette.stroke)
                    .frame(width: i == current ? 28 : 8, height: 8)
            }
        }
        .animation(Theme.Motion.snappy, value: current)
        .accessibilityElement()
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}

/// Shared page scaffold: art on top, serif title and subtitle beneath,
/// leaving room for the controls.
struct OnboardingPage<Art: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let art: Art

    var body: some View {
        VStack(spacing: 0) {
            art
                .frame(maxWidth: .infinity)
                .frame(height: 380)
            Spacer(minLength: Theme.Space.s)
            VStack(spacing: Theme.Space.m) {
                Text(title)
                    .font(Theme.Font.display)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Theme.Space.xl)
            Spacer(minLength: 130)
        }
        .padding(.top, 60)
    }
}
