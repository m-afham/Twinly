// AppModel — the app's single source of truth: which stage of the flow is
// on screen (home → reveal → result), the loaded engine, and the current
// analysis. Analysis runs off the main actor; the reveal screen decides
// when to hand over to the result so the moment gets its drama.

import Observation
import SwiftUI

@MainActor
@Observable
final class AppModel {
    enum Stage: Equatable { case home, reveal, result }

    private(set) var stage: Stage = .home
    private(set) var engine: LookalikeEngine?
    private(set) var engineError: String?

    /// The photo being analysed (shown immediately on the reveal screen).
    private(set) var photo: UIImage?
    private(set) var result: LookalikeResult?
    private(set) var failure: FaceError?

    /// Universes to match within (franchise ids); empty means all actors.
    /// Remembered between launches. Changing it re-ranks a shown result.
    var scope: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "scope") ?? []) {
        didSet {
            UserDefaults.standard.set(Array(scope), forKey: "scope")
            rescore()
        }
    }

    var isCameraPresented = false
    var isScopePickerPresented = false
    var isPickerPresented = false
    var isAboutPresented = false

    func load() async {
        guard engine == nil else { return }
        do {
            engine = try await Task.detached(priority: .userInitiated) { try LookalikeEngine() }.value
        } catch {
            engineError = "Twinly's face data is missing from this build."
        }
    }

    func analyze(_ photo: UIImage) {
        self.photo = photo
        result = nil
        failure = nil
        withAnimation(Theme.Motion.soft) { stage = .reveal }

        Task {
            if engine == nil { await load() }
            guard let engine else { failure = .engineUnavailable; return }
            do {
                let scope = scope
                result = try await Task.detached(priority: .userInitiated) {
                    try engine.analyze(photo, scope: scope)
                }.value
            } catch {
                #if DEBUG
                NSLog("Twinly: analysis failed: %@", String(describing: error))
                #endif
                failure = (error as? FaceError) ?? .noFace
                Haptics.warning()
            }
        }
    }

    /// Universes in the current scope that this build actually offers.
    var activeUniverses: [Universe] {
        engine?.universes.filter { scope.contains($0.id) } ?? []
    }

    /// "All actors", one universe's name, or "3 universes".
    var scopeLabel: String {
        let active = activeUniverses
        switch active.count {
        case 0: return "All actors"
        case 1: return active[0].name
        default: return "\(active.count) universes"
        }
    }

    /// Re-rank the current result for the new scope (a matrix product: instant).
    private func rescore() {
        guard let engine, let r = result else { return }
        result = LookalikeResult(selfie: r.selfie, embedding: r.embedding,
                                 matches: engine.matches(for: r.embedding, scope: scope))
    }

    func showResult() {
        guard result != nil else { return }
        withAnimation(Theme.Motion.soft) { stage = .result }
    }

    func reset() {
        withAnimation(Theme.Motion.soft) { stage = .home }
        photo = nil
        result = nil
        failure = nil
    }

    func retake() {
        reset()
        isCameraPresented = true
    }
}
