import SwiftUI

enum NoteTemplate: String, CaseIterable, Identifiable {
    case blank
    case meeting
    case project
    case brainstorm
    case weeklyReview
    case bookNotes
    case recipe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blank: return "Blank"
        case .meeting: return "Meeting Notes"
        case .project: return "Project"
        case .brainstorm: return "Brainstorm"
        case .weeklyReview: return "Weekly Review"
        case .bookNotes: return "Book Notes"
        case .recipe: return "Recipe"
        }
    }

    var icon: String {
        switch self {
        case .blank: return "doc"
        case .meeting: return "person.3"
        case .project: return "folder"
        case .brainstorm: return "lightbulb"
        case .weeklyReview: return "calendar"
        case .bookNotes: return "book"
        case .recipe: return "fork.knife"
        }
    }

    var description: String {
        switch self {
        case .blank: return "Start with an empty note"
        case .meeting: return "Attendees, agenda, and action items"
        case .project: return "Goals, tasks, and timeline"
        case .brainstorm: return "Ideas and mind mapping"
        case .weeklyReview: return "Reflect on your week"
        case .bookNotes: return "Capture insights from books"
        case .recipe: return "Ingredients and instructions"
        }
    }

    var content: String {
        switch self {
        case .blank:
            return ""
        case .meeting:
            return """
            ## Attendees
            -

            ## Agenda
            1.

            ## Discussion Notes


            ## Action Items
            - [ ]

            ## Next Meeting

            """
        case .project:
            return """
            ## Overview


            ## Goals
            -

            ## Tasks
            - [ ]

            ## Timeline
            | Milestone | Date |
            |-----------|------|
            |           |      |

            ## Resources
            -

            ## Notes

            """
        case .brainstorm:
            return """
            ## Main Idea


            ## Related Ideas
            -
            -
            -

            ## Questions
            -

            ## Potential Solutions
            1.
            2.
            3.

            ## Next Steps
            - [ ]

            """
        case .weeklyReview:
            return """
            ## Wins
            -

            ## Challenges
            -

            ## Lessons Learned
            -

            ## Next Week's Focus
            - [ ]

            ## Gratitude
            -

            ---
            *Week of [date]*
            """
        case .bookNotes:
            return """
            ## Book Info
            - **Author:**
            - **Published:**
            - **Rating:** ⭐️⭐️⭐️⭐️⭐️

            ## Summary


            ## Key Takeaways
            1.
            2.
            3.

            ## Favorite Quotes
            >

            ## How to Apply
            -

            """
        case .recipe:
            return """
            ## Ingredients
            -

            ## Equipment
            -

            ## Instructions
            1.

            ## Notes
            - **Prep time:**
            - **Cook time:**
            - **Servings:**

            ## Variations
            -

            """
        }
    }
}

struct TemplatePickerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var selectedTemplate: NoteTemplate = .blank
    @State private var noteTitle = ""
    @FocusState private var isTitleFocused: Bool

    private let columns = [
        GridItem(.adaptive(minimum: 140), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New from Template")
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

            // Title input
            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Note title", text: $noteTitle)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTitleFocused)
            }
            .padding()

            Divider()

            // Templates grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(NoteTemplate.allCases) { template in
                        TemplateCard(
                            template: template,
                            isSelected: selectedTemplate == template
                        )
                        .onTapGesture {
                            selectedTemplate = template
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create Note") {
                    createNote()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(noteTitle.isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 520)
        .onAppear {
            isTitleFocused = true
        }
    }

    private func createNote() {
        appState.createNoteFromTemplate(selectedTemplate, title: noteTitle)
        dismiss()
    }
}

struct TemplateCard: View {
    let template: NoteTemplate
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
                    .frame(width: 48, height: 48)

                Image(systemName: template.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? .accent : .secondary)
            }

            VStack(spacing: 2) {
                Text(template.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(template.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        )
    }
}

#Preview {
    TemplatePickerView()
        .environmentObject(AppState())
}
