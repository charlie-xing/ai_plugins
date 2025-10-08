import AppKit
import SwiftUI

/// Multi-line expandable text input with toolbar
struct ExpandableTextInput: View {
    @Binding var text: String
    @Binding var selectedKnowledgeBase: KnowledgeBase?
    @State private var textHeight: CGFloat = 44  // Single line height
    @State private var isDisabled: Bool = false
    @State private var showingKnowledgeBaseSelection = false
    @ObservedObject private var knowledgeBaseManager = KnowledgeBaseManager()

    let placeholder: String
    let onSend: () -> Void

    private let minHeight: CGFloat = 44  // 2 lines (adjusted for proper sizing)
    private let maxHeight: CGFloat = 110  // 5 lines (adjusted for proper sizing)
    private let lineHeight: CGFloat = 22

    var body: some View {
        VStack(spacing: 0) {
            // Text editor area
            ZStack(alignment: .topLeading) {
                // Placeholder - must be FIRST so it's behind the text editor
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.secondary.opacity(0.6))
                        .font(.system(size: 14))
                        .padding(.horizontal, 8)  // Match textContainerInset (4pt + 4pt extra)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                        .background(Color.clear)  // Explicitly clear background
                }

                // Text editor - must be LAST so it's on top
                ExpandableTextEditor(
                    text: $text,
                    height: $textHeight,
                    isDisabled: $isDisabled,
                    minHeight: minHeight,
                    maxHeight: maxHeight,
                    onSend: onSend
                )
                .frame(height: max(minHeight, min(textHeight, maxHeight)))
                .onTapGesture {
                    // This ensures the text view gets focus when tapped
                }
            }

            Divider()

            // Toolbar
            HStack(spacing: 12) {
                // Left side buttons
                HStack(spacing: 8) {
                    ToolbarButton(icon: "paperclip", tooltip: "Add attachment") {
                        // TODO: Implement attachment
                    }

                    ToolbarButton(
                        icon: selectedKnowledgeBase != nil
                            ? "books.vertical.fill" : "books.vertical",
                        tooltip: selectedKnowledgeBase?.name ?? "Select knowledge base",
                        isSelected: selectedKnowledgeBase != nil
                    ) {
                        showingKnowledgeBaseSelection.toggle()
                    }
                    .popover(isPresented: $showingKnowledgeBaseSelection) {
                        KnowledgeBaseSelectionView(
                            knowledgeBases: knowledgeBaseManager.knowledgeBases.filter {
                                $0.displayStatus == .ready
                            },
                            selectedKnowledgeBase: $selectedKnowledgeBase,
                            onDismiss: {
                                showingKnowledgeBaseSelection = false
                            }
                        )
                    }

                    ToolbarButton(icon: "globe", tooltip: "Web search") {
                        // TODO: Implement web search
                    }

                    ToolbarButton(icon: "magnifyingglass.circle", tooltip: "Deep research") {
                        // TODO: Implement deep research
                    }
                }

                Spacer()

                // Run button
                Button(action: {
                    print("ExpandableTextInput: Run button clicked, text: '\(text)'")
                    onSend()
                }) {
                    HStack(spacing: 4) {
                        Text("Run")
                            .font(.system(size: 13, weight: .medium))
                        Text("⌘↵")
                            .font(.system(size: 11))
                            .opacity(0.7)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(text.isEmpty || isDisabled ? Color.gray : Color.accentColor)
                    )
                }
                .buttonStyle(.plain)
                .disabled(text.isEmpty || isDisabled)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }
}

/// Toolbar button component
struct ToolbarButton: View {
    let icon: String
    let tooltip: String
    let isSelected: Bool
    let action: () -> Void

