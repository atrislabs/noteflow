import SwiftUI
import AppKit

// MARK: - World-Class Markdown Editor

struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    var typewriterMode: Bool = false
    var onImageDrop: ((Data, String) -> Void)?

    func makeNSView(context: Context) -> EditorScrollView {
        let scrollView = EditorScrollView()
        let textView = EditorTextView()

        // Configure text view
        textView.configure()
        textView.delegate = context.coordinator
        textView.onImageDrop = onImageDrop
        textView.editorCoordinator = context.coordinator

        // Configure scroll view
        scrollView.configure(with: textView)

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView

        return scrollView
    }

    func updateNSView(_ scrollView: EditorScrollView, context: Context) {
        guard let textView = scrollView.documentView as? EditorTextView else { return }

        context.coordinator.typewriterMode = typewriterMode

        if textView.string != text && !context.coordinator.isHighlighting {
            let selection = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selection
            context.coordinator.highlight()
        }
    }

    func makeCoordinator() -> EditorCoordinator {
        EditorCoordinator(self)
    }
}

// MARK: - Design System

enum Design {
    enum Font {
        static let h1: CGFloat = 32
        static let h2: CGFloat = 26
        static let h3: CGFloat = 22
        static let h4: CGFloat = 18
        static let h5: CGFloat = 16
        static let h6: CGFloat = 15
        static let body: CGFloat = 17
        static let code: CGFloat = 14
        static let ui: CGFloat = 13
    }

    enum Spacing {
        static let paragraph: CGFloat = 16
        static let heading: CGFloat = 24
        static let line: CGFloat = 7
        static let inset: CGFloat = 72
    }

    enum Color {
        static let text = NSColor.textColor
        static let textSecondary = NSColor.secondaryLabelColor
        static let textTertiary = NSColor.tertiaryLabelColor
        static let accent = NSColor.controlAccentColor
        static let link = NSColor.systemBlue
        static let code = NSColor(calibratedRed: 0.4, green: 0.4, blue: 0.45, alpha: 1)
        static let codeBackground = NSColor.quaternarySystemFill
        static let highlight = NSColor.systemYellow.withAlphaComponent(0.35)
        static let blockquoteBorder = NSColor.systemOrange.withAlphaComponent(0.6)
    }
}

// MARK: - Editor Scroll View

class EditorScrollView: NSScrollView {
    func configure(with textView: EditorTextView) {
        documentView = textView
        hasVerticalScroller = true
        hasHorizontalScroller = false
        autohidesScrollers = true
        scrollerStyle = .overlay
        drawsBackground = true
        backgroundColor = .textBackgroundColor
        contentView.postsBoundsChangedNotifications = true

        // Smooth scrolling
        scrollerKnobStyle = .default
        horizontalScrollElasticity = .none
        verticalScrollElasticity = .allowed
    }
}

// MARK: - Editor Text View

class EditorTextView: NSTextView {
    var onImageDrop: ((Data, String) -> Void)?
    weak var editorCoordinator: EditorCoordinator?

    private var notificationObservers: [NSObjectProtocol] = []

    func configure() {
        setupNotificationObservers()
        // Core
        isRichText = false
        allowsUndo = true
        usesFindBar = true
        isIncrementalSearchingEnabled = true

        // Disable auto-corrections
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticTextCompletionEnabled = false
        isAutomaticDataDetectionEnabled = false
        isAutomaticLinkDetectionEnabled = false

        // Appearance
        textContainerInset = NSSize(width: Design.Spacing.inset, height: 56)
        backgroundColor = .clear
        drawsBackground = false
        insertionPointColor = Design.Color.accent

        // Selection
        selectedTextAttributes = [
            .backgroundColor: Design.Color.accent.withAlphaComponent(0.15)
        ]

        // Typography
        let bodyFont = NSFont.systemFont(ofSize: Design.Font.body, weight: .regular)
        font = bodyFont
        typingAttributes = [
            .font: bodyFont,
            .foregroundColor: Design.Color.text,
            .kern: -0.3,
            .paragraphStyle: defaultParagraphStyle()
        ]

        // Text container
        minSize = NSSize(width: 0, height: 0)
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        isVerticallyResizable = true
        isHorizontallyResizable = false
        autoresizingMask = [.width]
        textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textContainer?.widthTracksTextView = true
        textContainer?.lineFragmentPadding = 0

        // Drag & drop
        registerForDraggedTypes([.png, .tiff, .fileURL])

        // Link clicking
        isAutomaticLinkDetectionEnabled = false
    }

