// OnboardingPages — the four animated pages. Each one animates only while
// it's the active page, restarts when revisited, and stills under Reduce
// Motion.

import SwiftUI

// MARK: - 1 · Face wall

struct FaceWallPage: View {
    let faces: [UIImage]
    let count: Int?

    var body: some View {
        ZStack(alignment: .top) {
            // Full-bleed wall behind the page; overlay + clip so its natural
            // width never widens the layout.
            Color.clear
                .frame(height: 600)
                .overlay { FaceWall(faces: faces) }
                .clipped()
                .mask(LinearGradient(stops: [.init(color: .black, location: 0),
                                             .init(color: .black, location: 0.6),
                                             .init(color: .clear, location: 1)],
                                     startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea(edges: .top)
            OnboardingPage(
                title: "Everyone has a\nfamous twin.",
                subtitle: "Twinly finds yours in seconds, out of \(count.map { $0.formatted() } ?? "hundreds of") famous faces."
            ) {
                Color.clear
            }
        }
    }
}

/// Five tilted columns of faces drifting in alternating directions.
private struct FaceWall: View {
    let faces: [UIImage]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = 5
    private let perColumn = 8
    private let side: CGFloat = 86
    private let gap: CGFloat = 14

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: gap) {
                ForEach(0..<columns, id: \.self) { col in
                    FaceColumn(images: images(for: col), side: side, gap: gap,
                               offset: offset(for: col, at: t))
                }
            }
        }
        .rotationEffect(.degrees(-12))
        .scaleEffect(1.2)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func images(for col: Int) -> [UIImage?] {
        (0..<perColumn).map { i in
            faces.isEmpty ? nil : faces[(col * perColumn + i) % faces.count]
        }
    }

    /// Each column loops over its own height; odd columns run downwards.
    private func offset(for col: Int, at t: TimeInterval) -> CGFloat {
        let loop = Double(perColumn) * Double(side + gap)
        let speed = 18.0 + Double(col % 3) * 7
        let travelled = (t * speed + Double(col) * 61).truncatingRemainder(dividingBy: loop)
        return CGFloat(col.isMultiple(of: 2) ? -travelled : travelled - loop)
    }
}

private struct FaceColumn: View {
    let images: [UIImage?]
    let side: CGFloat
    let gap: CGFloat
    let offset: CGFloat

    var body: some View {
        VStack(spacing: gap) {
            // Drawn twice so the loop is seamless.
            ForEach(0..<(images.count * 2), id: \.self) { i in
                FaceTile(image: images[i % images.count], side: side, hue: i)
            }
        }
        .offset(y: offset)
        .frame(width: side, height: 760, alignment: .top)
    }
}

private struct FaceTile: View {
    let image: UIImage?
    let side: CGFloat
    let hue: Int

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                hue.isMultiple(of: 2) ? Theme.Palette.surface : Theme.Palette.raised
            }
        }
        .frame(width: side, height: side)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Theme.Palette.stroke, lineWidth: 1))
    }
}

// MARK: - 2 · Face mesh

struct MeshPage: View {
    let active: Bool

    var body: some View {
        OnboardingPage(
            title: "Your face,\nmapped.",
            subtitle: "Apple's Vision finds your features. A neural network turns them into 512 numbers that are uniquely you."
        ) {
            FaceMeshArt(active: active)
        }
    }
}

private struct FaceMeshArt: View {
    let active: Bool
    @State private var start = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: !active || reduceMotion)) { context in
            let elapsed = reduceMotion ? 10 : context.date.timeIntervalSince(start)
            Canvas { ctx, size in
                FaceMesh.draw(in: &ctx, size: size, elapsed: elapsed)
            }
        }
        .frame(width: 300, height: 380)
        .onChange(of: active) { if active { start = Date() } }
        .onAppear { start = Date() }
        .accessibilityHidden(true)
    }
}

