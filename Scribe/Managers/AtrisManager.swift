import Foundation

actor AtrisManager {
    private let baseURL = "https://api.atris.ai/api"
    private let session = URLSession.shared

    enum AtrisError: LocalizedError {
        case invalidURL
        case networkError(Error)
        case invalidResponse
        case unauthorized
        case serverError(Int, String?)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid API URL"
            case .networkError(let error): return "Network error: \(error.localizedDescription)"
            case .invalidResponse: return "Invalid response from server"
            case .unauthorized: return "Unauthorized. Check your token."
            case .serverError(let code, let msg): return "Server error \(code): \(msg ?? "Unknown")"
            }
        }
    }

    // MARK: - Sync Note to Atris Journal

    func syncNote(_ note: Note, token: String, agentId: String) async throws {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateKey = dateFormatter.string(from: note.modifiedAt)

        guard let url = URL(string: "\(baseURL)/agents/\(agentId)/journal/\(dateKey)") else {
            throw AtrisError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "content": note.toMarkdown(),
            "metadata": [
                "title": note.title,
                "tags": note.tags,
                "source": "noteflow-mac",
                "localPath": note.relativePath
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AtrisError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299: return
        case 401: throw AtrisError.unauthorized
        default: throw AtrisError.serverError(httpResponse.statusCode, nil)
        }
    }

    // MARK: - Fetch Notes from Atris

    func fetchNotes(token: String, agentId: String, days: Int = 30) async throws -> [Note] {
        var notes: [Note] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Fetch last N days of journal entries
        for dayOffset in 0..<days {
            guard let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date()) else {
                continue
            }

            let dateKey = dateFormatter.string(from: date)

            guard let url = URL(string: "\(baseURL)/agents/\(agentId)/journal/\(dateKey)") else {
                continue
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else { continue }

                if httpResponse.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let content = json["content"] as? String,
                   !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

                    // Parse the markdown content
                    var title = "Atris Note - \(dateKey)"
                    var noteContent = content

                    let lines = content.components(separatedBy: .newlines)
                    if let firstLine = lines.first, firstLine.hasPrefix("# ") {
                        title = String(firstLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                        noteContent = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    }

                    // Check metadata for original info
                    if let metadata = json["metadata"] as? [String: Any] {
                        if let metaTitle = metadata["title"] as? String {
                            title = metaTitle
                        }
                    }

                    var note = Note(
                        title: title,
                        content: noteContent,
                        createdAt: date,
                        modifiedAt: date,
                        relativePath: "atris-sync"
                    )

                    // Get tags from metadata
                    if let metadata = json["metadata"] as? [String: Any],
                       let tags = metadata["tags"] as? [String] {
                        note.tags = tags
                    }

                    notes.append(note)
                }
            } catch {
                // Skip failed entries
                continue
            }
        }

        return notes
    }

    // MARK: - Store as Agent File

    func saveAsAgentFile(_ note: Note, token: String, agentId: String) async throws {
        guard let url = URL(string: "\(baseURL)/agents/\(agentId)/files") else {
            throw AtrisError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "name": note.fileName,
            "content": note.toMarkdown(),
            "path": "notes/\(note.relativePath)/\(note.fileName)"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AtrisError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw AtrisError.unauthorized
        }

        if httpResponse.statusCode >= 400 {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
            throw AtrisError.serverError(httpResponse.statusCode, msg)
        }
    }

    // MARK: - Quick AI Insight

    func getInsight(for note: Note, token: String, agentId: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/agent/\(agentId)/quick-chat") else {
            throw AtrisError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let prompt = """
        Give a brief, thoughtful insight about this note (2-3 sentences max):

        \(note.toMarkdown())
        """

        let body: [String: Any] = [
            "message": prompt,
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AtrisError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw AtrisError.unauthorized
        }

        // Parse SSE or JSON response
        let responseStr = String(data: data, encoding: .utf8) ?? ""
        var fullResponse = ""

        let lines = responseStr.components(separatedBy: "\n")
        for line in lines {
            if line.hasPrefix("data: ") {
                let jsonStr = String(line.dropFirst(6))
                if let jsonData = jsonStr.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let chunk = json["chunk"] as? String {
                    fullResponse += chunk
                }
            }
        }

        // Fallback to direct JSON
        if fullResponse.isEmpty {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = json["content"] as? String {
                fullResponse = content
            }
        }

        return fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
