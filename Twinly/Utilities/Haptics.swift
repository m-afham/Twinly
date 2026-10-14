// Haptics — the app's only haptic entry point, so feel stays consistent.

import UIKit

@MainActor
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notify = UINotificationFeedbackGenerator()

    static func tap() { light.impactOccurred() }
    static func tick() { selection.selectionChanged() }
    static func thump(_ intensity: CGFloat = 0.8) { soft.impactOccurred(intensity: intensity) }
    static func success() { notify.notificationOccurred(.success) }
    static func warning() { notify.notificationOccurred(.warning) }
}
