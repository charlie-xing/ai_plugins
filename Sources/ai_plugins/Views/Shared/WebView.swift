import SwiftUI
import WebKit

// Custom WKWebView that doesn't accept first responder
class NonInteractiveWebView: WKWebView {
    override var acceptsFirstResponder: Bool {
        return false
    }
}

// A SwiftUI wrapper for WKWebView that can be updated programmatically
class UpdatableWebView: NSView {
    let webView: NonInteractiveWebView

    override init(frame: CGRect) {
        webView = NonInteractiveWebView()
        super.init(frame: frame)
        addSubview(webView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool {
        return false
    }

    override func layout() {
        super.layout()
        webView.frame = bounds
    }

    func loadHTML(_ htmlString: String) {
        webView.loadHTMLString(htmlString, baseURL: nil)
    }
}

struct WebView: NSViewRepresentable {
    let htmlContent: String

    func makeNSView(context: Context) -> UpdatableWebView {
        let webView = UpdatableWebView()
        webView.loadHTML(htmlContent) // Load initial content
        return webView
    }

    func updateNSView(_ nsView: UpdatableWebView, context: Context) {
        print("--- WebView: updateNSView Called ---")
        print("Incoming HTML hash: \(htmlContent.hashValue)")
        print("Coordinator HTML hash: \(context.coordinator.lastLoadedHTML.hashValue)")
        
        // By comparing the new content with the coordinator's state, we ensure
        // that we only reload the web view when the content has actually changed.
        if htmlContent != context.coordinator.lastLoadedHTML {
            print("Content is DIFFERENT. Loading new HTML.")
            nsView.loadHTML(htmlContent)
            context.coordinator.lastLoadedHTML = htmlContent
        } else {
            print("Content is the SAME. Skipping reload.")
        }
        print("------------------------------------")
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: WebView
        var lastLoadedHTML: String = ""

        init(_ parent: WebView) {
            self.parent = parent
            self.lastLoadedHTML = parent.htmlContent
        }
    }
}