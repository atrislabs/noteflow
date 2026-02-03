import SwiftUI
import AppKit

struct EditorDetailView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if let note = appState.selectedNote {
                NoteEditorView(note: Binding(
                    get: { note },
                    set: { appState.selectedNote = $0 }
                ))
            } else {
                emptyState
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(.quaternary)

            VStack(spacing: 8) {
                Text("No note selected")
                    .font(.title3)
                    .fontWeight(.medium)

                Text("Select a note from the sidebar or create a new one")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button {
                    appState.createNewNote()
                } label: {
                    Label("New Note", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    appState.showQuickOpen = true
                } label: {
                    Label("Quick Open", systemImage: "magnifyingglass")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Text("⌘N new note · ⌘D daily note · ⌘P quick open")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NoteEditorView: View {
    @EnvironmentObject var appState: AppState
    @Binding var note: Note
    @State private var showingImagePicker = false
    @FocusState private var isTitleFocused: Bool
    @State private var showFocusHint = false

    var body: some View {
        HStack(spacing: 0) {
            // Main editor
            ZStack {
                VStack(spacing: 0) {
                    // Title bar (hidden in focus mode)
                    if !appState.focusMode {
                        titleBar
                        Divider()
                    }

                    // WYSIWYG Markdown Editor
                    MarkdownEditor(
                        text: $note.content,
                        typewriterMode: appState.typewriterMode,
                        onImageDrop: { data, name in
                            Task { @MainActor in
                                await insertImage(data: data, name: name)
                            }
                        }
                    )

                    // Status bar (hidden in focus mode)
                    if !appState.focusMode {
                        statusBar
                    }
                }

                // Focus mode exit hint
                if appState.focusMode {
                    VStack {
                        HStack {
                            Spacer()
                            if showFocusHint {
                                Button {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        appState.focusMode = false
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                                        Text("Exit Focus")
                                        Text("⌘⇧F")
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.white.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding()
                        Spacer()
                    }
                    .onHover { hovering in
                        withAnimation(.easeOut(duration: 0.15)) {
                            showFocusHint = hovering
                        }
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor))

            // Document outline panel (hidden in focus mode)
            if appState.showOutline && !appState.focusMode {
                Divider()
                DocumentOutlineView(content: note.content) { headerText in
                    scrollToHeader(headerText)
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: appState.showOutline)
        .fileImporter(isPresented: $showingImagePicker, allowedContentTypes: [.image]) { result in
            handleImageImport(result)
        }
        .animation(.easeOut(duration: 0.2), value: appState.focusMode)
    }

    private var statusBar: some View {
        HStack(spacing: 16) {
            // Word count
            Text("\(note.wordCount) words")

            Text("•")
                .foregroundStyle(.quaternary)

            // Character count
            Text("\(note.content.count) characters")

            Text("•")
                .foregroundStyle(.quaternary)

            // Reading time
            Text("\(max(1, note.wordCount / 200)) min read")

            Spacer()

            // Typewriter mode indicator
            if appState.typewriterMode {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.and.down.text.horizontal")
                        .font(.caption2)
                    Text("Typewriter")
                }
                .foregroundStyle(.orange)
            }

            // Auto-save indicator
            if appState.autoSave {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text("Auto-save")
                }
            }

            // Path
            if !note.relativePath.isEmpty {
                Text(note.relativePath)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 40)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
    }

    private var titleBar: some View {
        VStack(spacing: 0) {
            // Title
            TextField("Title", text: $note.title)
                .textFieldStyle(.plain)
                .font(.system(size: 28, weight: .bold))
                .focused($isTitleFocused)
                .padding(.horizontal, 40)
                .padding(.top, 30)
                .padding(.bottom, 8)

            // Metadata bar
            HStack(spacing: 12) {
                // Date
                Label(formatDate(note.modifiedAt), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Word count
                Label("\(note.wordCount) words", systemImage: "text.word.spacing")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                // Tags
                ForEach(note.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }

                // Add image button
                Button {
                    showingImagePicker = true
                } label: {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Add Image (or drag & drop)")

                // Sync status
                if appState.isSyncing {
                    ProgressView()
                        .scaleEffect(0.6)
                } else if case .success = appState.syncStatus {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 16)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func handleImageImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            if let data = try? Data(contentsOf: url) {
                Task { @MainActor in
                    await insertImage(data: data, name: url.lastPathComponent)
                }
            }
        case .failure:
            break
        }
    }

    private func insertImage(data: Data, name: String) async {
        do {
            let relativePath = try await appState.fileManager.saveImage(
                data,
                named: name,
                for: note,
                rootPath: appState.notesRootPath
            )
            note.content += "\n\n![\(name)](\(relativePath))\n"
        } catch {
            appState.errorMessage = "Failed to save image: \(error.localizedDescription)"
        }
    }

    private func scrollToHeader(_ headerText: String) {
        // Post notification for MarkdownEditor to scroll to header
        NotificationCenter.default.post(
            name: .scrollToHeader,
            object: nil,
            userInfo: ["headerText": headerText]
        )
    }
}

#Preview {
    EditorDetailView()
        .environmentObject(AppState())
}