    private func defaultParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = Design.Spacing.line
        style.paragraphSpacing = Design.Spacing.paragraph
        return style
    }

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        let nc = NotificationCenter.default

        notificationObservers.append(nc.addObserver(forName: .formatBold, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.wrap("**", "**") }
        })
        notificationObservers.append(nc.addObserver(forName: .formatItalic, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.wrap("*", "*") }
        })
        notificationObservers.append(nc.addObserver(forName: .formatCode, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.wrap("`", "`") }
        })
        notificationObservers.append(nc.addObserver(forName: .formatHeading1, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.setHeading(1) }
        })
        notificationObservers.append(nc.addObserver(forName: .formatHeading2, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.setHeading(2) }
        })
        notificationObservers.append(nc.addObserver(forName: .formatHeading3, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.setHeading(3) }
        })
        notificationObservers.append(nc.addObserver(forName: .formatLink, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.insertLink() }
        })
        notificationObservers.append(nc.addObserver(forName: .formatDivider, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.insertDivider() }
        })
        notificationObservers.append(nc.addObserver(forName: .scrollToHeader, object: nil, queue: .main) { [weak self] notification in
            guard let self,
                  let headerText = notification.userInfo?["headerText"] as? String else { return }
            Task { @MainActor in self.scrollToHeader(headerText) }
        })
    }

    deinit {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Keyboard Handling

    override func keyDown(with event: NSEvent) {
        let cmd = event.modifierFlags.contains(.command)
        let shift = event.modifierFlags.contains(.shift)
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""

        // Escape - close menus
        if event.keyCode == 53 {
            editorCoordinator?.dismissMenus()
            return
        }

        // Enter - list continuation
        if event.keyCode == 36 && !shift {
            if continueList() { return }
        }

        // Tab - indentation
        if event.keyCode == 48 {
            if indent(reverse: shift) { return }
        }

        // Command shortcuts
        if cmd {
            switch key {
            case "b": wrap("**", "**"); return
            case "i": wrap("*", "*"); return
            case "e": wrap("`", "`"); return
            case "k" where !shift: insertLink(); return
            case "k" where shift: insertCodeBlock(); return
            case "d" where shift: wrap("~~", "~~"); return
            case "h" where shift: wrap("==", "=="); return
            case "1": setHeading(1); return
            case "2": setHeading(2); return
            case "3": setHeading(3); return
            case "0": setHeading(0); return
            case "l" where shift: setList("- [ ] "); return
            case "u" where shift: setList("- "); return
            case "o" where shift: setList("1. "); return
            case "'": setBlockquote(); return
            case "/": insertDivider(); return
            default: break
            }
        }

        super.keyDown(with: event)
    }

    // MARK: - Link Clicking

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let charIndex = characterIndexForInsertion(at: point)

        if charIndex < textStorage?.length ?? 0,
           let attrs = textStorage?.attributes(at: charIndex, effectiveRange: nil),
           let link = attrs[.link] as? URL {
            NSWorkspace.shared.open(link)
            return
        }

        super.mouseDown(with: event)
    }

    override func resetCursorRects() {
        super.resetCursorRects()

        // Add hand cursor for links
        guard let storage = textStorage else { return }

        storage.enumerateAttribute(.link, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
            if value != nil {
                if let rect = boundingRect(for: range) {
                    addCursorRect(rect, cursor: .pointingHand)
                }
            }
        }
    }

    private func boundingRect(for range: NSRange) -> NSRect? {
        guard let layoutManager = layoutManager,
              let textContainer = textContainer else { return nil }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        rect.origin.x += textContainerOrigin.x
        rect.origin.y += textContainerOrigin.y
        return rect
    }

    // MARK: - Formatting Actions

    private func wrap(_ prefix: String, _ suffix: String) {
        guard let storage = textStorage else { return }

        let range = selectedRange()

        if range.length > 0 {
            let text = (string as NSString).substring(with: range)

            // Toggle off if already wrapped
            if text.hasPrefix(prefix) && text.hasSuffix(suffix) && text.count > prefix.count + suffix.count {
                let unwrapped = String(text.dropFirst(prefix.count).dropLast(suffix.count))
                storage.replaceCharacters(in: range, with: unwrapped)
                setSelectedRange(NSRange(location: range.location, length: unwrapped.count))
            } else {
                storage.replaceCharacters(in: range, with: "\(prefix)\(text)\(suffix)")
                setSelectedRange(NSRange(location: range.location + prefix.count, length: text.count))
            }
        } else {
            storage.replaceCharacters(in: range, with: "\(prefix)\(suffix)")
            setSelectedRange(NSRange(location: range.location + prefix.count, length: 0))
        }

        didChangeText()
    }

    private func insertLink() {
        guard let storage = textStorage else { return }

        let range = selectedRange()

        if range.length > 0 {
            let text = (string as NSString).substring(with: range)
            storage.replaceCharacters(in: range, with: "[\(text)]()")
            setSelectedRange(NSRange(location: range.location + text.count + 3, length: 0))
        } else {
            storage.replaceCharacters(in: range, with: "[]()")
            setSelectedRange(NSRange(location: range.location + 1, length: 0))
        }

        didChangeText()
    }

    private func insertCodeBlock() {
        guard let storage = textStorage else { return }

        let range = selectedRange()

        if range.length > 0 {
            let text = (string as NSString).substring(with: range)
            storage.replaceCharacters(in: range, with: "```\n\(text)\n```")
            setSelectedRange(NSRange(location: range.location + 4, length: text.count))
        } else {
            storage.replaceCharacters(in: range, with: "```\n\n```")
            setSelectedRange(NSRange(location: range.location + 4, length: 0))
        }

        didChangeText()
    }

    private func insertDivider() {
        guard let storage = textStorage else { return }

        let range = selectedRange()
        let text = string as NSString
        let lineRange = text.lineRange(for: range)
        let line = text.substring(with: lineRange)

        let insertion: String
        if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            insertion = "---\n"
        } else {
            insertion = "\n---\n"
        }

        storage.replaceCharacters(in: NSRange(location: lineRange.upperBound, length: 0), with: insertion)
        setSelectedRange(NSRange(location: lineRange.upperBound + insertion.count, length: 0))
        didChangeText()
    }

    private func setHeading(_ level: Int) {
        guard let storage = textStorage else { return }

        let text = string as NSString
        let lineRange = text.lineRange(for: selectedRange())
        let line = text.substring(with: lineRange)
        let hasNewline = line.hasSuffix("\n")

        // Strip existing heading
        var content = line.trimmingCharacters(in: .whitespacesAndNewlines)
        while content.hasPrefix("#") {
            content = String(content.dropFirst())
        }
        content = content.trimmingCharacters(in: .whitespaces)

        let newLine: String
        if level == 0 {
            newLine = content + (hasNewline ? "\n" : "")
        } else {
            let prefix = String(repeating: "#", count: level) + " "
            newLine = prefix + content + (hasNewline ? "\n" : "")
        }

        storage.replaceCharacters(in: lineRange, with: newLine)
        setSelectedRange(NSRange(location: lineRange.location + newLine.count - (hasNewline ? 1 : 0), length: 0))
        didChangeText()
    }

    private func setList(_ prefix: String) {
        guard let storage = textStorage else { return }

        let text = string as NSString
        let lineRange = text.lineRange(for: selectedRange())
        let line = text.substring(with: lineRange)
        let hasNewline = line.hasSuffix("\n")

        var content = line.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove existing list prefix
        let prefixes = ["- [ ] ", "- [x] ", "- [X] ", "- ", "* ", "+ "]
        for p in prefixes {
            if content.hasPrefix(p) {
                content = String(content.dropFirst(p.count))
                break
            }
        }
        if let match = content.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
            content = String(content[match.upperBound...])
        }

        let newLine = prefix + content + (hasNewline ? "\n" : "")
        storage.replaceCharacters(in: lineRange, with: newLine)
        setSelectedRange(NSRange(location: lineRange.location + newLine.count - (hasNewline ? 1 : 0), length: 0))
        didChangeText()
    }

    private func setBlockquote() {
        guard let storage = textStorage else { return }

        let text = string as NSString
        let lineRange = text.lineRange(for: selectedRange())
        let line = text.substring(with: lineRange)
        let hasNewline = line.hasSuffix("\n")

        var content = line.trimmingCharacters(in: .whitespacesAndNewlines)

        let newLine: String
        if content.hasPrefix("> ") {
            content = String(content.dropFirst(2))
            newLine = content + (hasNewline ? "\n" : "")
        } else if content.hasPrefix(">") {
            content = String(content.dropFirst(1))
            newLine = content + (hasNewline ? "\n" : "")
        } else {
            newLine = "> " + content + (hasNewline ? "\n" : "")
        }

        storage.replaceCharacters(in: lineRange, with: newLine)
        setSelectedRange(NSRange(location: lineRange.location + newLine.count - (hasNewline ? 1 : 0), length: 0))
        didChangeText()
    }

    // MARK: - List Continuation

    private func continueList() -> Bool {
        guard let storage = textStorage else { return false }

        let cursor = selectedRange().location
        let text = string as NSString
        let lineRange = text.lineRange(for: NSRange(location: cursor, length: 0))
        let line = text.substring(with: lineRange)

        // Patterns: checkbox, bullet, numbered
        let patterns: [(String, (String) -> String?)] = [
            (#"^(\s*)([-*+])\s+\[[xX ]\]\s*(.*)$"#, { _ in "- [ ] " }),
            (#"^(\s*)([-*+])\s+(.*)$"#, { line in
                if let bullet = line.first(where: { "-*+".contains($0) }) {
                    return "\(bullet) "
                }
                return "- "
            }),
            (#"^(\s*)(\d+)\.\s+(.*)$"#, { line in
                if let match = line.range(of: #"(\d+)\."#, options: .regularExpression),
                   let num = Int(line[match].dropLast()) {
                    return "\(num + 1). "
                }
                return "1. "
            })
        ]

        for (pattern, nextPrefix) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) else {
                continue
            }

            let indent = extractMatch(line, match, 1)
            let content = extractMatch(line, match, match.numberOfRanges - 1).trimmingCharacters(in: .whitespaces)

            // Empty = exit list
            if content.isEmpty {
                let deleteRange = NSRange(location: lineRange.location, length: lineRange.length - (line.hasSuffix("\n") ? 1 : 0))
                storage.replaceCharacters(in: deleteRange, with: "")
                setSelectedRange(NSRange(location: lineRange.location, length: 0))
                didChangeText()
                return true
            }

            // Continue list
            if let prefix = nextPrefix(line) {
                let insertion = "\n\(indent)\(prefix)"
                storage.replaceCharacters(in: selectedRange(), with: insertion)
                setSelectedRange(NSRange(location: cursor + insertion.count, length: 0))
                didChangeText()
                return true
            }
        }

        return false
    }

    private func extractMatch(_ text: String, _ match: NSTextCheckingResult, _ group: Int) -> String {
        let range = match.range(at: group)
        guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return "" }
        return String(text[swiftRange])
    }

    // MARK: - Navigation

    func scrollToHeader(_ headerText: String) {
        let text = string as NSString
        let lines = text.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Match header patterns
            if trimmed.hasPrefix("#") {
                var content = trimmed
                while content.hasPrefix("#") {
                    content = String(content.dropFirst())
                }
                content = content.trimmingCharacters(in: .whitespaces)

                if content == headerText {
                    // Calculate character offset
                    var offset = 0
                    for i in 0..<index {
                        offset += lines[i].count + 1 // +1 for newline
                    }

                    // Select the header line
                    let lineRange = text.lineRange(for: NSRange(location: offset, length: 0))
                    setSelectedRange(NSRange(location: lineRange.location, length: 0))
                    scrollRangeToVisible(lineRange)

                    // Flash highlight effect
                    if let layoutManager = layoutManager,
                       let textContainer = textContainer {
                        let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
                        let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

                        let flashView = NSView(frame: rect)
                        flashView.wantsLayer = true
                        flashView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor
                        flashView.layer?.cornerRadius = 4
                        addSubview(flashView)

                        NSAnimationContext.runAnimationGroup { context in
                            context.duration = 0.8
                            flashView.animator().alphaValue = 0
                        } completionHandler: {
                            flashView.removeFromSuperview()
                        }
                    }
                    break
                }
            }
        }
    }

    // MARK: - Indentation

    private func indent(reverse: Bool) -> Bool {
        guard let storage = textStorage else { return false }

        let text = string as NSString
        let lineRange = text.lineRange(for: selectedRange())
        let line = text.substring(with: lineRange)

        // Only indent list items
        guard line.range(of: #"^\s*[-*+\d]"#, options: .regularExpression) != nil else {
            return false
        }

        let newLine: String
        if reverse {
            if line.hasPrefix("  ") {
                newLine = String(line.dropFirst(2))
            } else if line.hasPrefix("\t") {
                newLine = String(line.dropFirst(1))
            } else {
                return false
            }
        } else {
            newLine = "  " + line
        }

        storage.replaceCharacters(in: lineRange, with: newLine)
        didChangeText()
        return true
    }

    // MARK: - Drag & Drop

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pb = sender.draggingPasteboard
        if pb.canReadObject(forClasses: [NSURL.self, NSImage.self], options: nil) {
            return .copy
        }
        return super.draggingEntered(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard

        // File URLs
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            for url in urls {
                if let data = try? Data(contentsOf: url), NSImage(data: data) != nil {
                    onImageDrop?(data, url.lastPathComponent)
                    return true
                }
            }
        }

        // Direct image
        if let image = pb.readObjects(forClasses: [NSImage.self])?.first as? NSImage,
           let data = image.pngData() {
            onImageDrop?(data, "image-\(UUID().uuidString.prefix(6)).png")
            return true
        }

        return super.performDragOperation(sender)
    }

    override func paste(_ sender: Any?) {
        let pb = NSPasteboard.general

        if let image = pb.readObjects(forClasses: [NSImage.self])?.first as? NSImage,
           let data = image.pngData() {
            onImageDrop?(data, "pasted-\(UUID().uuidString.prefix(6)).png")
            return
        }

        super.paste(sender)
    }
}

