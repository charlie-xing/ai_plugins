import SwiftUI
import AppKit

// Custom NSTextView wrapper that properly handles keyboard input
struct CustomTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onSubmit: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = NSColor.textColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainerInset = NSSize(width: 8, height: 8)

        // Configure scroll view
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        // Auto-focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let window = textView.window {
                window.makeFirstResponder(textView)
            }
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        if textView.string != text {
            textView.string = text
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CustomTextEditor

        init(_ parent: CustomTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let newText = textView.string

            DispatchQueue.main.async {
                self.parent.text = newText
            }
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Handle Cmd+Enter to submit
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Check if Cmd key is pressed
                if NSEvent.modifierFlags.contains(.command) {
                    DispatchQueue.main.async {
                        self.parent.onSubmit?()
                    }
                    return true
                }
            }
            return false
        }
    }
}
