import Foundation
import Combine

@MainActor
class PluginViewModel: ObservableObject {
    @Published var webViewContent: String = "<html><body><h1>Welcome!</h1><p>Enter a prompt below and run the plugin.</p></body></html>"
    @Published var prompt: String = ""

    private var jsBridge: JSBridge
    private var cancellables = Set<AnyCancellable>()

    init(settings: AppSettings) {
        self.jsBridge = JSBridge(settings: settings)

        // Listen for UI update notifications from JavaScript
        NotificationCenter.default.publisher(for: NSNotification.Name("PluginUIUpdate"))
            .compactMap { $0.userInfo?["htmlContent"] as? String }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] htmlContent in
                guard let self = self else { return }
                print("PluginViewModel: Received UI update from JavaScript, HTML length: \(htmlContent.count)")
                self.webViewContent = htmlContent
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

        print("PluginViewModel: Got resultValue: \(resultValue)")
        print("PluginViewModel: resultValue type: \(type(of: resultValue))")
        print("PluginViewModel: resultValue.isObject: \(resultValue.isObject)")
        print("PluginViewModel: resultValue.isUndefined: \(resultValue.isUndefined)")
        print("PluginViewModel: resultValue.isNull: \(resultValue.isNull)")

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