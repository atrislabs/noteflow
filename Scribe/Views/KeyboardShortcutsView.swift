import SwiftUI

struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ShortcutSection(title: "General", shortcuts: [
                        ("⌘N", "New Note"),
                        ("⌘⇧N", "New Folder"),
                        ("⌘D", "Today's Daily Note"),
                        ("⌘O", "Open Notes Folder"),
                        ("⌘S", "Save"),
                        ("⌘⇧S", "Sync to Atris"),
                        ("⌘P", "Quick Open"),
                        ("⌘0", "Toggle Sidebar"),
                        ("⌘\\", "Toggle Outline"),
                        ("⌘⇧F", "Focus Mode"),
                        ("⌘⇧T", "Typewriter Mode"),
                        ("⌘,", "Settings"),
                        ("⌘?", "Keyboard Shortcuts"),
                    ])

                    ShortcutSection(title: "Formatting", shortcuts: [
                        ("⌘B", "Bold"),
                        ("⌘I", "Italic"),
                        ("⌘E", "Inline Code"),
                        ("⌘K", "Insert Link"),
                        ("⌘⇧K", "Code Block"),
                        ("⌘⇧D", "Strikethrough"),
                        ("⌘⇧H", "Highlight"),
                        ("⌘'", "Blockquote"),
                        ("⌘/", "Divider"),
                    ])

                    ShortcutSection(title: "Headings", shortcuts: [
                        ("⌘1", "Heading 1"),
                        ("⌘2", "Heading 2"),
                        ("⌘3", "Heading 3"),
                        ("⌘0", "Remove Heading"),
                    ])

                    ShortcutSection(title: "Lists", shortcuts: [
                        ("⌘⇧U", "Bullet List"),
                        ("⌘⇧O", "Numbered List"),
                        ("⌘⇧L", "To-do List"),
                        ("Tab", "Indent"),
                        ("⇧Tab", "Outdent"),
                        ("Enter", "Continue List"),
                    ])

                    ShortcutSection(title: "Editor", shortcuts: [
                        ("/", "Slash Commands"),
                        ("Esc", "Dismiss Menu"),
                    ])
                }
                .padding()
            }
        }
        .frame(width: 400, height: 500)
    }
}

struct ShortcutSection: View {
    let title: String
    let shortcuts: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(shortcuts, id: \.0) { key, description in
                HStack {
                    Text(description)

                    Spacer()

                    Text(key)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }
}

#Preview {
    KeyboardShortcutsView()
}
