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
        return UpdatableWebView()
    }

    func updateNSView(_ nsView: UpdatableWebView, context: Context) {
        nsView.loadHTML(htmlContent)
    }
}