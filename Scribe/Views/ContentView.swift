import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Group {
                if appState.notesRootPath.isEmpty {
                    WelcomeView()
                } else {
                    MainEditorView()
                }
            }

            // Quick Open overlay
            if appState.showQuickOpen {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        appState.showQuickOpen = false
                    }

                QuickOpenView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeOut(duration: 0.15), value: appState.showQuickOpen)
        .sheet(isPresented: $appState.showFolderPicker) {
            FolderPickerSheet()
        }
        .sheet(isPresented: $appState.showTemplatePicker) {
            TemplatePickerView()
        }
        .alert("Error", isPresented: .constant(appState.errorMessage != nil)) {
            Button("OK") { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }
}

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.linearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 100, height: 100)
                    .shadow(color: .blue.opacity(0.3), radius: 20, y: 10)

                Image(systemName: "pencil.line")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text("Welcome to Noteflow")
                    .font(.system(size: 32, weight: .bold))

                Text("Write beautifully. Store locally. Sync intelligently.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            // Features
            HStack(spacing: 32) {
                FeatureItem(icon: "doc.text", title: "Markdown", subtitle: "WYSIWYG editing")
                FeatureItem(icon: "folder", title: "Local Files", subtitle: "Your filesystem")
                FeatureItem(icon: "arrow.triangle.2.circlepath", title: "Atris Sync", subtitle: "Cloud backup")
            }
            .padding(.vertical)

            // CTA
            Button {
                appState.showFolderPicker = true
            } label: {
                HStack {
                    Image(systemName: "folder.badge.plus")
                    Text("Choose Notes Folder")
                }
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }

            Spacer()

            // Hint
            Text("⌘O to open folder • ⌘N for new note • ⌘P quick open")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color(nsColor: .controlBackgroundColor)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

struct FeatureItem: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(.blue)
                .frame(height: 32)

            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 100)
    }
}

struct FolderPickerSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Select Notes Folder")
                .font(.headline)

            Text("Your markdown notes will be stored here")
                .foregroundStyle(.secondary)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Choose Folder...") {
                    selectFolder()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(40)
        .frame(width: 400)
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Choose a folder for your notes"

        if panel.runModal() == .OK, let url = panel.url {
            appState.setNotesRoot(url)
            dismiss()
        }
    }
}

struct MainEditorView: View {
    @EnvironmentObject var appState: AppState
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        Group {
            if appState.focusMode {
                // Focus mode: just the editor, nothing else
                EditorDetailView()
            } else {
                // Normal mode: full navigation split view
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    SidebarView()
                        .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 350)
                } content: {
                    NoteListView()
                        .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
                } detail: {
                    EditorDetailView()
                }
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        toolbarItems
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.25), value: appState.focusMode)
    }

    @ViewBuilder
    private var toolbarItems: some View {
        // Sync status
        if appState.isSyncing {
            ProgressView()
                .scaleEffect(0.7)
        } else if case .success = appState.syncStatus {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }

        Button {
            Task { await appState.syncToAtris() }
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
        }
        .help("Sync to Atris")
        .disabled(appState.atrisToken.isEmpty || appState.selectedNote == nil)

        Divider()

        // Focus mode toggle
        Button {
            withAnimation(.easeOut(duration: 0.25)) {
                appState.focusMode.toggle()
            }
        } label: {
            Image(systemName: appState.focusMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
        }
        .help("Focus Mode (⌘⇧F)")

        // Outline toggle
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                appState.showOutline.toggle()
            }
        } label: {
            Image(systemName: "list.bullet.indent")
        }
        .help("Document Outline (⌘\\)")

        Button {
            appState.showSidebar.toggle()
        } label: {
            Image(systemName: "sidebar.left")
        }
        .help("Toggle Sidebar")

        Button {
            appState.createNewNote()
        } label: {
            Image(systemName: "square.and.pencil")
        }
        .help("New Note")
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
