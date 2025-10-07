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

    // 会话跟踪
    var currentSession: ConversationSession?
    var hasInteraction: Bool = false

    init(tabId: UUID, settings: AppSettings) {
        self.tabId = tabId
        self.settings = settings

        // Monitor avatar changes via UserDefaults
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.updateAvatarInWebView()
            }
            .store(in: &cancellables)
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

    private func updateAvatarInWebView() {
        guard isPluginLoaded, let webView = webView else { return }

        // Convert avatar to data URL
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
                }
            }
        }

        // Update avatar in WebView via JavaScript
        let script = """
        (function() {
            if (window.INITIAL_SETTINGS) {
                window.INITIAL_SETTINGS.userAvatar = '\(avatarValue)';
                console.log('Avatar updated:', window.INITIAL_SETTINGS.userAvatar.substring(0, 50));

                // If chatApp exists, update userSettings
                if (window.chatApp && window.chatApp.userSettings) {
                    window.chatApp.userSettings.userAvatar = '\(avatarValue)';
                    console.log('ChatApp avatar updated');
                }
            }
        })();
        """

        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("PluginViewModel: Error updating avatar: \(error)")
            } else {
                print("PluginViewModel: Avatar updated successfully")
            }
        }
    }

    // MARK: - 会话管理

    /// 检查是否有交互内容
    func checkHasInteraction(completion: @escaping (Bool) -> Void) {
        guard let webView = webView else {
            completion(false)
            return
        }

        let script = """
        (function() {
            if (window.chatApp && window.chatApp.messages) {
                return window.chatApp.messages.length > 0;
            }
            return false;
        })();
        """

        webView.evaluateJavaScript(script) { result, error in
            if let hasMessages = result as? Bool {
                completion(hasMessages)
            } else {
                completion(false)
            }
        }
    }

    /// 获取会话标题（第一条用户消息）
    func extractSessionTitle(completion: @escaping (String?) -> Void) {
        guard let webView = webView else {
            completion(nil)
            return
        }

        let script = """
        (function() {
            if (window.chatApp && window.chatApp.messages) {
                const userMessage = window.chatApp.messages.find(m => m.role === 'user');
                if (userMessage && userMessage.content) {
                    // 截取前50个字符作为标题
                    return userMessage.content.substring(0, 50);
                }
            }
            return null;
        })();
        """

        webView.evaluateJavaScript(script) { result, error in
            completion(result as? String)
        }
    }

    /// 获取消息数量
    func getMessageCount(completion: @escaping (Int) -> Void) {
        guard let webView = webView else {
            completion(0)
            return
        }

        let script = """
        (function() {
            if (window.chatApp && window.chatApp.messages) {
                return window.chatApp.messages.length;
            }
            return 0;
        })();
        """

        webView.evaluateJavaScript(script) { result, error in
            completion((result as? Int) ?? 0)
        }
    }

    /// 获取完整的 WebView HTML 内容
    func captureWebViewHTML(completion: @escaping (String?) -> Void) {
        guard let webView = webView else {
            completion(nil)
            return
        }

        // 首先获取消息数据
        let getMessagesScript = """
        (function() {
            if (window.chatApp && window.chatApp.messages) {
                return JSON.stringify(window.chatApp.messages);
            }
            return null;
        })();
        """

        webView.evaluateJavaScript(getMessagesScript) { messagesResult, error in
            // 然后获取 HTML
            webView.evaluateJavaScript("document.documentElement.outerHTML") { htmlResult, htmlError in
                guard var html = htmlResult as? String else {
                    completion(nil)
                    return
                }

                // 如果有消息数据，注入到 HTML 中
                if let messagesJSON = messagesResult as? String {
                    let restorationScript = """
                    <script>
                    // Restore saved messages
                    window.SAVED_MESSAGES = \(messagesJSON);
                    console.log('Loaded saved messages:', window.SAVED_MESSAGES);
                    </script>
                    """

                    // 在 </head> 之前插入
                    if let headEndRange = html.range(of: "</head>", options: .caseInsensitive) {
                        html.insert(contentsOf: restorationScript, at: headEndRange.lowerBound)
                    }
                }

                completion(html)
            }
        }
    }

    /// 保存当前会话
    func saveCurrentSession(historyManager: HistoryManager, completion: @escaping (Bool) -> Void) {
        guard let plugin = currentPlugin else {
            completion(false)
            return
        }

        // 检查是否有交互
        checkHasInteraction { [weak self] hasInteraction in
            guard let self = self, hasInteraction else {
                completion(false)
                return
            }

            // 获取标题和消息数量
            self.extractSessionTitle { title in
                self.getMessageCount { messageCount in
                    self.captureWebViewHTML { html in
                        guard let html = html else {
                            completion(false)
                            return
                        }

                        // 创建或更新会话
                        var session: ConversationSession
                        if let existing = self.currentSession {
                            session = existing
                            session.updatedAt = Date()
                            session.messageCount = messageCount
                            if let newTitle = title, !newTitle.isEmpty {
                                session.title = newTitle
                            }
                        } else {
                            let sessionTitle = title ?? historyManager.generateDefaultTitle(for: plugin.name)
                            session = ConversationSession(
                                pluginId: plugin.id.uuidString,
                                pluginName: plugin.name,
                                title: sessionTitle,
                                messageCount: messageCount
                            )
                            self.currentSession = session
                        }

                        // 保存会话
                        historyManager.saveSession(session, htmlContent: html)
                        self.hasInteraction = true
                        completion(true)
                    }
                }
            }
        }
    }

    /// 加载已有会话
    func loadSession(_ session: ConversationSession, plugin: Plugin, historyManager: HistoryManager) {
        guard let html = historyManager.loadSessionHTML(session) else {
            print("PluginViewModel: Failed to load session HTML")
            return
        }

        self.currentPlugin = plugin
        self.currentSession = session
        self.webViewContent = html
        self.isPluginLoaded = true
        self.hasInteraction = true
        print("PluginViewModel: Loaded session '\(session.title)' for plugin '\(plugin.name)'")
    }
}