/// A 68-point face (the classic landmark layout), drawn progressively:
/// dots pop in, contours trace between them, a scan beam sweeps, and
/// embedding values drift upwards.
private enum FaceMesh {
    static let groups: [(points: [CGPoint], closed: Bool)] = {
        func arc(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat,
                 _ a0: CGFloat, _ a1: CGFloat, _ n: Int) -> [CGPoint] {
            (0..<n).map { i in
                let a = (a0 + (a1 - a0) * CGFloat(i) / CGFloat(max(1, n - 1))) * .pi / 180
                return CGPoint(x: cx + cos(a) * rx, y: cy + sin(a) * ry)
            }
        }
        func ring(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ n: Int) -> [CGPoint] {
            arc(cx, cy, rx, ry, 0, 360 - 360 / CGFloat(n), n)
        }
        return [
            (arc(0.5, 0.40, 0.36, 0.50, 5, 175, 17), false),                 // jaw
            (arc(0.33, 0.37, 0.11, 0.05, 195, 345, 5), false),               // brows
            (arc(0.67, 0.37, 0.11, 0.05, 195, 345, 5), false),
            ((0..<4).map { CGPoint(x: 0.5, y: 0.42 + CGFloat($0) * 0.06) }, false), // nose bridge
            (arc(0.5, 0.60, 0.075, 0.03, 10, 170, 5), false),                // nose base
            (ring(0.34, 0.46, 0.07, 0.028, 6), true),                        // eyes
            (ring(0.66, 0.46, 0.07, 0.028, 6), true),
            (ring(0.5, 0.75, 0.14, 0.05, 12), true),                         // lips
            (ring(0.5, 0.75, 0.08, 0.016, 8), true),
        ]
    }()

    static func draw(in ctx: inout GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        let total = groups.reduce(0) { $0 + $1.points.count }
        let reveal = min(1, elapsed / 1.6)        // dots
        let trace = min(1, max(0, (elapsed - 0.5) / 1.4))  // contours
        func p(_ u: CGPoint) -> CGPoint { CGPoint(x: u.x * size.width, y: u.y * size.height) }

        // Contours.
        for group in groups {
            var path = Path()
            path.addLines(group.points.map(p))
            if group.closed { path.closeSubpath() }
            ctx.stroke(path.trimmedPath(from: 0, to: trace),
                       with: .color(Theme.Palette.accent),
                       style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }

        // Dots, popping in one by one.
        var index = 0
        for group in groups {
            for u in group.points {
                let local = reveal * Double(total) - Double(index)
                index += 1
                guard local > 0 else { continue }
                let pop = min(1, local)
                let r = 2.2 + 3 * (1 - pop)
                let c = p(u)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                         with: .color(Theme.Palette.textPrimary.opacity(pop)))
            }
        }

        // A thin scan line sweeping down and up, clipped to the face.
        let beamY = (0.5 - 0.5 * cos(elapsed * 1.6)) * size.height
        var beamCtx = ctx
        beamCtx.clip(to: Path(ellipseIn: CGRect(x: size.width * 0.12, y: 0,
                                                width: size.width * 0.76, height: size.height * 0.92)))
        beamCtx.fill(Path(CGRect(x: 0, y: beamY - 1, width: size.width, height: 2)),
                     with: .color(Theme.Palette.star.opacity(0.8)))

        // Embedding values drifting up and fading.
        guard elapsed > 1.2 else { return }
        for i in 0..<14 {
            let seed = Double(i) * 12.9898
            let x = (0.08 + 0.84 * fract(sin(seed) * 43758.5453)) * size.width
            let speed = 26 + 18 * fract(sin(seed * 2) * 9631.17)
            let travel = ((elapsed - 1.2) * speed + Double(i) * 37).truncatingRemainder(dividingBy: Double(size.height))
            let y = size.height - travel
            let alpha = min(1, travel / 60) * (1 - travel / Double(size.height))
            let value = (fract(sin(seed * 3) * 2717.3) * 2 - 1)
            ctx.draw(Text(String(format: "%+.3f", value))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.Palette.star.opacity(alpha * 0.85)),
                     at: CGPoint(x: x, y: y))
        }
    }

    private static func fract(_ v: Double) -> Double { v - v.rounded(.down) }
}

