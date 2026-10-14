// ShareCard — the 1080×1440 image people post: both faces in the twin
// motif, the match, and the Twinly wordmark. Rendered with ImageRenderer.

import SwiftUI

struct ShareCard: View {
    let selfie: UIImage
    let celebFace: UIImage?
    let match: Match

    var body: some View {
        ZStack {
            Theme.Palette.night

            VStack(spacing: 18) {
                HStack(spacing: 8) {
                    TwinMark(size: 18)
                    Text("Twinly").font(.system(size: 18, weight: .bold, design: .serif))
                }
                .foregroundStyle(Theme.Palette.textPrimary)
                Spacer(minLength: 0)
                ZStack(alignment: .bottom) {
                    TwinPortraits(left: selfie, right: celebFace, size: 132)
                    Text("\(match.percent)% match")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Palette.onAccent)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Theme.Palette.accent, in: Capsule())
                        .offset(y: 16)
                }
                Spacer(minLength: 0)
                VStack(spacing: 6) {
                    Text("My famous twin is")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Text(match.celebrity.name)
                        .font(.system(size: 30, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Text("Find yours on Twinly ✦")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Palette.accent)
            }
            .padding(.vertical, 28)
            .padding(.horizontal, 24)
        }
        .frame(width: 360, height: 480)
    }

    @MainActor
    static func render(selfie: UIImage, celebFace: UIImage?, match: Match) -> Image? {
        let renderer = ImageRenderer(content: ShareCard(selfie: selfie, celebFace: celebFace, match: match))
        renderer.scale = 3
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}
