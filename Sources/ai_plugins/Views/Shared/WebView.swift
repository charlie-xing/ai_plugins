import SwiftUI
import WebKit

// A SwiftUI wrapper for WKWebView that can be updated programmatically
class UpdatableWebView: NSView {
    let webView = WKWebView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(webView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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