// MARK: - 3 · Collision

struct CollisionPage: View {
    let active: Bool
    let celebFace: UIImage?

    @State private var hit = false
    @State private var percent = 0
    @State private var burst = 0
    private let size: CGFloat = 150

    var body: some View {
        OnboardingPage(
            title: "Meet your twin.",
            subtitle: "See your closest matches, compare them with a tap, and share the card."
        ) {
            ZStack {
                Portrait(image: nil, size: size, placeholder: "face.smiling",
                         ring: AnyShapeStyle(Theme.Palette.accent), ringWidth: 4)
                    .offset(x: hit ? -size * 0.39 : -340)
                    .rotationEffect(.degrees(hit ? 0 : -25))
                Portrait(image: celebFace, size: size,
                         ring: AnyShapeStyle(Theme.Palette.star), ringWidth: 4)
                    .offset(x: hit ? size * 0.39 : 340)
                    .rotationEffect(.degrees(hit ? 0 : 25))
                SparkleBurst(trigger: burst)
                badge.offset(y: size * 0.62).opacity(hit ? 1 : 0)
            }
            .keyframeAnimator(initialValue: CGFloat.zero, trigger: burst) { view, x in
                view.offset(x: x)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(9, duration: 0.05)
                    CubicKeyframe(-7, duration: 0.06)
                    CubicKeyframe(4, duration: 0.06)
                    CubicKeyframe(0, duration: 0.1)
                }
            }
            .accessibilityHidden(true)
        }
        .task(id: active) { await play() }
    }

    private var badge: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkle")
            Text("\(percent)% match").contentTransition(.numericText(value: Double(percent)))
        }
        .font(Theme.Font.headline)
        .foregroundStyle(Theme.Palette.onAccent)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Theme.Palette.accent, in: Capsule())
    }

    private func play() async {
        hit = false
        percent = 0
        guard active else { return }
        try? await Task.sleep(for: .milliseconds(250))
        withAnimation(.spring(response: 0.42, dampingFraction: 0.58)) { hit = true }
        try? await Task.sleep(for: .milliseconds(260))
        guard !Task.isCancelled else { return }
        Haptics.thump(1)
        burst += 1
        withAnimation(.easeOut(duration: 1.2)) { percent = 94 }
    }
}

// MARK: - 4 · Privacy

struct PrivacyPage: View {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        OnboardingPage(
            title: "Your face\nstays yours.",
            subtitle: "Everything happens on your iPhone. No uploads, no accounts, no tracking. It doesn't even need the internet."
        ) {
            TimelineView(.animation(paused: !active || reduceMotion)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                ZStack {
                    orbit(color: Theme.Palette.accent, tilt: 62, spin: t * 24)
                    orbit(color: Theme.Palette.star, tilt: -62, spin: -t * 18)
                    ForEach(Array(["icloud.slash.fill", "wifi.slash", "eye.slash.fill"].enumerated()), id: \.offset) { i, icon in
                        satellite(icon, angle: t * 0.7 + Double(i) * 2 * .pi / 3)
                    }
                    lock
                }
            }
            .frame(width: 320, height: 320)
            .accessibilityHidden(true)
        }
    }

    private var lock: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 54, weight: .semibold))
            .foregroundStyle(Theme.Palette.accent)
            .symbolEffect(.bounce, value: active)
            .frame(width: 128, height: 128)
            .background(Theme.Palette.surface, in: Circle())
            .overlay(Circle().strokeBorder(Theme.Palette.stroke, lineWidth: 1))
    }

    private func orbit(color: Color, tilt: Double, spin: Double) -> some View {
        Ellipse()
            .stroke(color.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [3, 9]))
            .frame(width: 290, height: 110)
            .rotationEffect(.degrees(spin))
            .rotationEffect(.degrees(tilt))
    }

    private func satellite(_ icon: String, angle: Double) -> some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(Theme.Palette.surface, in: Circle())
            .overlay(Circle().strokeBorder(Theme.Palette.stroke))
            .offset(x: cos(angle) * 138, y: sin(angle) * 138)
    }
}
