import Foundation
import CryptoKit

struct Note: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var modifiedAt: Date
    var tags: [String]
    var isFavorite: Bool
    var relativePath: String // Folder path relative to notes root
    var originalFileName: String? // Track original filename for renames

    var fileName: String {
        let name = title.isEmpty ? "Untitled" : title.sanitizedFileName
        return "\(name).md"
    }

    var displayTitle: String {
        title.isEmpty ? "Untitled" : title
    }

    var wordCount: Int {
        content.split { $0.isWhitespace || $0.isNewline }.count
    }

    var characterCount: Int {
        content.count
    }

    var preview: String {
        let text = content
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .filter { !$0.hasPrefix("#") }
            .joined(separator: " ")
        return String(text.prefix(200))
    }

    init(
        id: UUID = UUID(),
        title: String = "",
        content: String = "",
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        tags: [String] = [],
        isFavorite: Bool = false,
        relativePath: String = "",
        originalFileName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.tags = tags
        self.isFavorite = isFavorite
        self.relativePath = relativePath
        self.originalFileName = originalFileName
    }

    /// Create a stable ID from file path so notes keep identity across reloads
    static func stableID(for filePath: String) -> UUID {
        let hash = SHA256.hash(data: Data(filePath.utf8))
        let hashBytes = Array(hash.prefix(16))
        return UUID(uuid: (
            hashBytes[0], hashBytes[1], hashBytes[2], hashBytes[3],
            hashBytes[4], hashBytes[5], hashBytes[6], hashBytes[7],
            hashBytes[8], hashBytes[9], hashBytes[10], hashBytes[11],
            hashBytes[12], hashBytes[13], hashBytes[14], hashBytes[15]
        ))
    }

    static func fromFile(at url: URL, relativeTo rootPath: String) throws -> Note {
        let content = try String(contentsOf: url, encoding: .utf8)

        let folderPath = url.deletingLastPathComponent().path
            .replacingOccurrences(of: rootPath, with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        let actualFileName = url.lastPathComponent

        // Stable ID based on original file path
        let stableId = stableID(for: url.path)

        var note = Note(
            id: stableId,
            relativePath: folderPath,
            originalFileName: actualFileName
        )

        // Parse content
        let lines = content.components(separatedBy: .newlines)

        // Extract title from first H1 heading or use filename
        if let firstLine = lines.first, firstLine.hasPrefix("# ") {
            note.title = String(firstLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            note.content = lines.dropFirst()
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // Use filename as title
            note.title = (actualFileName as NSString).deletingPathExtension
            note.content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Extract tags from content
        note.tags = extractTags(from: content)

        // Get file dates
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        note.createdAt = attrs[.creationDate] as? Date ?? Date()
        note.modifiedAt = attrs[.modificationDate] as? Date ?? Date()

        return note
    }

    private static func extractTags(from content: String) -> [String] {
        // Match #tag but not ## headings
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

    func toMarkdown() -> String {
        if title.isEmpty {
            return content
        }
        return "# \(title)\n\n\(content)"
    }

    /// Check if title changed and we need to rename the file
    var needsRename: Bool {
        guard let original = originalFileName else { return false }
        return original != fileName
    }
}

struct NoteFolder: Identifiable, Hashable {
    let id: UUID
    var name: String
    var relativePath: String
    var children: [NoteFolder]
    var notes: [Note]

    var isEmpty: Bool {
        notes.isEmpty && children.allSatisfy { $0.isEmpty }
    }

    var totalNotes: Int {
        notes.count + children.reduce(0) { $0 + $1.totalNotes }
    }

    init(id: UUID = UUID(), name: String, relativePath: String, children: [NoteFolder] = [], notes: [Note] = []) {
        self.id = id
        self.name = name
        self.relativePath = relativePath
        self.children = children
        self.notes = notes
    }
}

extension String {
    var sanitizedFileName: String {
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|#")
        var result = self.components(separatedBy: invalidChars).joined(separator: "-")
        result = result.trimmingCharacters(in: .whitespaces)
        result = result.replacingOccurrences(of: "  ", with: " ")

        // Limit length
        if result.count > 100 {
            result = String(result.prefix(100))
        }

        // Ensure not empty
        if result.isEmpty {
            result = "Untitled"
        }

        return result
    }
}