    init(icon: String, tooltip: String, isSelected: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.tooltip = tooltip
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(
                            isSelected
                                ? Color.accentColor.opacity(0.2)
                                : Color(NSColor.controlBackgroundColor))
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

/// Knowledge Base Selection View
struct KnowledgeBaseSelectionView: View {
    let knowledgeBases: [KnowledgeBase]
    @Binding var selectedKnowledgeBase: KnowledgeBase?
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Select Knowledge Base")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Knowledge Base List
            if knowledgeBases.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)

                    Text("No Ready Knowledge Bases")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Create and configure knowledge bases in Settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // None option
                        KnowledgeBaseSelectionRow(
                            knowledgeBase: nil,
                            isSelected: selectedKnowledgeBase == nil,
                            onSelect: {
                                selectedKnowledgeBase = nil
                                onDismiss()
                            }
                        )

                        Divider()
                            .padding(.leading, 48)

                        // Knowledge bases
                        ForEach(knowledgeBases) { kb in
                            KnowledgeBaseSelectionRow(
                                knowledgeBase: kb,
                                isSelected: selectedKnowledgeBase?.id == kb.id,
                                onSelect: {
                                    selectedKnowledgeBase = kb
                                    onDismiss()
                                }
                            )

                            if kb.id != knowledgeBases.last?.id {
                                Divider()
                                    .padding(.leading, 48)
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .frame(width: 320)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 8)
    }
}

/// Knowledge Base Selection Row
struct KnowledgeBaseSelectionRow: View {
    let knowledgeBase: KnowledgeBase?
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: knowledgeBase?.type.icon ?? "xmark.circle")
                    .font(.system(size: 20))
                    .foregroundColor(knowledgeBase != nil ? .accentColor : .secondary)
                    .frame(width: 24, height: 24)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(knowledgeBase?.name ?? "None")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if let kb = knowledgeBase {
                        Text("\(kb.totalDocuments) documents • \(kb.totalChunks) chunks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No knowledge base selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 18))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            isSelected ? Color.accentColor.opacity(0.1) : Color.clear
        )
    }
}

/// Custom NSTextView that handles Command+Enter
class CustomTextView: NSTextView {
    var onCommandEnter: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        // Check for Command+Enter
        if event.keyCode == 36 && event.modifierFlags.contains(.command) {  // 36 = Return key
            print("CustomTextView: Command+Enter detected via keyDown")
            onCommandEnter?()
            return
        }
        super.keyDown(with: event)
    }
}

/// NSTextView wrapper for multi-line input with auto-expansion
struct ExpandableTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    @Binding var isDisabled: Bool

    let minHeight: CGFloat
    let maxHeight: CGFloat
    let onSend: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = CustomTextView()

        // Store reference in coordinator
        context.coordinator.textView = textView

        // Set up Command+Enter handler
        textView.onCommandEnter = { [weak textView] in
            guard let textView = textView, !textView.string.isEmpty else { return }
            print("CustomTextView: onCommandEnter callback triggered")
            DispatchQueue.main.async {
                self.onSend()
            }
        }

        // Configure text view
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = NSColor.textColor  // System text color (adapts to dark mode)
        textView.backgroundColor = NSColor.textBackgroundColor  // System background (adapts to dark mode)
        textView.drawsBackground = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainerInset = NSSize(width: 4, height: 8)  // Reduced padding
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.insertionPointColor = NSColor.textColor  // Cursor color matches text

        // Configure scroll view
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true  // Must draw background to show text
        scrollView.backgroundColor = NSColor.textBackgroundColor  // System background (adapts to dark mode)
        scrollView.borderType = .noBorder

        // Configure text container - DON'T set containerSize, let it auto-resize
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true

        // Make sure the text view becomes first responder when window appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // FIX: Ensure textView has proper width
        if textView.frame.width == 0 {
            let scrollWidth = scrollView.frame.width
            if scrollWidth > 0 {
                textView.frame = NSRect(
                    x: 0, y: 0, width: scrollWidth, height: textView.frame.height)
                textView.textContainer?.containerSize = NSSize(
                    width: scrollWidth, height: .greatestFiniteMagnitude)
            }
        }

        if textView.string != text {
            textView.string = text
            updateHeight(for: textView)
        }

        textView.isEditable = !isDisabled
        textView.isSelectable = true
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func updateHeight(for textView: NSTextView) {
        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer

        layoutManager?.ensureLayout(for: textContainer!)
        let usedRect = layoutManager?.usedRect(for: textContainer!)
        let newHeight = (usedRect?.height ?? 0) + 24  // Add padding

        DispatchQueue.main.async {
            self.height = max(minHeight, min(newHeight, maxHeight))
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ExpandableTextEditor
        weak var textView: CustomTextView?

        init(_ parent: ExpandableTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.updateHeight(for: textView)
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            print("ExpandableTextInput: doCommandBy called with selector: \(commandSelector)")

            // Command + Enter to send
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                let event = NSApp.currentEvent
                print(
                    "ExpandableTextInput: insertNewline detected, modifierFlags: \(String(describing: event?.modifierFlags))"
                )

                if event?.modifierFlags.contains(.command) == true {
                    print("ExpandableTextInput: Command+Enter detected, triggering onSend")

                    // Don't trigger if text is empty or disabled
                    guard !parent.text.isEmpty && !parent.isDisabled else {
                        print("ExpandableTextInput: Ignoring - text empty or disabled")
                        return false
                    }

                    // Trigger the send action
                    DispatchQueue.main.async {
                        self.parent.onSend()
                    }
                    return true
                }
            }
            return false
        }

        @MainActor
        func focusTextView() {
            textView?.window?.makeFirstResponder(textView)
        }
    }
}
