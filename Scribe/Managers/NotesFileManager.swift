import Foundation
import AppKit

actor NotesFileManager {
    private let fm = FileManager.default

    // MARK: - Load

    func loadNotesFolder(at rootPath: String) throws -> NoteFolder {
        let rootURL = URL(fileURLWithPath: rootPath)
        guard fm.fileExists(atPath: rootPath) else {
            throw NSError(domain: "NotesFileManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Notes folder doesn't exist"])
        }
        return try loadFolder(at: rootURL, relativeTo: rootPath, name: rootURL.lastPathComponent)
    }

    private func loadFolder(at url: URL, relativeTo rootPath: String, name: String) throws -> NoteFolder {
        let relativePath = url.path
            .replacingOccurrences(of: rootPath, with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        var folder = NoteFolder(name: name, relativePath: relativePath)

        let contents = try fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        for itemURL in contents {
            let resourceValues = try itemURL.resourceValues(forKeys: [.isDirectoryKey])

            if resourceValues.isDirectory == true {
                // Skip assets folders
                if itemURL.lastPathComponent == "assets" {
                    continue
                }

                let childFolder = try loadFolder(
                    at: itemURL,
                    relativeTo: rootPath,
                    name: itemURL.lastPathComponent
                )
                folder.children.append(childFolder)
            } else if itemURL.pathExtension.lowercased() == "md" {
                do {
                    let note = try Note.fromFile(at: itemURL, relativeTo: rootPath)
                    folder.notes.append(note)
                } catch {
                    // Skip files that can't be read
                }
            }
        }

        folder.children.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        folder.notes.sort { $0.modifiedAt > $1.modifiedAt }

        return folder
    }

    // MARK: - Save

    func saveNote(_ note: Note, rootPath: String) throws {
        let folderPath = buildFolderPath(for: note, rootPath: rootPath)

        // Ensure folder exists
        if !fm.fileExists(atPath: folderPath) {
            try fm.createDirectory(atPath: folderPath, withIntermediateDirectories: true)
        }

        // Handle rename: delete old file if filename changed
        if note.needsRename, let oldFileName = note.originalFileName {
            let oldPath = (folderPath as NSString).appendingPathComponent(oldFileName)
            if fm.fileExists(atPath: oldPath) {
                try fm.removeItem(atPath: oldPath)
            }
        }

        // Write new file
        let filePath = (folderPath as NSString).appendingPathComponent(note.fileName)
        let content = note.toMarkdown()

        try content.write(toFile: filePath, atomically: true, encoding: .utf8)
    }

    // MARK: - Delete

    func deleteNote(_ note: Note, rootPath: String) throws {
        let folderPath = buildFolderPath(for: note, rootPath: rootPath)

        // Try to delete by current filename
        let filePath = (folderPath as NSString).appendingPathComponent(note.fileName)
        if fm.fileExists(atPath: filePath) {
            try fm.trashItem(at: URL(fileURLWithPath: filePath), resultingItemURL: nil)
            return
        }

        // Fallback: try original filename
        if let originalFileName = note.originalFileName {
            let originalPath = (folderPath as NSString).appendingPathComponent(originalFileName)
            if fm.fileExists(atPath: originalPath) {
                try fm.trashItem(at: URL(fileURLWithPath: originalPath), resultingItemURL: nil)
            }
        }
    }

    // MARK: - Move/Rename

    func moveNote(_ note: Note, to newFolderPath: String, rootPath: String) throws {
        let oldFolderPath = buildFolderPath(for: note, rootPath: rootPath)
        let oldFileName = note.originalFileName ?? note.fileName
        let oldFilePath = (oldFolderPath as NSString).appendingPathComponent(oldFileName)

        let newFolderFullPath = newFolderPath.isEmpty ? rootPath : (rootPath as NSString).appendingPathComponent(newFolderPath)
        let newFilePath = (newFolderFullPath as NSString).appendingPathComponent(note.fileName)

        // Ensure destination exists
        if !fm.fileExists(atPath: newFolderFullPath) {
            try fm.createDirectory(atPath: newFolderFullPath, withIntermediateDirectories: true)
        }

        // Move file
        if fm.fileExists(atPath: oldFilePath) {
            try fm.moveItem(atPath: oldFilePath, toPath: newFilePath)
        }
    }

    // MARK: - Create Folder

    func createFolder(named name: String, at parentPath: String, rootPath: String) throws {
        let parentFullPath = parentPath.isEmpty ? rootPath : (rootPath as NSString).appendingPathComponent(parentPath)
        let newFolderPath = (parentFullPath as NSString).appendingPathComponent(name)

        try fm.createDirectory(atPath: newFolderPath, withIntermediateDirectories: true)
    }

    // MARK: - Images

    func saveImage(_ imageData: Data, named name: String, for note: Note, rootPath: String) throws -> String {
        let folderPath = buildFolderPath(for: note, rootPath: rootPath)
        let assetsPath = (folderPath as NSString).appendingPathComponent("assets")

        if !fm.fileExists(atPath: assetsPath) {
            try fm.createDirectory(atPath: assetsPath, withIntermediateDirectories: true)
        }

        // Clean filename
        let cleanName = name.replacingOccurrences(of: " ", with: "-")
            .lowercased()

        let fileName = "\(UUID().uuidString.prefix(8))-\(cleanName)"
        let filePath = (assetsPath as NSString).appendingPathComponent(fileName)

        try imageData.write(to: URL(fileURLWithPath: filePath))

        return "assets/\(fileName)"
    }

    // MARK: - Helpers

    private func buildFolderPath(for note: Note, rootPath: String) -> String {
        if note.relativePath.isEmpty {
            return rootPath
        }
        return (rootPath as NSString).appendingPathComponent(note.relativePath)
    }

    // MARK: - Export

    func exportToHTML(_ note: Note) -> String {
        let content = note.toMarkdown()

        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(escapeHTML(note.title))</title>
            <style>
                * { box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
                    max-width: 750px;
                    margin: 0 auto;
                    padding: 48px 24px;
                    line-height: 1.7;
                    color: #1a1a1a;
                    background: #fff;
                }
                h1 { font-size: 2.2em; margin: 0 0 0.5em; font-weight: 700; }
                h2 { font-size: 1.6em; margin: 1.8em 0 0.6em; font-weight: 600; }
                h3 { font-size: 1.3em; margin: 1.5em 0 0.5em; font-weight: 600; }
                h4, h5, h6 { font-size: 1.1em; margin: 1.2em 0 0.4em; font-weight: 600; }
                p { margin: 0 0 1.2em; }
                a { color: #0066cc; text-decoration: none; }
                a:hover { text-decoration: underline; }
                code {
                    font-family: 'SF Mono', Menlo, Monaco, 'Courier New', monospace;
                    font-size: 0.9em;
                    background: #f5f5f5;
                    padding: 2px 6px;
                    border-radius: 4px;
                }
                pre {
                    background: #f5f5f5;
                    padding: 16px 20px;
                    border-radius: 8px;
                    overflow-x: auto;
                    margin: 1.5em 0;
                }
                pre code {
                    background: none;
                    padding: 0;
                    font-size: 0.85em;
                }
                blockquote {
                    border-left: 4px solid #e0e0e0;
                    margin: 1.5em 0;
                    padding: 0.5em 0 0.5em 20px;
                    color: #555;
                }
                blockquote p { margin: 0; }
                ul, ol { margin: 0 0 1.2em; padding-left: 1.5em; }
                li { margin: 0.3em 0; }
                img { max-width: 100%; height: auto; border-radius: 8px; margin: 1em 0; }
                hr { border: none; border-top: 1px solid #e0e0e0; margin: 2.5em 0; }
                table { border-collapse: collapse; width: 100%; margin: 1.5em 0; }
                th, td { border: 1px solid #e0e0e0; padding: 10px 14px; text-align: left; }
                th { background: #f9f9f9; font-weight: 600; }
                del { color: #888; }
                .meta { color: #888; font-size: 0.9em; margin-bottom: 2em; }
            </style>
        </head>
        <body>
        """

        // Add metadata
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        html += "<div class=\"meta\">\(dateFormatter.string(from: note.modifiedAt))"
        if !note.tags.isEmpty {
            html += " · " + note.tags.map { "#\($0)" }.joined(separator: " ")
        }
        html += "</div>\n"

        // Convert markdown to HTML
        html += convertMarkdownToHTML(content)

        html += "</body></html>"
        return html
    }

    private func convertMarkdownToHTML(_ markdown: String) -> String {
        var html = ""
        var inCodeBlock = false
        var inList = false
        var listType: String? = nil
        let lines = markdown.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Code blocks
            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    html += "</code></pre>\n"
                    inCodeBlock = false
                } else {
                    html += "<pre><code>"
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock {
                html += escapeHTML(line) + "\n"
                continue
            }

            // Close list if needed
            let startsWithNumber = trimmed.first?.isNumber == true
            if inList && !trimmed.hasPrefix("- ") && !trimmed.hasPrefix("* ") && !trimmed.hasPrefix("+ ") && !startsWithNumber {
                html += "</\(listType!)>\n"
                inList = false
                listType = nil
            }

            var processed = line

            // Headings
            if trimmed.hasPrefix("######") {
                processed = "<h6>\(processInline(String(trimmed.dropFirst(7))))</h6>"
            } else if trimmed.hasPrefix("#####") {
                processed = "<h5>\(processInline(String(trimmed.dropFirst(6))))</h5>"
            } else if trimmed.hasPrefix("####") {
                processed = "<h4>\(processInline(String(trimmed.dropFirst(5))))</h4>"
            } else if trimmed.hasPrefix("###") {
                processed = "<h3>\(processInline(String(trimmed.dropFirst(4))))</h3>"
            } else if trimmed.hasPrefix("##") {
                processed = "<h2>\(processInline(String(trimmed.dropFirst(3))))</h2>"
            } else if trimmed.hasPrefix("#") {
                processed = "<h1>\(processInline(String(trimmed.dropFirst(2))))</h1>"
            }
            // Blockquote
            else if trimmed.hasPrefix(">") {
                let quoteContent = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                processed = "<blockquote><p>\(processInline(quoteContent))</p></blockquote>"
            }
            // Horizontal rule
            else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                processed = "<hr>"
            }
            // Unordered list
            else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                if !inList {
                    html += "<ul>\n"
                    inList = true
                    listType = "ul"
                }
                let itemContent = String(trimmed.dropFirst(2))
                processed = "<li>\(processInline(itemContent))</li>"
            }
            // Ordered list
            else if let firstChar = trimmed.first, firstChar.isNumber, trimmed.contains(". ") {
                if !inList {
                    html += "<ol>\n"
                    inList = true
                    listType = "ol"
                }
                if let dotIndex = trimmed.firstIndex(of: ".") {
                    let itemContent = String(trimmed[trimmed.index(after: dotIndex)...]).trimmingCharacters(in: .whitespaces)
                    processed = "<li>\(processInline(itemContent))</li>"
                }
            }
            // Empty line
            else if trimmed.isEmpty {
                processed = ""
            }
            // Paragraph
            else {
                processed = "<p>\(processInline(processed))</p>"
            }

            html += processed + "\n"
        }

        // Close any open list
        if inList {
            html += "</\(listType!)>\n"
        }

        return html
    }

    private func processInline(_ text: String) -> String {
        var result = escapeHTML(text)

        // Images (before links to avoid conflict)
        result = result.replacingOccurrences(of: #"!\[([^\]]*)\]\(([^)]+)\)"#, with: "<img src=\"$2\" alt=\"$1\">", options: .regularExpression)

        // Links
        result = result.replacingOccurrences(of: #"\[([^\]]+)\]\(([^)]+)\)"#, with: "<a href=\"$2\">$1</a>", options: .regularExpression)

        // Bold + Italic
        result = result.replacingOccurrences(of: #"\*\*\*(.+?)\*\*\*"#, with: "<strong><em>$1</em></strong>", options: .regularExpression)

        // Bold
        result = result.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)
        result = result.replacingOccurrences(of: #"__(.+?)__"#, with: "<strong>$1</strong>", options: .regularExpression)

        // Italic
        result = result.replacingOccurrences(of: #"\*(.+?)\*"#, with: "<em>$1</em>", options: .regularExpression)
        result = result.replacingOccurrences(of: #"_(.+?)_"#, with: "<em>$1</em>", options: .regularExpression)

        // Strikethrough
        result = result.replacingOccurrences(of: #"~~(.+?)~~"#, with: "<del>$1</del>", options: .regularExpression)

        // Inline code
        result = result.replacingOccurrences(of: #"`([^`]+)`"#, with: "<code>$1</code>", options: .regularExpression)

        return result
    }

    private func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
