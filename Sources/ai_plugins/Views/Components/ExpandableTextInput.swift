import SwiftUI
import AppKit

/// Multi-line expandable text input with toolbar
struct ExpandableTextInput: View {
    @Binding var text: String
    @State private var textHeight: CGFloat = 44 // Single line height
    @State private var isDisabled: Bool = false

    let placeholder: String
    let onSend: () -> Void

    private let minHeight: CGFloat = 44  // 2 lines (adjusted for proper sizing)
    private let maxHeight: CGFloat = 110 // 5 lines (adjusted for proper sizing)
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

                    ToolbarButton(icon: "books.vertical", tooltip: "Select knowledge base") {
                        // TODO: Implement knowledge base
                    }

                    ToolbarButton(icon: "globe", tooltip: "Web search") {
                        // TODO: Implement web search
                    }

                    ToolbarButton(icon: "magnifyingglass.circle", tooltip: "Deep research") {
                        // TODO: Implement deep research
                    }
                }

                Spacer()

                // Send button
                Button(action: {
                    print("ExpandableTextInput: Send button clicked, text: '\(text)'")
                    onSend()
                }) {
                    HStack(spacing: 4) {
                        Text("Send")
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color(NSColor.controlBackgroundColor))
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
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
        let textView = NSTextView()

        // Store reference in coordinator
        context.coordinator.textView = textView

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
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
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
                textView.frame = NSRect(x: 0, y: 0, width: scrollWidth, height: textView.frame.height)
                textView.textContainer?.containerSize = NSSize(width: scrollWidth, height: .greatestFiniteMagnitude)
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
        let newHeight = (usedRect?.height ?? 0) + 24 // Add padding

        DispatchQueue.main.async {
            self.height = max(minHeight, min(newHeight, maxHeight))
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ExpandableTextEditor
        weak var textView: NSTextView?

        init(_ parent: ExpandableTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.updateHeight(for: textView)
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Command + Enter to send
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                let event = NSApp.currentEvent
                if event?.modifierFlags.contains(.command) == true {
                    parent.onSend()
                    return true
                }
            }
            return false
        }

        func focusTextView() {
            textView?.window?.makeFirstResponder(textView)
        }
    }
}