// MARK: - Editor Coordinator

class EditorCoordinator: NSObject, NSTextViewDelegate {
    var parent: MarkdownEditor
    weak var textView: EditorTextView?
    weak var scrollView: EditorScrollView?
    var isHighlighting = false
    var typewriterMode = false

    private var highlightTask: DispatchWorkItem?
    private var slashMenu: SlashMenuWindow?

    init(_ parent: MarkdownEditor) {
        self.parent = parent
    }

    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        guard !isHighlighting else { return }

        parent.text = textView.string
        scheduleHighlight()
        checkSlashCommand()

        if typewriterMode {
            scrollCursorToCenter()
        }
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        if typewriterMode {
            scrollCursorToCenter()
        }
    }

    private func scrollCursorToCenter() {
        guard let textView = textView,
              let scrollView = scrollView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let cursor = textView.selectedRange().location
        let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: cursor, length: 0), actualCharacterRange: nil)
        let cursorRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        // Calculate the center of the visible area
        let visibleHeight = scrollView.contentView.bounds.height
        let targetY = cursorRect.origin.y + textView.textContainerInset.height - (visibleHeight / 2) + (cursorRect.height / 2)

        let contentHeight = scrollView.documentView?.frame.height ?? 0
        let maxY = max(0, contentHeight - visibleHeight)
        let clampedY = max(0, min(targetY, maxY))

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            scrollView.contentView.animator().setBoundsOrigin(NSPoint(x: 0, y: clampedY))
        }
    }

    func dismissMenus() {
        slashMenu?.close()
        slashMenu = nil
    }

    private func scheduleHighlight() {
        highlightTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.highlight()
        }
        highlightTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02, execute: task)
    }

    // MARK: - Slash Commands

    private func checkSlashCommand() {
        guard let textView = textView else { return }

        let cursor = textView.selectedRange().location
        guard cursor > 0 else {
            dismissMenus()
            return
        }

        let text = textView.string as NSString
        let lineRange = text.lineRange(for: NSRange(location: cursor, length: 0))
        let beforeCursor = text.substring(with: NSRange(location: lineRange.location, length: cursor - lineRange.location))

        // Check for slash at start of line or after space
        if let match = beforeCursor.range(of: #"(^|\s)/([a-z]*)$"#, options: .regularExpression) {
            let query = String(beforeCursor[match]).trimmingCharacters(in: .whitespaces).dropFirst()
            showSlashMenu(filter: String(query))
        } else {
            dismissMenus()
        }
    }

    private func showSlashMenu(filter: String) {
        guard let textView = textView,
              let window = textView.window else { return }

        if slashMenu == nil {
            slashMenu = SlashMenuWindow()
            slashMenu?.onSelect = { [weak self] item in
                self?.insertSlashItem(item)
            }
        }

        // Position near cursor
        let cursor = textView.selectedRange().location
        let glyphRange = textView.layoutManager?.glyphRange(forCharacterRange: NSRange(location: cursor, length: 0), actualCharacterRange: nil) ?? NSRange()
        var rect = textView.layoutManager?.boundingRect(forGlyphRange: glyphRange, in: textView.textContainer!) ?? .zero
        rect = textView.convert(rect, to: nil)
        rect = window.convertToScreen(rect)

        slashMenu?.showMenu(near: rect, filter: filter, in: window)
    }

    private func insertSlashItem(_ item: SlashCommand) {
        guard let textView = textView,
              let storage = textView.textStorage else { return }

        dismissMenus()

        // Find and delete the slash command
        let cursor = textView.selectedRange().location
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: NSRange(location: cursor, length: 0))
        let beforeCursor = text.substring(with: NSRange(location: lineRange.location, length: cursor - lineRange.location))

        var deleteStart = cursor
        if let match = beforeCursor.range(of: #"(^|\s)/[a-z]*$"#, options: .regularExpression) {
            let offset = beforeCursor.distance(from: beforeCursor.startIndex, to: match.lowerBound)
            deleteStart = lineRange.location + offset
            if beforeCursor[match].hasPrefix(" ") { deleteStart += 1 }
        }

        storage.replaceCharacters(in: NSRange(location: deleteStart, length: cursor - deleteStart), with: "")

        // Insert content
        let insertAt = deleteStart
        textView.setSelectedRange(NSRange(location: insertAt, length: 0))

        let content: String
        var cursorOffset = 0

        switch item {
        case .heading1: content = "# "; cursorOffset = 2
        case .heading2: content = "## "; cursorOffset = 3
        case .heading3: content = "### "; cursorOffset = 4
        case .bullet: content = "- "; cursorOffset = 2
        case .numbered: content = "1. "; cursorOffset = 3
        case .todo: content = "- [ ] "; cursorOffset = 6
        case .quote: content = "> "; cursorOffset = 2
        case .code: content = "```\n\n```"; cursorOffset = 4
        case .divider: content = "---\n"; cursorOffset = 4
        case .link: content = "[]()"; cursorOffset = 1
        case .image: content = "![]()"; cursorOffset = 2
        }

        storage.replaceCharacters(in: textView.selectedRange(), with: content)
        textView.setSelectedRange(NSRange(location: insertAt + cursorOffset, length: 0))
        textView.didChangeText()
    }

    // MARK: - Syntax Highlighting

    func highlight() {
        guard let textView = textView,
              let storage = textView.textStorage else { return }

        isHighlighting = true
        defer { isHighlighting = false }

        let text = storage.string
        let fullRange = NSRange(location: 0, length: storage.length)

        storage.beginEditing()

        // Base style
        storage.setAttributes([
            .font: NSFont.systemFont(ofSize: Design.Font.body, weight: .regular),
            .foregroundColor: Design.Color.text,
            .paragraphStyle: bodyStyle(),
            .kern: -0.3
        ], range: fullRange)

        // Apply patterns (order matters)
        highlightCodeBlocks(storage, text)
        highlightHeadings(storage, text)
        highlightBoldItalic(storage, text)
        highlightBold(storage, text)
        highlightItalic(storage, text)
        highlightInlineCode(storage, text)
        highlightLinks(storage, text)
        highlightImages(storage, text)
        highlightLists(storage, text)
        highlightBlockquotes(storage, text)
        highlightDividers(storage, text)
        highlightStrikethrough(storage, text)
        highlightHighlight(storage, text)
        highlightTables(storage, text)

        storage.endEditing()

        // Update cursor rects for links
        textView.resetCursorRects()
    }

    // MARK: - Paragraph Styles

    private func bodyStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = Design.Spacing.line
        style.paragraphSpacing = Design.Spacing.paragraph
        return style
    }

    private func headingStyle(_ level: Int) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        let spacing: [(before: CGFloat, after: CGFloat, line: CGFloat)] = [
            (28, 12, 4), // H1
            (24, 10, 3), // H2
            (20, 8, 2),  // H3
            (16, 6, 1),  // H4
            (12, 4, 1),  // H5
            (10, 4, 1),  // H6
        ]
        let s = spacing[min(level - 1, 5)]
        style.paragraphSpacingBefore = s.before
        style.paragraphSpacing = s.after
        style.lineSpacing = s.line
        return style
    }

    // MARK: - Pattern Matching

    private func apply(_ pattern: String, to storage: NSTextStorage, in text: String,
                       options: NSRegularExpression.Options = [], handler: (NSTextCheckingResult) -> Void) {
        var opts = options
        opts.insert(.dotMatchesLineSeparators)

        guard let regex = try? NSRegularExpression(pattern: pattern, options: opts) else { return }
        let range = NSRange(location: 0, length: text.utf16.count)

        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match = match else { return }
            handler(match)
        }
    }

    private func fade(_ storage: NSTextStorage, _ range: NSRange, prefix: Int, suffix: Int) {
        let start = NSRange(location: range.location, length: prefix)
        let end = NSRange(location: range.upperBound - suffix, length: suffix)

        if start.upperBound <= storage.length {
            storage.addAttribute(.foregroundColor, value: Design.Color.textTertiary, range: start)
        }
        if end.location >= 0 && end.upperBound <= storage.length {
            storage.addAttribute(.foregroundColor, value: Design.Color.textTertiary, range: end)
        }
    }

    // MARK: - Highlighting Functions

    private func highlightHeadings(_ storage: NSTextStorage, _ text: String) {
        let specs: [(String, CGFloat, NSFont.Weight)] = [
            (#"^(#)\s+(.+)$"#, Design.Font.h1, .bold),
            (#"^(##)\s+(.+)$"#, Design.Font.h2, .bold),
            (#"^(###)\s+(.+)$"#, Design.Font.h3, .semibold),
            (#"^(####)\s+(.+)$"#, Design.Font.h4, .semibold),
            (#"^(#####)\s+(.+)$"#, Design.Font.h5, .medium),
            (#"^(######)\s+(.+)$"#, Design.Font.h6, .medium),
        ]

        for (i, spec) in specs.enumerated() {
            apply(spec.0, to: storage, in: text, options: .anchorsMatchLines) { match in
                guard match.numberOfRanges >= 3 else { return }

                let full = match.range
                let hash = match.range(at: 1)
                let content = match.range(at: 2)

                // Font & style
                storage.addAttribute(.font, value: NSFont.systemFont(ofSize: spec.1, weight: spec.2), range: full)
                storage.addAttribute(.paragraphStyle, value: self.headingStyle(i + 1), range: full)

                // Fade markers
                storage.addAttribute(.foregroundColor, value: Design.Color.textTertiary, range: hash)
                let space = NSRange(location: hash.upperBound, length: 1)
                if space.upperBound <= storage.length {
                    storage.addAttribute(.foregroundColor, value: Design.Color.textTertiary, range: space)
                }

                // Content stays default color
                storage.addAttribute(.foregroundColor, value: Design.Color.text, range: content)
            }
        }
    }

    private func highlightBold(_ storage: NSTextStorage, _ text: String) {
        apply(#"\*\*(?!\s)(.+?)(?<!\s)\*\*"#, to: storage, in: text) { match in
            guard match.numberOfRanges >= 2 else { return }
            let content = match.range(at: 1)
            let bold = NSFontManager.shared.convert(NSFont.systemFont(ofSize: Design.Font.body), toHaveTrait: .boldFontMask)
            storage.addAttribute(.font, value: bold, range: content)
            self.fade(storage, match.range, prefix: 2, suffix: 2)
        }

        apply(#"__(?!\s)(.+?)(?<!\s)__"#, to: storage, in: text) { match in
            guard match.numberOfRanges >= 2 else { return }
            let content = match.range(at: 1)
            let bold = NSFontManager.shared.convert(NSFont.systemFont(ofSize: Design.Font.body), toHaveTrait: .boldFontMask)
            storage.addAttribute(.font, value: bold, range: content)
            self.fade(storage, match.range, prefix: 2, suffix: 2)
        }
    }

    private func highlightItalic(_ storage: NSTextStorage, _ text: String) {
        apply(#"(?<!\*)\*(?!\*)(?!\s)(.+?)(?<!\s)\*(?!\*)"#, to: storage, in: text) { match in
            guard match.numberOfRanges >= 2 else { return }
            let content = match.range(at: 1)
            let italic = NSFontManager.shared.convert(NSFont.systemFont(ofSize: Design.Font.body), toHaveTrait: .italicFontMask)
            storage.addAttribute(.font, value: italic, range: content)
            self.fade(storage, match.range, prefix: 1, suffix: 1)
        }

        apply(#"(?<!_)_(?!_)(?!\s)(.+?)(?<!\s)_(?!_)"#, to: storage, in: text) { match in
            guard match.numberOfRanges >= 2 else { return }
            let content = match.range(at: 1)
            let italic = NSFontManager.shared.convert(NSFont.systemFont(ofSize: Design.Font.body), toHaveTrait: .italicFontMask)
            storage.addAttribute(.font, value: italic, range: content)
            self.fade(storage, match.range, prefix: 1, suffix: 1)
        }
    }

    private func highlightBoldItalic(_ storage: NSTextStorage, _ text: String) {
        apply(#"\*\*\*(?!\s)(.+?)(?<!\s)\*\*\*"#, to: storage, in: text) { match in
            guard match.numberOfRanges >= 2 else { return }
            let content = match.range(at: 1)
            var font = NSFontManager.shared.convert(NSFont.systemFont(ofSize: Design.Font.body), toHaveTrait: .boldFontMask)
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            storage.addAttribute(.font, value: font, range: content)
            self.fade(storage, match.range, prefix: 3, suffix: 3)
        }
    }

    private func highlightInlineCode(_ storage: NSTextStorage, _ text: String) {
        apply(#"(?<!`)`(?!`)([^`\n]+?)`(?!`)"#, to: storage, in: text) { match in
            guard match.numberOfRanges >= 2 else { return }
            let content = match.range(at: 1)

            storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: Design.Font.code, weight: .regular), range: content)
            storage.addAttribute(.foregroundColor, value: Design.Color.code, range: content)
            storage.addAttribute(.backgroundColor, value: Design.Color.codeBackground, range: content)
            self.fade(storage, match.range, prefix: 1, suffix: 1)
        }
    }

    private func highlightCodeBlocks(_ storage: NSTextStorage, _ text: String) {
        apply(#"^```(\w*)\n([\s\S]*?)^```$"#, to: storage, in: text, options: .anchorsMatchLines) { match in
            let codeFont = NSFont.monospacedSystemFont(ofSize: Design.Font.code, weight: .regular)

            storage.addAttribute(.font, value: codeFont, range: match.range)
            storage.addAttribute(.foregroundColor, value: Design.Color.code, range: match.range)
            storage.addAttribute(.backgroundColor, value: NSColor.windowBackgroundColor.withAlphaComponent(0.5), range: match.range)

            // Style for code block
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 3
            style.paragraphSpacing = 14
            style.paragraphSpacingBefore = 14
            storage.addAttribute(.paragraphStyle, value: style, range: match.range)

            // Fade fences
            if let r = Range(match.range, in: text) {
                let content = String(text[r])
                if let newline = content.firstIndex(of: "\n") {
                    let openLen = content.distance(from: content.startIndex, to: newline)
                    storage.addAttribute(.foregroundColor, value: Design.Color.textTertiary,
                                         range: NSRange(location: match.range.location, length: openLen))
                }
            }
            storage.addAttribute(.foregroundColor, value: Design.Color.textTertiary,
                                 range: NSRange(location: match.range.upperBound - 3, length: 3))
        }
    }

    private func highlightLinks(_ storage: NSTextStorage, _ text: String) {
        apply(#"\[([^\]]+)\]\(([^)]+)\)"#, to: storage, in: text) { match in
            guard match.numberOfRanges >= 3 else { return }

            let textRange = match.range(at: 1)
            let urlRange = match.range(at: 2)

            // Make link clickable
            if let r = Range(urlRange, in: text) {
                let urlString = String(text[r])
                if let url = URL(string: urlString) {
                    storage.addAttribute(.link, value: url, range: textRange)
                }
            }

            // Style link text
            storage.addAttribute(.foregroundColor, value: Design.Color.link, range: textRange)
            storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: textRange)

            // Fade structural parts
            let open = NSRange(location: match.range.location, length: 1)
            let mid = NSRange(location: textRange.upperBound, length: 2)
            let close = NSRange(location: urlRange.upperBound, length: 1)

            for r in [open, mid, urlRange, close] {
                if r.upperBound <= storage.length {
                    storage.addAttribute(.foregroundColor, value: Design.Color.textTertiary, range: r)
                }
            }
        }
    }

    private func highlightImages(_ storage: NSTextStorage, _ text: String) {
        apply(#"!\[([^\]]*)\]\(([^)]+)\)"#, to: storage, in: text) { match in
            storage.addAttribute(.foregroundColor, value: NSColor.systemPurple, range: match.range)

            if match.numberOfRanges >= 2 {
                let alt = match.range(at: 1)
                if alt.length > 0 {
                    storage.addAttribute(.foregroundColor, value: NSColor.systemPurple.withAlphaComponent(0.7), range: alt)
                }
            }
        }
    }

    private func highlightLists(_ storage: NSTextStorage, _ text: String) {
        // Bullets
        apply(#"^(\s*)([-*+])\s+"#, to: storage, in: text, options: .anchorsMatchLines) { match in
            if match.numberOfRanges >= 3 {
                storage.addAttribute(.foregroundColor, value: Design.Color.textTertiary, range: match.range(at: 2))
            }
        }

        // Numbers
        apply(#"^(\s*)(\d+\.)\s+"#, to: storage, in: text, options: .anchorsMatchLines) { match in
            if match.numberOfRanges >= 3 {
                storage.addAttribute(.foregroundColor, value: Design.Color.textTertiary, range: match.range(at: 2))
            }
        }

        // Unchecked
        apply(#"^(\s*[-*+]\s+)(\[ \])"#, to: storage, in: text, options: .anchorsMatchLines) { match in
            if match.numberOfRanges >= 3 {
                storage.addAttribute(.foregroundColor, value: Design.Color.textTertiary, range: match.range(at: 2))
            }
        }

        // Checked
        apply(#"^(\s*[-*+]\s+)(\[[xX]\])(.*)$"#, to: storage, in: text, options: .anchorsMatchLines) { match in
            if match.numberOfRanges >= 3 {
                storage.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: match.range(at: 2))
            }
            if match.numberOfRanges >= 4 {
                let text = match.range(at: 3)
                storage.addAttribute(.foregroundColor, value: Design.Color.textSecondary, range: text)
                storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: text)
            }
        }
    }

    private func highlightBlockquotes(_ storage: NSTextStorage, _ text: String) {
        apply(#"^(>+)\s*(.*)$"#, to: storage, in: text, options: .anchorsMatchLines) { match in
            guard match.numberOfRanges >= 3 else { return }

            let marker = match.range(at: 1)
            let content = match.range(at: 2)

            // Marker color
            storage.addAttribute(.foregroundColor, value: Design.Color.blockquoteBorder, range: marker)

            // Content - italic & muted
            let italic = NSFontManager.shared.convert(NSFont.systemFont(ofSize: Design.Font.body), toHaveTrait: .italicFontMask)
            storage.addAttribute(.font, value: italic, range: content)
            storage.addAttribute(.foregroundColor, value: Design.Color.textSecondary, range: content)

            // Indented style
            let style = NSMutableParagraphStyle()
            style.headIndent = 20
            style.firstLineHeadIndent = 0
            style.lineSpacing = Design.Spacing.line
            style.paragraphSpacing = 12
            storage.addAttribute(.paragraphStyle, value: style, range: match.range)
        }
    }

    private func highlightDividers(_ storage: NSTextStorage, _ text: String) {
        apply(#"^(-{3,}|\*{3,}|_{3,})$"#, to: storage, in: text, options: .anchorsMatchLines) { match in
            storage.addAttribute(.foregroundColor, value: NSColor.separatorColor, range: match.range)

            let style = NSMutableParagraphStyle()
            style.paragraphSpacingBefore = 20
            style.paragraphSpacing = 20
            style.alignment = .center
            storage.addAttribute(.paragraphStyle, value: style, range: match.range)
        }
    }

    private func highlightStrikethrough(_ storage: NSTextStorage, _ text: String) {
        apply(#"~~(?!\s)(.+?)(?<!\s)~~"#, to: storage, in: text) { match in
            guard match.numberOfRanges >= 2 else { return }
            let content = match.range(at: 1)
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: content)
            storage.addAttribute(.foregroundColor, value: Design.Color.textSecondary, range: content)
            self.fade(storage, match.range, prefix: 2, suffix: 2)
        }
    }

    private func highlightHighlight(_ storage: NSTextStorage, _ text: String) {
        apply(#"==(?!\s)(.+?)(?<!\s)=="#, to: storage, in: text) { match in
            guard match.numberOfRanges >= 2 else { return }
            let content = match.range(at: 1)
            storage.addAttribute(.backgroundColor, value: Design.Color.highlight, range: content)
            self.fade(storage, match.range, prefix: 2, suffix: 2)
        }
    }

    private func highlightTables(_ storage: NSTextStorage, _ text: String) {
        let monoFont = NSFont.monospacedSystemFont(ofSize: Design.Font.body - 1, weight: .regular)

        // Table header row: | Header | Header |
        apply(#"^\|(.+)\|$"#, to: storage, in: text, options: .anchorsMatchLines) { match in
            storage.addAttribute(.font, value: monoFont, range: match.range)

            // Style pipe characters
            let content = (text as NSString).substring(with: match.range)
            var offset = match.range.location

            for char in content {
                if char == "|" {
                    storage.addAttribute(.foregroundColor, value: Design.Color.textTertiary, range: NSRange(location: offset, length: 1))
                }
                offset += 1
            }
        }

        // Table separator row: |---|---|
        apply(#"^\|[-:\s\|]+\|$"#, to: storage, in: text, options: .anchorsMatchLines) { match in
            storage.addAttribute(.font, value: monoFont, range: match.range)
            storage.addAttribute(.foregroundColor, value: Design.Color.textTertiary, range: match.range)
        }

        // Header cells (first row before separator) - make bold
        apply(#"^\|(.+)\|$\n\|[-:\s\|]+\|$"#, to: storage, in: text, options: .anchorsMatchLines) { match in
            if match.numberOfRanges >= 2 {
                let headerRow = match.range(at: 0)
                let lines = (text as NSString).substring(with: headerRow).components(separatedBy: "\n")
                if let firstLine = lines.first {
                    let headerRange = NSRange(location: headerRow.location, length: firstLine.count)
                    let boldFont = NSFont.monospacedSystemFont(ofSize: Design.Font.body - 1, weight: .semibold)
                    storage.addAttribute(.font, value: boldFont, range: headerRange)
                }
            }
        }
    }
}

