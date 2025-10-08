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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .opacity(0.7)
                .scaleEffect(0.9)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        // Add subtle hover animation
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.03))

            Divider()
                .opacity(0.3)

            // Knowledge Base List
            if knowledgeBases.isEmpty {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(.tertiary.opacity(0.3))
                            .frame(width: 48, height: 48)

                        Image(systemName: "books.vertical")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.secondary)
                            .opacity(0.7)
                    }

                    VStack(spacing: 4) {
                        Text("No Knowledge Bases")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)

                        Text("Create one in Settings to get started")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .opacity(0.85)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
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
                            .padding(.leading, 36)
                            .opacity(0.3)

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
                                    .padding(.leading, 36)
                                    .opacity(0.3)
                            }
                        }
                    }
                }
                .frame(maxHeight: 250)
            }
        }
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.regularMaterial, style: FillStyle())
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.quaternary, lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)
        .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
                .blendMode(.overlay)
        )
    }
}

/// Knowledge Base Selection Row
struct KnowledgeBaseSelectionRow: View {
    let knowledgeBase: KnowledgeBase?
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Icon with subtle background
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(
                            knowledgeBase != nil
                                ? LinearGradient(
                                    colors: [
                                        Color.accentColor.opacity(0.15),
                                        Color.accentColor.opacity(0.05),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [
                                        Color.secondary.opacity(0.08),
                                        Color.secondary.opacity(0.04),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 32, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(.quaternary.opacity(0.5), lineWidth: 0.5)
                        )

                    Image(systemName: knowledgeBase?.type.icon ?? "xmark.circle")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(knowledgeBase != nil ? .accentColor : .secondary)
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(knowledgeBase?.name ?? "None")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if let kb = knowledgeBase {
                        Text("\(kb.totalDocuments) documents • \(kb.totalChunks) chunks")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.secondary)
                            .opacity(0.85)
                    } else {
                        Text("No knowledge base selected")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.secondary)
                            .opacity(0.85)
                    }
                }

                Spacer()

                // Selection indicator with animation
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 20, height: 20)
                            .scaleEffect(isSelected ? 1.0 : 0.1)

                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(isSelected ? 1.0 : 0.1)
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isSelected)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    isSelected
                        ? LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.12), Color.accentColor.opacity(0.06),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : (isHovered
                            ? LinearGradient(
                                colors: [Color.primary.opacity(0.06), Color.primary.opacity(0.02)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.clear], startPoint: .top, endPoint: .bottom))
                )
                .overlay(
                    isSelected
                        ? RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 0.5)
                        : nil
                )
                .animation(.easeInOut(duration: 0.2), value: isHovered)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        )
        .onHover { hovering in
            isHovered = hovering
        }
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
