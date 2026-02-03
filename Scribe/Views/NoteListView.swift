import SwiftUI

struct NoteListView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(headerTitle)
                    .font(.headline)

                Spacer()

                Button {
                    appState.createNewNote()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Note list
            if filteredNotes.isEmpty {
                emptyState
            } else {
                List(filteredNotes, selection: Binding(
                    get: { appState.selectedNote?.id },
                    set: { id in
                        appState.selectedNote = filteredNotes.first { $0.id == id }
                    }
                )) { note in
                    NoteRow(note: note)
                        .tag(note.id)
                        .contextMenu {
                            noteContextMenu(for: note)
                        }
                }
                .listStyle(.plain)
            }
        }
    }

    private var headerTitle: String {
        guard let path = appState.selectedFolderPath else {
            return "All Notes"
        }

        if path == "__favorites__" {
            return "Favorites"
        }

        if path.hasPrefix("__tag__") {
            return "#\(path.replacingOccurrences(of: "__tag__", with: ""))"
        }

        return (path as NSString).lastPathComponent
    }

    private var filteredNotes: [Note] {
        guard let folder = appState.rootFolder else { return [] }

        var notes: [Note]

        if let path = appState.selectedFolderPath {
            if path == "__favorites__" {
                notes = collectAllNotes(from: folder).filter { $0.isFavorite }
            } else if path.hasPrefix("__tag__") {
                let tag = path.replacingOccurrences(of: "__tag__", with: "")
                notes = collectAllNotes(from: folder).filter { $0.tags.contains(tag) }
            } else {
                notes = findFolder(at: path, in: folder)?.notes ?? []
            }
        } else {
            notes = collectAllNotes(from: folder)
        }

        // Apply search filter
        if !appState.searchQuery.isEmpty {
            let query = appState.searchQuery.lowercased()
            notes = notes.filter {
                $0.title.lowercased().contains(query) ||
                $0.content.lowercased().contains(query) ||
                $0.tags.contains { $0.lowercased().contains(query) }
            }
        }

        return notes.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)

            Text("No notes")
                .foregroundStyle(.secondary)

            Button("Create Note") {
                appState.createNewNote()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func noteContextMenu(for note: Note) -> some View {
        Button {
            toggleFavorite(note)
        } label: {
            Label(
                note.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                systemImage: note.isFavorite ? "star.slash" : "star"
            )
        }

        Divider()

        Button {
            Task { await appState.syncToAtris() }
        } label: {
            Label("Sync to Atris", systemImage: "arrow.triangle.2.circlepath")
        }
        .disabled(appState.atrisToken.isEmpty)

        Divider()

        Button(role: .destructive) {
            appState.deleteNote(note)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func toggleFavorite(_ note: Note) {
        guard var updatedNote = appState.selectedNote, updatedNote.id == note.id else { return }
        updatedNote.isFavorite.toggle()
        appState.selectedNote = updatedNote
        appState.saveCurrentNote()
    }

    private func collectAllNotes(from folder: NoteFolder) -> [Note] {
        var notes = folder.notes
        for child in folder.children {
            notes.append(contentsOf: collectAllNotes(from: child))
        }
        return notes
    }

    private func findFolder(at path: String, in folder: NoteFolder) -> NoteFolder? {
        if folder.relativePath == path {
            return folder
        }
        for child in folder.children {
            if let found = findFolder(at: path, in: child) {
                return found
            }
        }
        return nil
    }
}

struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(note.displayTitle)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if note.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }

            Text(note.preview.isEmpty ? "No content" : note.preview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                Text(formatDate(note.modifiedAt))
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                if !note.tags.isEmpty {
                    Text("•")
                        .foregroundStyle(.tertiary)

                    ForEach(note.tags.prefix(3), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }

                Spacer()

                Text("\(note.wordCount) words")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NoteListView()
        .environmentObject(AppState())
        .frame(width: 300)
}