// MARK: - Slash Menu

enum SlashCommand: CaseIterable {
    case heading1, heading2, heading3
    case bullet, numbered, todo
    case quote, code, divider
    case link, image

    var title: String {
        switch self {
        case .heading1: return "Heading 1"
        case .heading2: return "Heading 2"
        case .heading3: return "Heading 3"
        case .bullet: return "Bullet List"
        case .numbered: return "Numbered List"
        case .todo: return "To-do"
        case .quote: return "Quote"
        case .code: return "Code"
        case .divider: return "Divider"
        case .link: return "Link"
        case .image: return "Image"
        }
    }

    var subtitle: String {
        switch self {
        case .heading1: return "Large heading"
        case .heading2: return "Medium heading"
        case .heading3: return "Small heading"
        case .bullet: return "Bullet list"
        case .numbered: return "Numbered list"
        case .todo: return "Task checkbox"
        case .quote: return "Quote block"
        case .code: return "Code block"
        case .divider: return "Horizontal line"
        case .link: return "Web link"
        case .image: return "Image"
        }
    }

    var icon: String {
        switch self {
        case .heading1: return "h1"
        case .heading2: return "h2"
        case .heading3: return "h3"
        case .bullet: return "list.bullet"
        case .numbered: return "list.number"
        case .todo: return "checkmark.square"
        case .quote: return "text.quote"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .divider: return "minus"
        case .link: return "link"
        case .image: return "photo"
        }
    }

