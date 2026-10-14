// TwinlyApp — entry point and root view. One ambient background, three
// stages swapped in place, the camera as a full-screen cover, the photo
// picker and About as sheets.

import PhotosUI
import SwiftUI

@main
struct TwinlyApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(Theme.Palette.accent)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var pickerItem: PhotosPickerItem?
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    var body: some View {
        @Bindable var model = model
        ZStack {
            AmbientBackground()
            switch model.stage {
            case .home:
                HomeView().transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .reveal:
                RevealView().transition(.opacity)
            case .result:
                ResultView().transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            if !hasOnboarded {
                OnboardingView { startSelfie in
                    withAnimation(Theme.Motion.soft) { hasOnboarded = true }
                    if startSelfie { model.isCameraPresented = true }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.04)))
                .zIndex(1)
            }
        }
        .fullScreenCover(isPresented: $model.isCameraPresented) {
            CameraView(
                onCapture: { image in
                    model.isCameraPresented = false
                    model.analyze(image)
                },
                onChoosePhoto: {
                    model.isCameraPresented = false
                    model.isPickerPresented = true
                }
            )
        }
        .photosPicker(isPresented: $model.isPickerPresented, selection: $pickerItem, matching: .images,
                      preferredItemEncoding: .compatible)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            pickerItem = nil
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    model.analyze(image)
                }
            }
        }
        .sheet(isPresented: $model.isAboutPresented) { AboutView() }
        .sheet(isPresented: $model.isScopePickerPresented) { ScopePicker() }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.environment["TWINLY_ONBOARDING"] == "1" { hasOnboarded = false }
            if ProcessInfo.processInfo.environment["TWINLY_DEMO_IMAGE"] != nil { hasOnboarded = true }
            #endif
            await model.load()
            #if DEBUG
            // Test hook: TWINLY_DEMO_IMAGE=/abs/path.jpg (Simulator) or a file name
            // in the app's Documents folder (device) runs that photo straight away.
            if let name = ProcessInfo.processInfo.environment["TWINLY_DEMO_IMAGE"],
               let image = UIImage(contentsOfFile: name.hasPrefix("/") ? name
                   : URL.documentsDirectory.appendingPathComponent(name).path) {
                model.analyze(image)
            }
            #endif
        }
    }
}
