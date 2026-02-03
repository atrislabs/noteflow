import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search", text: $appState.searchQuery)
                    .textFieldStyle(.plain)

                if !appState.searchQuery.isEmpty {
                    Button {
                        appState.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding()

            Divider()

            // Folder tree
            if appState.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let rootFolder = appState.rootFolder {
                List(selection: $appState.selectedFolderPath) {
                    // All Notes
                    SidebarItem(
                        icon: "doc.text",
                        title: "All Notes",
                        count: countAllNotes(in: rootFolder),
                        isSelected: appState.selectedFolderPath == nil
                    )
                    .tag(nil as String?)
                    .onTapGesture {
                        appState.selectedFolderPath = nil
                    }

                    // Favorites
                    SidebarItem(
                        icon: "star.fill",
                        title: "Favorites",
                        count: countFavorites(in: rootFolder),
                        isSelected: appState.selectedFolderPath == "__favorites__"
                    )
                    .tag("__favorites__" as String?)
                    .onTapGesture {
                        appState.selectedFolderPath = "__favorites__"
                    }

                    Section("Folders") {
                        ForEach(rootFolder.children, id: \.id) { folder in
                            FolderRow(folder: folder)
                        }
                    }

                    Section("Tags") {
                        ForEach(collectTags(from: rootFolder), id: \.self) { tag in
                            SidebarItem(
                                icon: "tag",
                                title: "#\(tag)",
                                count: countNotesWithTag(tag, in: rootFolder),
                                isSelected: appState.selectedFolderPath == "__tag__\(tag)"
                            )
                            .tag("__tag__\(tag)" as String?)
                            .onTapGesture {
                                appState.selectedFolderPath = "__tag__\(tag)"
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            } else {
                Text("No notes folder selected")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Noteflow")
    }

    private func countAllNotes(in folder: NoteFolder) -> Int {
        var count = folder.notes.count
        for child in folder.children {
            count += countAllNotes(in: child)
        }
        return count
    }

    private func countFavorites(in folder: NoteFolder) -> Int {
        var count = folder.notes.filter { $0.isFavorite }.count
        for child in folder.children {
            count += countFavorites(in: child)
        }
        return count
    }

    private func collectTags(from folder: NoteFolder) -> [String] {
        var tags = Set<String>()
        collectTagsRecursive(from: folder, into: &tags)
        return Array(tags).sorted()
    }

    private func collectTagsRecursive(from folder: NoteFolder, into tags: inout Set<String>) {
        for note in folder.notes {
            tags.formUnion(note.tags)
        }
        for child in folder.children {
            collectTagsRecursive(from: child, into: &tags)
        }
    }

    private func countNotesWithTag(_ tag: String, in folder: NoteFolder) -> Int {
        var count = folder.notes.filter { $0.tags.contains(tag) }.count
        for child in folder.children {
            count += countNotesWithTag(tag, in: child)
        }
        return count
    }
}

struct SidebarItem: View {
    let icon: String
    let title: String
    let count: Int
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 20)

            Text(title)
                .lineLimit(1)

            Spacer()

            Text("\(count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

struct FolderRow: View {
    @EnvironmentObject var appState: AppState
    let folder: NoteFolder
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(folder.children, id: \.id) { child in
                FolderRow(folder: child)
            }
        } label: {
            HStack {
                Image(systemName: isExpanded ? "folder.fill" : "folder")
                    .foregroundStyle(.orange)

                Text(folder.name)
                    .lineLimit(1)

                Spacer()

                Text("\(folder.notes.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                appState.selectedFolderPath = folder.relativePath
            }
        }
    }
}

#Preview {
    SidebarView()
        .environmentObject(AppState())
        .frame(width: 250)
}
