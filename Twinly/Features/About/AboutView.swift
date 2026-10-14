// AboutView — how Twinly works, the privacy promise, licences (the face
// model is non-commercial; celebrity portraits are CC-licensed from
// Wikimedia Commons and credited individually), and a disclaimer.

import SwiftUI

struct AboutView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: Theme.Space.m) {
                        Image("IconArt")
                            .resizable()
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .accessibilityHidden(true)
                        Text("Twinly").font(.system(size: 28, weight: .bold, design: .serif))
                        Text("Find your famous twin.")
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Space.m)
                    .listRowBackground(Color.clear)
                }

                Section("How it works") {
                    step("viewfinder", "Find", "Apple's Vision framework locates your face and five key points: eyes, nose and mouth corners.")
                    step("point.3.connected.trianglepath.dotted", "Describe", "A neural network turns your aligned face into 512 numbers that capture its shape.")
                    step("person.2.fill", "Compare", "Twinly compares them with \(model.engine?.celebrityCount.formatted() ?? "thousands of") famous faces and shows the closest.")
                }

                Section("Privacy") {
                    step("lock.fill", "Nothing leaves your iPhone",
                         "Your photo is analysed on-device and never uploaded, stored or shared unless you share it yourself. Twinly has no accounts, no analytics and no network access.")
                }

                Section("Credits") {
                    NavigationLink {
                        CreditsView()
                    } label: {
                        Label("Celebrity photo credits", systemImage: "photo.stack")
                    }
                    Text("Portraits are freely licensed images from Wikimedia Commons, credited to their authors under their CC licences. Names and descriptions from Wikidata (CC0).")
                        .font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                    Text("Face recognition model: ArcFace MobileFaceNet by InsightFace, licensed for non-commercial research use only. Twinly is a non-commercial portfolio project.")
                        .font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                }

                Section {
                    Text("Just for fun. Resemblance is a guess based on facial geometry, not identity. Twinly isn't affiliated with or endorsed by anyone it shows.")
                        .font(Theme.Font.caption).foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.night)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func step(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.m) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.Palette.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(Theme.Font.headline)
                Text(text).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CreditsView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var all: [Celebrity] = []

    var body: some View {
        let shown = query.isEmpty ? all : all.filter { $0.name.localizedCaseInsensitiveContains(query) }
        List(shown) { c in
            HStack(spacing: Theme.Space.m) {
                Portrait(image: model.engine?.face(for: c), size: 44, ringWidth: 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.name).font(Theme.Font.headline)
                    Text("\(c.artist.isEmpty ? "Unknown author" : c.artist) · \(c.license)")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                if let url = URL(string: c.source), !c.source.isEmpty {
                    Link(destination: url) { Image(systemName: "arrow.up.right.square") }
                        .accessibilityLabel("Open source page")
                }
            }
        }
        .searchable(text: $query, prompt: "Search \(all.count.formatted()) people")
        .scrollContentBackground(.hidden)
        .background(Theme.Palette.night)
        .navigationTitle("Photo credits")
        .task {
            guard all.isEmpty, let engine = model.engine else { return }
            all = engine.index.celebrities.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        }
    }
}
