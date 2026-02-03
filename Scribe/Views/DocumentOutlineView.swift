import SwiftUI

struct DocumentOutlineView: View {
    let content: String
    var onHeaderTap: ((String) -> Void)?

    private var headers: [HeaderItem] {
        extractHeaders(from: content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Outline")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(headers.count)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if headers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet.indent")
                        .font(.title2)
                        .foregroundStyle(.quaternary)

                    Text("No headers yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text("Add # headers to see outline")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(headers) { header in
                            HeaderRow(header: header) {
                                onHeaderTap?(header.text)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(width: 200)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
    }

    private func extractHeaders(from text: String) -> [HeaderItem] {
        var items: [HeaderItem] = []
        let lines = text.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("######") {
                let title = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                if !title.isEmpty {
                    items.append(HeaderItem(level: 6, text: title, lineIndex: index))
                }
            } else if trimmed.hasPrefix("#####") {
                let title = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                if !title.isEmpty {
                    items.append(HeaderItem(level: 5, text: title, lineIndex: index))
                }
            } else if trimmed.hasPrefix("####") {
                let title = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                if !title.isEmpty {
                    items.append(HeaderItem(level: 4, text: title, lineIndex: index))
                }
            } else if trimmed.hasPrefix("###") {
                let title = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                if !title.isEmpty {
                    items.append(HeaderItem(level: 3, text: title, lineIndex: index))
                }
            } else if trimmed.hasPrefix("##") {
                let title = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !title.isEmpty {
                    items.append(HeaderItem(level: 2, text: title, lineIndex: index))
                }
            } else if trimmed.hasPrefix("#") && !trimmed.hasPrefix("##") {
                let title = String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces)
                if !title.isEmpty {
                    items.append(HeaderItem(level: 1, text: title, lineIndex: index))
                }
            }
        }

        return items
    }
}

struct HeaderItem: Identifiable {
    let id = UUID()
    let level: Int
    let text: String
    let lineIndex: Int

    var indent: CGFloat {
        CGFloat((level - 1) * 12)
    }

    var fontSize: CGFloat {
        switch level {
        case 1: return 13
        case 2: return 12
        default: return 11
        }
    }

    var fontWeight: Font.Weight {
        switch level {
        case 1: return .semibold
        case 2: return .medium
        default: return .regular
        }
    }
}

struct HeaderRow: View {
    let header: HeaderItem
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                // Level indicator
                Circle()
                    .fill(levelColor)
                    .frame(width: 6, height: 6)

                Text(header.text)
                    .font(.system(size: header.fontSize, weight: header.fontWeight))
                    .foregroundStyle(isHovered ? .primary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()
            }
            .padding(.leading, header.indent)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var levelColor: Color {
        switch header.level {
        case 1: return .blue
        case 2: return .purple
        case 3: return .orange
        default: return .gray
        }
    }
}

#Preview {
    DocumentOutlineView(content: """
    # Welcome to Noteflow

    Some intro text here.

    ## Getting Started

    This is how you get started.

    ### Installation

    Download the app.

    ### Configuration

    Set up your preferences.

    ## Features

    ### Markdown Support

    Full markdown support.

    ### Focus Mode

    Distraction free writing.

    ## Conclusion

    Thanks for using Noteflow!
    """)
    .frame(height: 400)
}