    var keywords: [String] {
        switch self {
        case .heading1: return ["h1", "heading", "title"]
        case .heading2: return ["h2", "heading"]
        case .heading3: return ["h3", "heading"]
        case .bullet: return ["bullet", "list", "ul"]
        case .numbered: return ["number", "list", "ol"]
        case .todo: return ["todo", "task", "check"]
        case .quote: return ["quote", "blockquote"]
        case .code: return ["code", "pre"]
        case .divider: return ["divider", "hr", "line"]
        case .link: return ["link", "url"]
        case .image: return ["image", "photo", "img"]
        }
    }

    func matches(_ query: String) -> Bool {
        let q = query.lowercased()
        return title.lowercased().contains(q) || keywords.contains { $0.contains(q) }
    }
}

class SlashMenuWindow {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<SlashMenuContent>?
    var onSelect: ((SlashCommand) -> Void)?

    func showMenu(near rect: NSRect, filter: String, in parentWindow: NSWindow) {
        let items = filter.isEmpty ? SlashCommand.allCases : SlashCommand.allCases.filter { $0.matches(filter) }

        guard !items.isEmpty else {
            close()
            return
        }

        let content = SlashMenuContent(items: Array(items)) { [weak self] item in
            self?.onSelect?(item)
        }

        let height = min(CGFloat(items.count) * 48 + 12, 300)

        if panel == nil {
            panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 260, height: height),
                styleMask: [.nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel?.isFloatingPanel = true
            panel?.level = .floating
            panel?.backgroundColor = .clear
            panel?.isOpaque = false
            panel?.hasShadow = true
        }

        panel?.setContentSize(NSSize(width: 260, height: height))

        hostingView = NSHostingView(rootView: content)
        hostingView?.frame = NSRect(x: 0, y: 0, width: 260, height: height)
        panel?.contentView = hostingView

        let origin = NSPoint(x: rect.minX, y: rect.minY - height - 6)
        panel?.setFrameOrigin(origin)
        panel?.orderFront(nil)
    }

