// ScopeViews — "Match within": limit matching to chosen universes (film
// series, franchises and TV shows, from Wikidata cast lists) or keep all
// actors. A chip shows the current scope on Home and Result; tapping it
// opens the picker, which toggles universes live (a shown result re-ranks
// instantly).

import SwiftUI

struct ScopeChip: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            Haptics.tap()
            model.isScopePickerPresented = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "film.stack")
                Text("Match within")
                Text(model.scopeLabel)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Palette.accent)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Palette.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Theme.Palette.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.Palette.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Match within \(model.scopeLabel)")
        .accessibilityHint("Choose which film and TV universes to match against")
    }
}

struct ScopePicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    allActorsRow
                } footer: {
                    Text("Pick one or more universes to match only against their cast. Changes apply instantly.")
                }

                ForEach(groups, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.universes) { universeRow($0) }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search universes")
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.night)
            .navigationTitle("Match within")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var universes: [Universe] {
        let all = model.engine?.universes ?? []
        return query.isEmpty ? all : all.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var groups: [(title: String, universes: [Universe])] {
        let films = universes.filter { $0.kind != "TV series" }
        let shows = universes.filter { $0.kind == "TV series" }
        return [("Films and franchises", films), ("TV series", shows)].filter { !$0.1.isEmpty }
    }

    private var allActorsRow: some View {
        Button {
            Haptics.tick()
            model.scope = []
        } label: {
            HStack(spacing: Theme.Space.m) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Palette.accent)
                    .frame(width: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text("All actors").font(Theme.Font.headline).foregroundStyle(Theme.Palette.textPrimary)
                    Text("\(model.engine?.celebrityCount.formatted() ?? "Every") actors on file")
                        .font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                }
                Spacer()
                check(model.activeUniverses.isEmpty)
            }
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private func universeRow(_ u: Universe) -> some View {
        let selected = model.scope.contains(u.id)
        return Button {
            Haptics.tick()
            if selected { model.scope.remove(u.id) } else { model.scope.insert(u.id) }
        } label: {
            HStack(spacing: Theme.Space.m) {
                FaceStack(rows: Array(u.rows.prefix(3)))
                    .frame(width: 64, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(u.name).font(Theme.Font.headline).foregroundStyle(Theme.Palette.textPrimary)
                    Text("\(u.rows.count) actors · \(u.kind)")
                        .font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                }
                Spacer()
                check(selected)
            }
        }
        .listRowBackground(Theme.Palette.surface)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func check(_ on: Bool) -> some View {
        Image(systemName: on ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 22))
            .foregroundStyle(on ? Theme.Palette.accent : Theme.Palette.stroke)
    }
}

/// Three overlapping cast faces — a quick visual for a universe.
private struct FaceStack: View {
    @Environment(AppModel.self) private var model
    let rows: [Int]

    var body: some View {
        HStack(spacing: -12) {
            ForEach(rows, id: \.self) { row in
                Group {
                    if let engine = model.engine, let face = engine.face(for: engine.index.celebrities[row]) {
                        Image(uiImage: face).resizable().scaledToFill()
                    } else {
                        Theme.Palette.raised
                    }
                }
                .frame(width: 30, height: 30)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Theme.Palette.surface, lineWidth: 2))
            }
        }
        .accessibilityHidden(true)
    }
}
