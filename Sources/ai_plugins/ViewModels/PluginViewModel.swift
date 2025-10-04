import Foundation
import Combine

@MainActor
class PluginViewModel: ObservableObject {
    @Published var webViewContent: String = "<html><body><h1>Welcome!</h1><p>Enter a prompt below and run the plugin.</p></body></html>"
    @Published var prompt: String = ""
    
    private let jsBridge = JSBridge()
    
    func runPlugin(plugin: Plugin) {
        guard let resultValue = jsBridge.runPlugin(plugin: plugin, args: [prompt]) else {
            self.webViewContent = "<h1>Error</h1><p>Failed to execute plugin.</p>"
            return
        }
        
        // The JS function is expected to return an object like {content: "...", type: "...", replace: true}
        if let resultDict = resultValue.toDictionary(),
           let content = resultDict["content"] as? String,
           let type = resultDict["type"] as? String {
            
            if type == "html" {
                self.webViewContent = content
            } else {
                // Handle other content types like 'text', 'imageUrl', etc.
                self.webViewContent = "<h1>\(content)</h1>"
            }
        } else {
            self.webViewContent = "<h1>Error</h1><p>Plugin returned an invalid result format.</p>"
        }
    }
}