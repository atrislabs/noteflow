import SwiftUI
import WebKit

// MARK: - Notification Names for Format Commands

extension Notification.Name {
    static let formatBold = Notification.Name("formatBold")
    static let formatItalic = Notification.Name("formatItalic")
    static let formatCode = Notification.Name("formatCode")
    static let formatHeading1 = Notification.Name("formatHeading1")
    static let formatHeading2 = Notification.Name("formatHeading2")
    static let formatHeading3 = Notification.Name("formatHeading3")
    static let formatLink = Notification.Name("formatLink")
    static let formatDivider = Notification.Name("formatDivider")
    static let scrollToHeader = Notification.Name("scrollToHeader")
}

@main
struct NoteflowApp: App {
    @StateObject private var appState = AppState()
    @State private var showKeyboardShortcuts = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
                .navigationTitle(appState.selectedNote?.displayTitle ?? "Noteflow")
                .sheet(isPresented: $showKeyboardShortcuts) {
                    KeyboardShortcutsView()
                }
        }
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    appState.createNewNote()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Folder") {
                    appState.createNewFolder()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("Today's Note") {
                    appState.openDailyNote()
                }
                .keyboardShortcut("d", modifiers: .command)

                Button("New from Template...") {
                    appState.showTemplatePicker = true
                }
                .keyboardShortcut("n", modifiers: [.command, .option])

                Divider()

                Button("Open Notes Folder...") {
                    appState.showFolderPicker = true
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandGroup(after: .saveItem) {
                Button("Save") {
                    appState.saveCurrentNote()
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Sync to Atris") {
                    Task { await appState.syncToAtris() }
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Divider()

                Button("Export as HTML...") {
                    exportAsHTML()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(appState.selectedNote == nil)
            }

            CommandGroup(replacing: .importExport) {
                Button("Export as HTML...") {
                    exportAsHTML()
                }
                .disabled(appState.selectedNote == nil)

                Button("Export as PDF...") {
                    exportAsPDF()
                }
                .disabled(appState.selectedNote == nil)
            }

            CommandGroup(replacing: .textEditing) {
                Button("Quick Open") {
                    appState.showQuickOpen = true
                }
                .keyboardShortcut("p", modifiers: .command)
            }

            CommandMenu("View") {
                Button(appState.showSidebar ? "Hide Sidebar" : "Show Sidebar") {
                    appState.showSidebar.toggle()
                }
                .keyboardShortcut("0", modifiers: .command)

                Button(appState.showOutline ? "Hide Outline" : "Show Outline") {
                    withAnimation(.easeOut(duration: 0.2)) {
                        appState.showOutline.toggle()
                    }
                }
                .keyboardShortcut("\\", modifiers: .command)

                Divider()

                Button(appState.focusMode ? "Exit Focus Mode" : "Enter Focus Mode") {
                    withAnimation(.easeOut(duration: 0.25)) {
                        appState.focusMode.toggle()
                    }
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])

                Button(appState.typewriterMode ? "Exit Typewriter Mode" : "Enter Typewriter Mode") {
                    withAnimation(.easeOut(duration: 0.2)) {
                        appState.typewriterMode.toggle()
                    }
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])

                Divider()

                Button("Quick Open") {
                    appState.showQuickOpen = true
                }
                .keyboardShortcut("p", modifiers: .command)
            }

            CommandMenu("Format") {
                Button("Bold") {
                    NotificationCenter.default.post(name: .formatBold, object: nil)
                }
                .keyboardShortcut("b", modifiers: .command)

                Button("Italic") {
                    NotificationCenter.default.post(name: .formatItalic, object: nil)
                }
                .keyboardShortcut("i", modifiers: .command)

                Button("Code") {
                    NotificationCenter.default.post(name: .formatCode, object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)

                Divider()

                Button("Heading 1") {
                    NotificationCenter.default.post(name: .formatHeading1, object: nil)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Heading 2") {
                    NotificationCenter.default.post(name: .formatHeading2, object: nil)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Heading 3") {
                    NotificationCenter.default.post(name: .formatHeading3, object: nil)
                }
                .keyboardShortcut("3", modifiers: .command)

                Divider()

                Button("Insert Link") {
                    NotificationCenter.default.post(name: .formatLink, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)

                Button("Insert Divider") {
                    NotificationCenter.default.post(name: .formatDivider, object: nil)
                }
                .keyboardShortcut("/", modifiers: .command)
            }

            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts") {
                    showKeyboardShortcuts = true
                }
                .keyboardShortcut("?", modifiers: .command)

                Divider()

                Link("Noteflow Documentation", destination: URL(string: "https://atris.ai/noteflow")!)
                Link("Report an Issue", destination: URL(string: "https://github.com/atris-ai/noteflow/issues")!)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }

    private func exportAsHTML() {
        guard let note = appState.selectedNote else { return }

        Task {
            let html = await appState.fileManager.exportToHTML(note)

            await MainActor.run {
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.html]
                panel.nameFieldStringValue = "\(note.title).html"
                panel.canCreateDirectories = true

                if panel.runModal() == .OK, let url = panel.url {
                    try? html.write(to: url, atomically: true, encoding: .utf8)
                }
            }
        }
    }

    private func exportAsPDF() {
        guard let note = appState.selectedNote else { return }

        Task {
            let html = await appState.fileManager.exportToHTML(note)

            await MainActor.run {
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.pdf]
                panel.nameFieldStringValue = "\(note.title).pdf"
                panel.canCreateDirectories = true

                if panel.runModal() == .OK, let url = panel.url {
                    // Create PDF from HTML using WebKit
                    let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 1000))
                    webView.loadHTMLString(html, baseURL: nil)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        let config = WKPDFConfiguration()
                        config.rect = CGRect(x: 0, y: 0, width: 612, height: 792) // Letter size

                        webView.createPDF(configuration: config) { result in
                            if case .success(let data) = result {
                                try? data.write(to: url)
                            }
                        }
                    }
                }
            }
        }
    }
}
