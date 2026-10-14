// Components — shared building blocks: buttons, the ringed circular
// portrait used everywhere a face appears, the twin-circle hero, chips and
// the background. Solid colours only.

import SwiftUI

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.headline)
            .foregroundStyle(Theme.Palette.onAccent)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(Theme.Palette.accent, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Theme.Motion.snappy, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.headline)
            .foregroundStyle(Theme.Palette.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Theme.Palette.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.Palette.stroke, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Theme.Motion.snappy, value: configuration.isPressed)
    }
}

struct CircleIconButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: { Haptics.tap(); action() }) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(width: 44, height: 44)
                .background(Theme.Palette.surface, in: Circle())
                .overlay(Circle().strokeBorder(Theme.Palette.stroke, lineWidth: 1))
        }
        .accessibilityLabel(label)
    }
}

// MARK: - Portraits

/// A circular face with a coloured ring. `image == nil` shows a soft
/// placeholder silhouette.
struct Portrait: View {
    let image: UIImage?
    var size: CGFloat = 120
    var placeholder = "person.fill"
    var ring: AnyShapeStyle = AnyShapeStyle(Theme.Palette.accent)
    var ringWidth: CGFloat = 3

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Theme.Palette.surface
                Image(systemName: placeholder)
                    .font(.system(size: size * 0.36, weight: .medium))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(ring, lineWidth: ringWidth))
    }
}

/// Twinly's signature motif: two overlapping circles — champagne for you,
/// steel blue for your famous twin.
struct TwinPortraits: View {
    let left: UIImage?
    let right: UIImage?
    var size: CGFloat = 168
    var leftPlaceholder = "person.fill"
    var overlap: CGFloat = 0.22

    var body: some View {
        ZStack {
            Portrait(image: left, size: size, placeholder: leftPlaceholder,
                     ring: AnyShapeStyle(Theme.Palette.accent), ringWidth: 4)
                .offset(x: -size * (0.5 - overlap / 2))
            Portrait(image: right, size: size,
                     ring: AnyShapeStyle(Theme.Palette.star), ringWidth: 4)
                .offset(x: size * (0.5 - overlap / 2))
        }
        .frame(width: size * (2 - overlap), height: size)
    }
}

// MARK: - Small pieces

struct Chip: View {
    let text: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(Theme.Font.caption)
        .foregroundStyle(Theme.Palette.textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Theme.Palette.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.Palette.stroke, lineWidth: 1))
    }
}

/// The ink canvas behind every screen.
struct AmbientBackground: View {
    var body: some View {
        Theme.Palette.night.ignoresSafeArea()
    }
}
