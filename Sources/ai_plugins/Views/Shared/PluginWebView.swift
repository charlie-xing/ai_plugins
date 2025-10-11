import SwiftUI
import WebKit

/// A SwiftUI wrapper for WKWebView with integrated WebViewBridge
/// This replaces the old JSCore + WebView approach with a pure WKWebView solution
struct PluginWebView: NSViewRepresentable {
    let viewModel: PluginViewModel
    let tabId: UUID
    let htmlContent: String
    let settings: AppSettings?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()

        // Register message handlers for JS -> Swift communication
        userContentController.add(context.coordinator.bridge, name: "callAI")
        userContentController.add(context.coordinator.bridge, name: "log")
        userContentController.add(context.coordinator.bridge, name: "getSettings")
        userContentController.add(context.coordinator.bridge, name: "runPythonScript")
        userContentController.add(context.coordinator.bridge, name: "consoleLog")

        config.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground") // Transparent background

        // Enable Safari Web Inspector for debugging
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        } else {
            // For older versions, enable developer extras
            UserDefaults.standard.set(true, forKey: "WebKitDeveloperExtras")
        }

        // Link bridge to webView AND link webView to viewModel
        context.coordinator.bridge.webView = webView
        viewModel.webView = webView

        // Load initial content
        if !htmlContent.isEmpty {
            webView.loadHTMLString(htmlContent, baseURL: nil)
            context.coordinator.lastLoadedHTML = htmlContent
        }

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Only reload if content has changed
        if htmlContent != context.coordinator.lastLoadedHTML && !htmlContent.isEmpty {
            print("PluginWebView: Loading new HTML content (length: \(htmlContent.count))")
            nsView.loadHTMLString(htmlContent, baseURL: nil)
            context.coordinator.lastLoadedHTML = htmlContent
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(tabId: tabId, settings: settings, initialHTML: htmlContent)
    }

    @MainActor
    class Coordinator: NSObject {
        let bridge: WebViewBridge
        var lastLoadedHTML: String

        init(tabId: UUID, settings: AppSettings?, initialHTML: String) {
            self.bridge = WebViewBridge(tabId: tabId, settings: settings)
            self.lastLoadedHTML = initialHTML
            super.init()
        }
    }
}
