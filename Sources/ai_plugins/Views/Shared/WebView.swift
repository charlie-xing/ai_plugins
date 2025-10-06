import SwiftUI
import WebKit

// Custom WKWebView that doesn't accept first responder
class NonInteractiveWebView: WKWebView {
    override var acceptsFirstResponder: Bool {
        return false
    }

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)

        // Enable Safari Web Inspector for debugging
        if #available(macOS 13.3, *) {
            self.isInspectable = true
        } else {
            // For older versions, enable developer extras
            UserDefaults.standard.set(true, forKey: "WebKitDeveloperExtras")
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        // Enable Safari Web Inspector for debugging
        if #available(macOS 13.3, *) {
            self.isInspectable = true
        } else {
            // For older versions, enable developer extras
            UserDefaults.standard.set(true, forKey: "WebKitDeveloperExtras")
        }
    }
}

// A SwiftUI wrapper for WKWebView that can be updated programmatically
class UpdatableWebView: NSView {
    let webView: NonInteractiveWebView

    override init(frame: CGRect) {
        let config = WKWebViewConfiguration()
        webView = NonInteractiveWebView(frame: .zero, configuration: config)
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

    func evaluateJavaScript(_ script: String) {
        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("WebView JS Error: \(error)")
                print("Script that failed: \(script.prefix(500))...")
            }
        }
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

        // Check if this is a JavaScript execution command
        if htmlContent.hasPrefix("<script>") && htmlContent.hasSuffix("</script>") {
            // Extract JavaScript code and execute it
            let startIndex = htmlContent.index(htmlContent.startIndex, offsetBy: 8)
            let endIndex = htmlContent.index(htmlContent.endIndex, offsetBy: -9)
            let jsCode = String(htmlContent[startIndex..<endIndex])
            print("Executing JavaScript: \(jsCode.prefix(100))...")

            // Try to execute, if it fails due to function not ready, retry with delay
            nsView.webView.evaluateJavaScript(jsCode) { result, error in
                if let error = error {
                    print("WebView JS Error: \(error)")
                    print("Script that failed: \(jsCode.prefix(500))...")

                    // If function not defined, retry after a short delay
                    if error.localizedDescription.contains("undefined is not a function") {
                        print("Function not ready, retrying after delay...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            nsView.webView.evaluateJavaScript(jsCode) { _, retryError in
                                if let retryError = retryError {
                                    print("Retry failed: \(retryError)")
                                } else {
                                    print("Retry succeeded!")
                                }
                            }
                        }
                    }
                }
            }
            return
        }

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