    func close() {
        panel?.orderOut(nil)
    }
}

struct SlashMenuContent: View {
    let items: [SlashCommand]
    let onSelect: (SlashCommand) -> Void
    @State private var hovered: SlashCommand?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(items, id: \.self) { item in
                        SlashMenuRow(item: item, isHovered: hovered == item)
                            .onTapGesture { onSelect(item) }
                            .onHover { isHovered in
                                if isHovered { hovered = item }
                            }
                    }
                }
                .padding(6)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThickMaterial)
                .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

struct SlashMenuRow: View {
    let item: SlashCommand
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
                    .frame(width: 32, height: 32)

                if item.icon.hasPrefix("h") {
                    Text(item.icon.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(isHovered ? .accentColor : .secondary)
                } else {
                    Image(systemName: item.icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isHovered ? .accentColor : .secondary)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                Text(item.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Extensions

extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}

// MARK: - Preview

#Preview {
    MarkdownEditor(text: .constant("""
    # Welcome to Noteflow

    A beautiful, minimal markdown editor. Type `/` to see commands.

    ## Formatting

    Write **bold**, *italic*, or ***both***. Add `inline code` or ==highlights==.

    Create [clickable links](https://apple.com) that actually work.

    ## Lists

    - Bullet points
    - With auto-continuation
    - Press Enter to continue

    1. Numbered lists
    2. Auto-increment
    3. Tab to indent

    - [ ] Unchecked task
    - [x] Completed task

    > Blockquotes are beautifully styled with italic text and colored markers.

    ```swift
    let editor = "Beautiful"
    print(editor)
    ```

    ---

    ### Keyboard Shortcuts

    | Shortcut | Action |
    |----------|--------|
    | ⌘B | Bold |
    | ⌘I | Italic |
    | ⌘K | Link |
    | ⌘1-3 | Headings |

    Type `/` for the command menu!
    """))
    .frame(width: 700, height: 700)
}
