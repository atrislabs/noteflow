import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    // MARK: - Published State
    @Published var rootFolder: NoteFolder?
    @Published var selectedNote: Note?
    @Published var selectedFolderPath: String?
    @Published var searchQuery: String = ""
    @Published var showSidebar: Bool = true
    @Published var showFolderPicker: Bool = false
    @Published var showQuickOpen: Bool = false
    @Published var showTemplatePicker: Bool = false
    @Published var focusMode: Bool = false
    @Published var showOutline: Bool = false
    @Published var typewriterMode: Bool = false
    @Published var isLoading: Bool = false
    @Published var isSyncing: Bool = false
    @Published var errorMessage: String?
    @Published var syncStatus: SyncStatus = .idle
    @Published var recentNotes: [Note] = []

    // MARK: - Managers
    let fileManager = NotesFileManager()
    let atrisManager = AtrisManager()

    // MARK: - Settings
    @AppStorage("notesRootPath") var notesRootPath: String = ""
    @AppStorage("atrisToken") var atrisToken: String = ""
    @AppStorage("atrisAgentId") var atrisAgentId: String = ""
    @AppStorage("autoSave") var autoSave: Bool = true
    @AppStorage("autoSync") var autoSync: Bool = false

    private var autoSaveTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    enum SyncStatus {
        case idle
        case syncing
        case success
        case error(String)
    }

    init() {
        setupAutoSave()
        if !notesRootPath.isEmpty {
            Task { await loadNotes() }
        }
    }

    // MARK: - Note Operations

    func loadNotes() async {
        guard !notesRootPath.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            rootFolder = try await fileManager.loadNotesFolder(at: notesRootPath)
        } catch {
            errorMessage = "Failed to load notes: \(error.localizedDescription)"
        }
    }

    func createNewNote() {
        let folderPath = selectedFolderPath ?? ""
        var note = Note(relativePath: folderPath)
        note.title = "Untitled"
        note.content = ""

        selectedNote = note

        // Add to folder structure
        if var folder = rootFolder {
            addNoteToFolder(&folder, note: note, at: folderPath)
            rootFolder = folder
        }
    }

    func createNoteFromTemplate(_ template: NoteTemplate, title: String) {
        let folderPath = selectedFolderPath ?? ""
        var note = Note(relativePath: folderPath)
        note.title = title
        note.content = template.content

        selectedNote = note

        // Add to folder structure
        if var folder = rootFolder {
            addNoteToFolder(&folder, note: note, at: folderPath)
            rootFolder = folder
        }

        // Save immediately
        saveCurrentNote()
    }

    func createNewFolder() {
        guard !notesRootPath.isEmpty else {
            showFolderPicker = true
            return
        }

        let parentPath = selectedFolderPath ?? ""
        let folderName = "New Folder"
        let newPath = parentPath.isEmpty ? folderName : "\(parentPath)/\(folderName)"

        let fullPath = (notesRootPath as NSString).appendingPathComponent(newPath)

        do {
            try Foundation.FileManager.default.createDirectory(atPath: fullPath, withIntermediateDirectories: true)
            Task { await loadNotes() }
        } catch {
            errorMessage = "Failed to create folder: \(error.localizedDescription)"
        }
    }

    func openDailyNote() {
        guard !notesRootPath.isEmpty else {
            showFolderPicker = true
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())

        let titleFormatter = DateFormatter()
        titleFormatter.dateFormat = "EEEE, MMMM d, yyyy"
        let titleDate = titleFormatter.string(from: Date())

        // Create Daily folder if needed
        let dailyFolderPath = (notesRootPath as NSString).appendingPathComponent("Daily")
        if !Foundation.FileManager.default.fileExists(atPath: dailyFolderPath) {
            try? Foundation.FileManager.default.createDirectory(atPath: dailyFolderPath, withIntermediateDirectories: true)
        }

        // Check if today's note exists
        let dailyNotePath = (dailyFolderPath as NSString).appendingPathComponent("\(dateString).md")

        if Foundation.FileManager.default.fileExists(atPath: dailyNotePath) {
            // Open existing daily note
            if let existingNote = findNote(inFolder: rootFolder, fileName: "\(dateString).md", relativePath: "Daily") {
                selectedNote = existingNote
                return
            }
        }

        // Create new daily note
        var note = Note(relativePath: "Daily")
        note.title = dateString
        note.content = """
        # \(titleDate)

        ## Tasks
        - [ ]

        ## Notes


        ## Gratitude


        """
        note.modifiedAt = Date()

        selectedNote = note

        // Save immediately
        Task {
            do {
                try await fileManager.saveNote(note, rootPath: notesRootPath)
                await loadNotes()
            } catch {
                errorMessage = "Failed to create daily note: \(error.localizedDescription)"
            }
        }
    }

    private func findNote(inFolder folder: NoteFolder?, fileName: String, relativePath: String) -> Note? {
        guard let folder = folder else { return nil }

        // Check current folder's notes
        if folder.relativePath == relativePath {
            return folder.notes.first { $0.fileName == fileName }
        }

        // Recurse into children
        for child in folder.children {
            if let found = findNote(inFolder: child, fileName: fileName, relativePath: relativePath) {
                return found
            }
        }

        return nil
    }

    func saveCurrentNote() {
        guard var note = selectedNote, !notesRootPath.isEmpty else { return }

        note.modifiedAt = Date()

        Task {
            do {
                try await fileManager.saveNote(note, rootPath: notesRootPath)

                // Update originalFileName after successful save
                note.originalFileName = note.fileName

                selectedNote = note

                // Update in folder structure
                if var folder = rootFolder {
                    updateNoteInFolder(&folder, note: note)
                    rootFolder = folder
                }

                // Re-extract tags from content
                let fullContent = note.toMarkdown()
                note.tags = extractTags(from: fullContent)
                selectedNote = note
            } catch {
                errorMessage = "Failed to save: \(error.localizedDescription)"
            }
        }
    }

    private func extractTags(from content: String) -> [String] {
        let pattern = #"(?:^|[\s\(])#([a-zA-Z]\w*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, range: range)

        var tags = Set<String>()
        for match in matches {
            if let tagRange = Range(match.range(at: 1), in: content) {
                tags.insert(String(content[tagRange]))
            }
        }

        return Array(tags).sorted()
    }

    func deleteNote(_ note: Note) {
        Task {
            do {
                try await fileManager.deleteNote(note, rootPath: notesRootPath)

                if selectedNote?.id == note.id {
                    selectedNote = nil
                }

                if var folder = rootFolder {
                    removeNoteFromFolder(&folder, noteId: note.id)
                    rootFolder = folder
                }
            } catch {
                errorMessage = "Failed to delete: \(error.localizedDescription)"
            }
        }
    }

    func setNotesRoot(_ url: URL) {
        notesRootPath = url.path
        Task { await loadNotes() }
    }

    // MARK: - Atris Sync

    func syncToAtris() async {
        guard !atrisToken.isEmpty, !atrisAgentId.isEmpty else {
            errorMessage = "Please configure Atris in Settings"
            return
        }

        guard let note = selectedNote else {
            errorMessage = "No note selected"
            return
        }

        syncStatus = .syncing
        isSyncing = true

        do {
            try await atrisManager.syncNote(
                note,
                token: atrisToken,
                agentId: atrisAgentId
            )
            syncStatus = .success

            // Reset to idle after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            syncStatus = .idle
        } catch {
            syncStatus = .error(error.localizedDescription)
            errorMessage = "Sync failed: \(error.localizedDescription)"
        }

        isSyncing = false
    }

    func pullFromAtris() async {
        guard !atrisToken.isEmpty, !atrisAgentId.isEmpty else {
            errorMessage = "Please configure Atris in Settings"
            return
        }

        syncStatus = .syncing
        isSyncing = true

        do {
            let notes = try await atrisManager.fetchNotes(
                token: atrisToken,
                agentId: atrisAgentId
            )

            for note in notes {
                try await fileManager.saveNote(note, rootPath: notesRootPath)
            }

            await loadNotes()
            syncStatus = .success
        } catch {
            syncStatus = .error(error.localizedDescription)
            errorMessage = "Pull failed: \(error.localizedDescription)"
        }

        isSyncing = false
    }

    // MARK: - Search

    var filteredNotes: [Note] {
        guard let folder = rootFolder else { return [] }

        let allNotes = collectAllNotes(from: folder)

        if searchQuery.isEmpty {
            return allNotes
        }

        let query = searchQuery.lowercased()
        return allNotes.filter { note in
            note.title.lowercased().contains(query) ||
            note.content.lowercased().contains(query) ||
            note.tags.contains { $0.lowercased().contains(query) }
        }
    }

    // MARK: - Private Helpers

    private func setupAutoSave() {
        $selectedNote
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.autoSave else { return }
                self.saveCurrentNote()
            }
            .store(in: &cancellables)

        // Track recent notes
        $selectedNote
            .compactMap { $0 }
            .sink { [weak self] note in
                self?.addToRecent(note)
            }
            .store(in: &cancellables)
    }

    private func addToRecent(_ note: Note) {
        recentNotes.removeAll { $0.id == note.id }
        recentNotes.insert(note, at: 0)
        if recentNotes.count > 10 {
            recentNotes = Array(recentNotes.prefix(10))
        }
    }

    private func collectAllNotes(from folder: NoteFolder) -> [Note] {
        var notes = folder.notes
        for child in folder.children {
            notes.append(contentsOf: collectAllNotes(from: child))
        }
        return notes.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    private func addNoteToFolder(_ folder: inout NoteFolder, note: Note, at path: String) {
        if path.isEmpty || folder.relativePath == path {
            folder.notes.append(note)
            return
        }

        for i in folder.children.indices {
            if path.hasPrefix(folder.children[i].relativePath) {
                addNoteToFolder(&folder.children[i], note: note, at: path)
                return
            }
        }

        folder.notes.append(note)
    }

    private func updateNoteInFolder(_ folder: inout NoteFolder, note: Note) {
        if let index = folder.notes.firstIndex(where: { $0.id == note.id }) {
            folder.notes[index] = note
            return
        }

        for i in folder.children.indices {
            updateNoteInFolder(&folder.children[i], note: note)
        }
    }

    private func removeNoteFromFolder(_ folder: inout NoteFolder, noteId: UUID) {
        folder.notes.removeAll { $0.id == noteId }

        for i in folder.children.indices {
            removeNoteFromFolder(&folder.children[i], noteId: noteId)
        }
    }
}
