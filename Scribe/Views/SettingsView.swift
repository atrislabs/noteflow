import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AtrisSettingsView()
                .tabItem {
                    Label("Atris", systemImage: "cloud")
                }

            EditorSettingsView()
                .tabItem {
                    Label("Editor", systemImage: "pencil")
                }

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 420)
    }
}

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            // App icon
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.linearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)

                Image(systemName: "doc.text")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Text("Noteflow")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Version 1.0")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("Beautiful markdown notes for Mac")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.horizontal, 40)

            VStack(spacing: 8) {
                Link("Visit atris.ai", destination: URL(string: "https://atris.ai/noteflow")!)
                    .font(.subheadline)

                Link("Report an Issue", destination: URL(string: "https://github.com/atris-ai/noteflow/issues")!)
                    .font(.subheadline)
            }

            Spacer()

            Text("© 2025 Atris AI")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 30)
        .padding(.bottom, 20)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Notes Folder")
                            .font(.headline)

                        if appState.notesRootPath.isEmpty {
                            Text("Not selected")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(appState.notesRootPath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }

                    Spacer()

                    Button("Change...") {
                        selectFolder()
                    }
                }

                Toggle("Auto-save notes", isOn: $appState.autoSave)

                Toggle("Auto-sync to Atris", isOn: $appState.autoSync)
                    .disabled(appState.atrisToken.isEmpty)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            appState.setNotesRoot(url)
        }
    }
}

struct AtrisSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showToken = false
    @State private var testStatus: TestStatus = .idle

    enum TestStatus {
        case idle
        case testing
        case success
        case error(String)
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Token")
                        .font(.headline)

                    HStack {
                        if showToken {
                            TextField("Token", text: $appState.atrisToken)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("Token", text: $appState.atrisToken)
                                .textFieldStyle(.roundedBorder)
                        }

                        Button {
                            showToken.toggle()
                        } label: {
                            Image(systemName: showToken ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Get your token from atris.ai/settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Agent ID")
                        .font(.headline)

                    TextField("Agent ID", text: $appState.atrisAgentId)
                        .textFieldStyle(.roundedBorder)

                    Text("The agent to sync notes with")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                HStack {
                    Button("Test Connection") {
                        testConnection()
                    }
                    .disabled(appState.atrisToken.isEmpty || appState.atrisAgentId.isEmpty)

                    Spacer()

                    switch testStatus {
                    case .idle:
                        EmptyView()
                    case .testing:
                        ProgressView()
                            .scaleEffect(0.7)
                    case .success:
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .error(let message):
                        Label(message, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sync Options")
                        .font(.headline)

                    Button("Pull Notes from Atris") {
                        Task { await appState.pullFromAtris() }
                    }
                    .disabled(appState.atrisToken.isEmpty)

                    Text("Download notes from Atris to your local folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func testConnection() {
        testStatus = .testing

        Task {
            do {
                _ = try await appState.atrisManager.fetchNotes(
                    token: appState.atrisToken,
                    agentId: appState.atrisAgentId,
                    days: 1
                )
                testStatus = .success

                try? await Task.sleep(nanoseconds: 3_000_000_000)
                testStatus = .idle
            } catch {
                testStatus = .error(error.localizedDescription)
            }
        }
    }
}

struct EditorSettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("editorFontSize") var fontSize: Double = 16
    @AppStorage("editorLineSpacing") var lineSpacing: Double = 1.5

    var body: some View {
        Form {
            Section("Typography") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Font Size")
                        Spacer()
                        Text("\(Int(fontSize)) pt")
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $fontSize, in: 12...28, step: 1)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Line Spacing")
                        Spacer()
                        Text(String(format: "%.1f", lineSpacing))
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $lineSpacing, in: 1.0...2.5, step: 0.1)
                }
            }

            Section("Preview") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("# Heading")
                        .font(.system(size: CGFloat(fontSize) * 1.8, weight: .bold))

                    Text("The quick **brown** fox jumps over the *lazy* dog.")
                        .font(.system(size: CGFloat(fontSize)))
                        .lineSpacing(CGFloat(lineSpacing * 4))

                    Text("`inline code`")
                        .font(.system(size: CGFloat(fontSize) * 0.9, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
