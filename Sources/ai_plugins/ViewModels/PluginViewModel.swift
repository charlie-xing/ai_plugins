import Foundation
import Combine

@MainActor
class PluginViewModel: ObservableObject {
    @Published var webViewContent: String = "<html><body><h1>Welcome!</h1><p>Enter a prompt below and run the plugin.</p></body></html>"
    @Published var prompt: String = ""

    let tabId: UUID
    private var jsBridge: JSBridge
    private var cancellables = Set<AnyCancellable>()

    init(tabId: UUID, settings: AppSettings) {
        self.tabId = tabId
        self.jsBridge = JSBridge(tabId: tabId, settings: settings)

        // Listen for UI update notifications from JavaScript and filter by tabId
        NotificationCenter.default.publisher(for: NSNotification.Name("PluginUIUpdate"))
            .filter {
                // Ensure the notification is for this specific tab instance.
                guard let notificationTabId = $0.userInfo?["tabId"] as? UUID else { return false }
                return notificationTabId == self.tabId
            }
            .compactMap { $0.userInfo?["htmlContent"] as? String }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] htmlContent in
                guard let self = self else { return }
                print(">>> PluginViewModel [\(self.tabId.uuidString.prefix(4))]: Received PluginUIUpdate Notification!")
                print(">>> New HTML Content Length: \(htmlContent.count)")
                self.webViewContent = htmlContent
                print(">>> self.webViewContent has been updated.")
            }
            .store(in: &cancellables)
    }
    
    func runPlugin(plugin: Plugin) {
        print("PluginViewModel: Running plugin '\(plugin.name)' with prompt: '\(prompt)'")

        // Save prompt and clear it immediately
        let currentPrompt = prompt
        prompt = ""

        guard let resultValue = jsBridge.runPlugin(plugin: plugin, args: [currentPrompt]) else {
            print("PluginViewModel: Failed to execute plugin - resultValue is nil")
            self.webViewContent = "<h1>Error</h1><p>Failed to execute plugin.</p>"
            return
        }

        // If the result is undefined, it likely means the plugin is running an async operation
        // (e.g., streaming) and will update the UI via `updateUI` notification.
        // In this case, we don't want to overwrite the UI with an error.
        if resultValue.isUndefined {
            print("PluginViewModel: Plugin returned undefined, likely running an async operation. Awaiting UI update notification.")
            return
        }

        // The JS function is expected to return an object like {content: "...", type: "...", replace: true}
        if let resultDict = resultValue.toDictionary() {
            print("PluginViewModel: Converted to dictionary: \(resultDict)")

            if let content = resultDict["content"] as? String,
               let type = resultDict["type"] as? String {
                print("PluginViewModel: Got content (length: \(content.count)) and type: \(type)")

                if type == "html" {
                    self.webViewContent = content
                } else {
                    // Handle other content types like 'text', 'imageUrl', etc.
                    self.webViewContent = "<h1>\(content)</h1>"
                }
            } else {
                print("PluginViewModel: Failed to extract content or type from dictionary")
                print("PluginViewModel: content type: \(type(of: resultDict["content"]))")
                print("PluginViewModel: type type: \(type(of: resultDict["type"]))")
                self.webViewContent = "<h1>Error</h1><p>Plugin returned an invalid result format. Missing content or type.</p>"
            }
        } else {
            print("PluginViewModel: Failed to convert resultValue to dictionary")
            self.webViewContent = "<h1>Error</h1><p>Plugin returned an invalid result format.</p>"
        }
    }
}