import Foundation
import Combine
import WebKit
import AppKit

@MainActor
class PluginViewModel: ObservableObject {
    @Published var webViewContent: String = ""
    @Published var prompt: String = ""

    let tabId: UUID
    private var cancellables = Set<AnyCancellable>()
    weak var webView: WKWebView?  // Will be set by PluginWebView
    private var isPluginLoaded = false
    private var currentPlugin: Plugin?
    private let settings: AppSettings

    init(tabId: UUID, settings: AppSettings) {
        self.tabId = tabId
        self.settings = settings
    }

    func runPlugin(plugin: Plugin) {
        print("PluginViewModel: Running plugin '\(plugin.name)' with prompt: '\(prompt)'")

        let currentPrompt = prompt
        prompt = ""

        // If this is the first run or a different plugin, load the HTML
        if !isPluginLoaded || currentPlugin?.id != plugin.id {
            guard let pluginJS = loadPluginScript(plugin: plugin) else {
                print("PluginViewModel: Failed to load plugin script")
                self.webViewContent = "<html><body><h1>Error</h1><p>Failed to load plugin script.</p></body></html>"
                return
            }

            let htmlPage = createHTMLPage(pluginScript: pluginJS)
            self.webViewContent = htmlPage
            self.isPluginLoaded = true
            self.currentPlugin = plugin

            // Execute plugin after delay to ensure HTML and auto-init complete
            // Auto-init in DOMContentLoaded needs time to load marked.js and highlight.js
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.executePlugin(prompt: currentPrompt)
            }
        } else {
            // Plugin already loaded, just execute with new prompt
            executePlugin(prompt: currentPrompt)
        }
    }

    private func executePlugin(prompt: String) {
        let escapedPrompt = prompt
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")

        // Wrap the call to handle undefined return value
        let script = """
        (function() {
            if (typeof runPlugin === 'function') {
                runPlugin('\(escapedPrompt)');
            }
            return null;
        })();
        """
        webView?.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("PluginViewModel: Error executing plugin: \(error)")
            }
        }
    }

    private func loadPluginScript(plugin: Plugin) -> String? {
        do {
            let content = try String(contentsOf: plugin.filePath, encoding: .utf8)
            print("PluginViewModel: Loaded plugin script from \(plugin.filePath), length: \(content.count)")
            return content
        } catch {
            print("PluginViewModel: Error loading plugin file: \(error)")
            return nil
        }
    }

    private func createHTMLPage(pluginScript: String) -> String {
        // Prepare settings JSON to inject
        let settingsJSON = createSettingsJSON()

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body>
            <script>
            // Inject settings before plugin loads
            window.INITIAL_SETTINGS = \(settingsJSON);
            console.log('Injected settings:', window.INITIAL_SETTINGS);

            // Plugin code
            \(pluginScript)

            // Mark as ready
            window.addEventListener('DOMContentLoaded', function() {
                console.log('DOM loaded, plugin ready');
            });
            </script>
        </body>
        </html>
        """
    }

    private func createSettingsJSON() -> String {
        guard let activeProvider = settings.aiProviders.first(where: { $0.id == settings.activeProviderId }),
              let selectedModel = settings.availableModels.first(where: { $0.id == settings.selectedModelId }) else {
            return "{}"
        }

        // Convert avatar image to data URL (resize to 64x64 to keep HTML small)
        var avatarValue = "👤"
        if !settings.userAvatarPath.isEmpty {
            if let image = NSImage(contentsOfFile: settings.userAvatarPath) {
                // Resize to 64x64 to reduce data size
                let targetSize = NSSize(width: 64, height: 64)
                let resizedImage = NSImage(size: targetSize)
                resizedImage.lockFocus()
                image.draw(in: NSRect(origin: .zero, size: targetSize),
                          from: NSRect(origin: .zero, size: image.size),
                          operation: .copy,
                          fraction: 1.0)
                resizedImage.unlockFocus()

                if let tiffData = resizedImage.tiffRepresentation,
                   let bitmapImage = NSBitmapImageRep(data: tiffData),
                   let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) {
                    let base64String = jpegData.base64EncodedString()
                    avatarValue = "data:image/jpeg;base64,\(base64String)"
                    print("PluginViewModel: Avatar data URL size: \(jpegData.count) bytes")
                }
            }
        }

        let settingsDict: [String: Any] = [
            "apiEndpoint": activeProvider.apiEndpoint,
            "selectedModel": selectedModel.id,
            "selectedModelName": selectedModel.name,
            "userName": settings.userName.isEmpty ? "User" : settings.userName,
            "userAvatar": avatarValue
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: settingsDict),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }

        return "{}"
    }
}
