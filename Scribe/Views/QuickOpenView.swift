import SwiftUI

struct QuickOpenView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool

    var filteredNotes: [Note] {
        guard let folder = appState.rootFolder else { return [] }
        let allNotes = collectAllNotes(from: folder)

        if searchText.isEmpty {
            return Array(allNotes.prefix(10))
        }

        let query = searchText.lowercased()
        return allNotes.filter { note in
            note.title.lowercased().contains(query) ||
            note.content.lowercased().contains(query) ||
            note.tags.contains { $0.lowercased().contains(query) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.title3)

                TextField("Search notes...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isSearchFocused)
                    .onSubmit {
                        selectCurrentNote()
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Text("⌘P")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding()

            Divider()

            // Results
            if filteredNotes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(.quaternary)

                    Text(searchText.isEmpty ? "No notes yet" : "No matches found")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List(Array(filteredNotes.enumerated()), id: \.element.id) { index, note in
                        QuickOpenRow(
                            note: note,
                            isSelected: index == selectedIndex
                        )
                        .id(index)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectNote(note)
                        }
                    }
                    .listStyle(.plain)
                    .onChange(of: selectedIndex) { _, newValue in
                        withAnimation {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }

            Divider()

            // Footer hints
            HStack(spacing: 16) {
                KeyHint(key: "↑↓", label: "Navigate")
                KeyHint(key: "↵", label: "Open")
                KeyHint(key: "esc", label: "Close")
            }
            .padding(10)
        }
        .frame(width: 500, height: 400)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        .onAppear {
            isSearchFocused = true
            selectedIndex = 0
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < filteredNotes.count - 1 {
                selectedIndex += 1
            }
            return .handled
        }
        .onKeyPress(.escape) {
            appState.showQuickOpen = false
            return .handled
        }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
        }
    }

    private func selectCurrentNote() {
        guard !filteredNotes.isEmpty else { return }
        let note = filteredNotes[min(selectedIndex, filteredNotes.count - 1)]
        selectNote(note)
    }

    private func selectNote(_ note: Note) {
        appState.selectedNote = note
        appState.showQuickOpen = false
    }

    private func collectAllNotes(from folder: NoteFolder) -> [Note] {
        var notes = folder.notes
        for child in folder.children {
            notes.append(contentsOf: collectAllNotes(from: child))
        }
        return notes.sorted { $0.modifiedAt > $1.modifiedAt }
    }
}

struct QuickOpenRow: View {
    let note: Note
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(note.displayTitle)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .primary)

                HStack(spacing: 8) {
                    Text(formatDate(note.modifiedAt))
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)

                    if !note.relativePath.isEmpty {
                        Text(note.relativePath)
                            .font(.caption)
                            .foregroundStyle(isSelected ? .white.opacity(0.5) : Color.secondary.opacity(0.7))
                    }
                }
            }

            Spacer()

            if !note.tags.isEmpty {
                Text("#\(note.tags.first!)")
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : .blue)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct KeyHint: View {
    let key: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.caption.monospaced())
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 3))

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    QuickOpenView()
        .environmentObject(AppState())
}
