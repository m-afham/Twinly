// ResultView — the payoff. Twin-circle hero (you + the star) with a rolling
// "% match" badge and a sparkle burst, the star's name in serif, a row of
// top matches that swaps the hero on tap, the portrait's licence credit, and
// a share card rendered on demand.

import SwiftUI

struct ResultView: View {
    @Environment(AppModel.self) private var model
    @State private var selected: Match?
    @State private var shownPercent = 0
    @State private var burst = 0
    @State private var shareImage: Image?

    var body: some View {
        if let result = model.result, let engine = model.engine {
            let match = selected ?? result.matches[0]
            ScrollView {
                VStack(spacing: Theme.Space.l) {
                    topBar
                    ScopeChip()
                    hero(result: result, match: match, engine: engine)
                    identity(match)
                    matchesRow(result.matches, current: match, engine: engine)
                    credit(match.celebrity)
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.bottom, Theme.Space.l)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) { actions(match: match) }
            .onChange(of: result.id) { selected = nil }
            .task(id: match.id) {
                shownPercent = 0
                try? await Task.sleep(for: .milliseconds(120))
                withAnimation(.easeOut(duration: 0.9)) { shownPercent = match.percent }
                burst += 1
                shareImage = ShareCard.render(selfie: result.selfie, celebFace: engine.face(for: match.celebrity),
                                              match: match)
            }
        }
    }

    private var topBar: some View {
        HStack {
            CircleIconButton(systemName: "xmark", label: "Start over") { model.reset() }
            Spacer()
            Text("YOUR FAMOUS TWIN")
                .font(Theme.Font.overline)
                .tracking(2)
                .foregroundStyle(Theme.Palette.accent)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.top, Theme.Space.s)
    }

    private func hero(result: LookalikeResult, match: Match, engine: LookalikeEngine) -> some View {
        ZStack {
            TwinPortraits(left: result.selfie, right: engine.face(for: match.celebrity), size: 158)
                .animation(Theme.Motion.soft, value: match.id)
            SparkleBurst(trigger: burst)
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                Text("\(shownPercent)% match")
                    .contentTransition(.numericText(value: Double(shownPercent)))
            }
            .font(Theme.Font.headline)
            .foregroundStyle(Theme.Palette.onAccent)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Theme.Palette.accent, in: Capsule())
            .offset(y: 20)
        }
        .padding(.top, Theme.Space.m)
        .padding(.bottom, Theme.Space.m)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("You and \(match.celebrity.name), \(match.percent) percent match")
    }

    private func identity(_ match: Match) -> some View {
        VStack(spacing: Theme.Space.s) {
            Text(Self.verdict(for: match.percent))
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
            Text(match.celebrity.name)
                .font(Theme.Font.name)
                .foregroundStyle(Theme.Palette.textPrimary)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
            if !match.celebrity.description.isEmpty {
                Text(match.celebrity.description.prefix(1).uppercased() + match.celebrity.description.dropFirst())
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: match.id)
    }

    private func matchesRow(_ matches: [Match], current: Match, engine: LookalikeEngine) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("Your top matches")
                .font(Theme.Font.headline)
                .foregroundStyle(Theme.Palette.textPrimary)
            ScrollView(.horizontal) {
                HStack(spacing: Theme.Space.m) {
                    ForEach(matches) { m in
                        Button {
                            Haptics.tick()
                            withAnimation(Theme.Motion.snappy) { selected = m }
                        } label: {
                            VStack(spacing: 6) {
                                Portrait(image: engine.face(for: m.celebrity), size: 68,
                                         ring: m.id == current.id ? AnyShapeStyle(Theme.Palette.star)
                                                                  : AnyShapeStyle(Theme.Palette.stroke),
                                         ringWidth: m.id == current.id ? 3 : 1)
                                Text(m.celebrity.name)
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(Theme.Palette.textPrimary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 84, height: 34, alignment: .top)
                                Text("\(m.percent)%")
                                    .font(Theme.Font.overline)
                                    .foregroundStyle(m.id == current.id ? Theme.Palette.accent : Theme.Palette.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(m.celebrity.name), \(m.percent) percent")
                    }
                }
                .padding(.horizontal, Theme.Space.l)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -Theme.Space.l)
        }
        .padding(Theme.Space.m)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.m))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).strokeBorder(Theme.Palette.stroke))
    }

    @ViewBuilder
    private func credit(_ c: Celebrity) -> some View {
        let text = "Photo: \(c.artist.isEmpty ? "Wikimedia Commons" : c.artist) · \(c.license)"
        if let url = URL(string: c.source), !c.source.isEmpty {
            Link(destination: url) {
                Label(text, systemImage: "c.circle")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .lineLimit(1)
            }
        } else {
            Text(text).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textTertiary)
        }
    }

    private func actions(match: Match) -> some View {
        VStack(spacing: Theme.Space.s + 4) {
            if let shareImage {
                ShareLink(item: shareImage,
                          subject: Text("My famous twin"),
                          message: Text("I'm a \(match.percent)% match with \(match.celebrity.name)\(scopeSuffix) on Twinly ✨"),
                          preview: SharePreview("Me × \(match.celebrity.name)", image: shareImage)) {
                    Label("Share my twin", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PrimaryButtonStyle())
                .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
            }
            Button { model.retake() } label: { Label("Try another selfie", systemImage: "arrow.counterclockwise") }
                .buttonStyle(SecondaryButtonStyle())
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.top, Theme.Space.l)
        .padding(.bottom, Theme.Space.s)
        .background(
            LinearGradient(colors: [Theme.Palette.night.opacity(0), Theme.Palette.night.opacity(0.95), Theme.Palette.night],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    /// " in Harry Potter" when matching within exactly one universe.
    private var scopeSuffix: String {
        let active = model.activeUniverses
        return active.count == 1 ? " in \(active[0].name)" : ""
    }

    static func verdict(for percent: Int) -> String {
        switch percent {
        case 92...: "Uncanny. Are you sure you're not related?"
        case 84..<92: "A striking resemblance to"
        case 74..<84: "You've got a lot in common with"
        default: "There's a hint of"
        }
    }
}

/// Gold sparkles that pop outward from the lens each time `trigger` changes.
/// `progress` runs 0 → 1 per burst; at rest (1) they're invisible.
struct SparkleBurst: View {
    let trigger: Int
    @State private var progress: Double = 1
    private let angles: [Double] = [0, 45, 90, 108, 153, 198, 216, 261, 306, 324]

    var body: some View {
        ZStack {
            ForEach(angles.indices, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: CGFloat(10 + (i % 3) * 5), weight: .bold))
                    .foregroundStyle(i % 2 == 0 ? Theme.Palette.accent : Theme.Palette.textPrimary)
                    .offset(offset(for: i))
                    .opacity(1 - progress)
                    .scaleEffect(1.1 - 0.7 * progress)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) {
            progress = 0
            Task { @MainActor in
                withAnimation(.easeOut(duration: 1.0)) { progress = 1 }
            }
        }
    }

    private func offset(for i: Int) -> CGSize {
        let a = angles[i] * .pi / 180
        let dist = 10 + progress * Double(100 + (i % 3) * 22)
        return CGSize(width: cos(a) * dist, height: sin(a) * dist * 0.75)
    }
}
