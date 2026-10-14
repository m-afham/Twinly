// HomeView — the landing screen. The hero is the twin-circle motif: "you"
// (a breathing placeholder) beside a celebrity face that cross-fades every
// couple of seconds. One primary action (selfie), one secondary (photo).

import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var celebFace: UIImage?
    @State private var breathe = false
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Spacer(minLength: Theme.Space.l)

            hero
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.92)

            Spacer(minLength: Theme.Space.xl)

            VStack(spacing: Theme.Space.m) {
                Text("Who's your\nfamous twin?")
                    .font(Theme.Font.display)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(subtitle)
                    .font(Theme.Font.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.horizontal, Theme.Space.m)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)

            Spacer(minLength: Theme.Space.xl)

            VStack(spacing: Theme.Space.s + 4) {
                ScopeChip()
                    .padding(.bottom, Theme.Space.xs)
                Button {
                    Haptics.tap()
                    model.isCameraPresented = true
                } label: {
                    Label("Take a selfie", systemImage: "camera.fill")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    Haptics.tap()
                    model.isPickerPresented = true
                } label: {
                    Label("Choose a photo", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(SecondaryButtonStyle())

                Label("Runs on-device. Your photo never leaves your iPhone.", systemImage: "lock.fill")
                    .multilineTextAlignment(.center)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .padding(.top, Theme.Space.s)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 24)
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.bottom, Theme.Space.s)
        .onAppear {
            withAnimation(Theme.Motion.soft.delay(0.05)) { appeared = true }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { breathe = true }
        }
        .task(id: "\(model.engine == nil)\(model.scope.sorted())") { await cycleFaces() }
    }

    private var subtitle: String {
        let count = model.engine?.candidateCount(for: model.scope) ?? 0
        let faces = count > 0 ? "\(count.formatted()) famous faces" : "thousands of famous faces"
        return "Take a selfie and Twinly finds the star you look most like, out of \(faces)."
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: Theme.Space.s) {
                TwinMark(size: 22)
                Text("Twinly")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.Palette.textPrimary)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            CircleIconButton(systemName: "info", label: "About Twinly") { model.isAboutPresented = true }
        }
        .padding(.top, Theme.Space.s)
    }

    private var hero: some View {
        ZStack {
            TwinPortraits(left: nil, right: celebFace, size: 150, leftPlaceholder: "face.smiling")
                .animation(.easeInOut(duration: 0.6), value: celebFace)
            // "You": a dashed, breathing outline over the left circle.
            Circle()
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 7]))
                .foregroundStyle(Theme.Palette.accent.opacity(0.8))
                .frame(width: 150 + (breathe ? 22 : 8))
                .offset(x: -150 * 0.39)
                .opacity(breathe ? 0.25 : 0.7)
            Sparkle(size: 30)
                .offset(y: -150 * 0.42)
                .scaleEffect(breathe ? 1.1 : 0.85)
        }
        .accessibilityHidden(true)
    }

    private func cycleFaces() async {
        guard let engine = model.engine else { return }
        // Show faces from the universes being matched against.
        let pool = (engine.rows(for: model.scope).map { $0.map { engine.index.celebrities[$0] } }
                    ?? engine.index.celebrities).shuffled()
        var i = 0
        while !Task.isCancelled, !pool.isEmpty {
            celebFace = engine.face(for: pool[i % pool.count])
            i += 1
            try? await Task.sleep(for: .seconds(2.2))
        }
    }
}

/// Four-point star used for "star moments".
struct Sparkle: View {
    var size: CGFloat = 24
    var color: Color = Theme.Palette.accent

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(color)
    }
}

/// Small brand mark: two overlapping rings (matches the app icon).
struct TwinMark: View {
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            Circle().strokeBorder(Theme.Palette.accent, lineWidth: size * 0.14)
                .frame(width: size, height: size).offset(x: -size * 0.24)
            Circle().strokeBorder(Theme.Palette.star, lineWidth: size * 0.14)
                .frame(width: size, height: size).offset(x: size * 0.24)
        }
        .frame(width: size * 1.5, height: size)
    }
}
