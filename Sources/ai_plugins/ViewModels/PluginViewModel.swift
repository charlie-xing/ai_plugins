import AppKit
import Combine
import Foundation
import WebKit

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

    // RAG 相关
    var selectedKnowledgeBase: KnowledgeBase?
    private var currentRAGContext: RAGContext?
    private let ragService = RAGService.shared
    private var currentEnhancedPrompt: String?

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

    func runPlugin(plugin: Plugin, knowledgeBase: KnowledgeBase? = nil) {
        print("PluginViewModel: Running plugin '\(plugin.name)' with prompt: '\(prompt)'")

        let currentPrompt = prompt
        prompt = ""

        // Update selected knowledge base if provided
        if let kb = knowledgeBase {
            selectedKnowledgeBase = kb
        }

        // If this is the first run or a different plugin, load the HTML
        if !isPluginLoaded || currentPlugin?.id != plugin.id {
            guard let pluginJS = loadPluginScript(plugin: plugin) else {
                print("PluginViewModel: Failed to load plugin script")
                self.webViewContent =
                    "<html><body><h1>Error</h1><p>Failed to load plugin script.</p></body></html>"
                return
            }

            let htmlPage = createHTMLPage(pluginScript: pluginJS)
            self.webViewContent = htmlPage
            self.isPluginLoaded = true
            self.currentPlugin = plugin

            // Execute plugin after delay to ensure HTML and auto-init complete
            // Auto-init in DOMContentLoaded needs time to load marked.js and highlight.js
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.executePluginWithRAG(prompt: currentPrompt)
            }
        } else {
            // Plugin already loaded, just execute with new prompt
            executePluginWithRAG(prompt: currentPrompt)
        }
    }

    private func executePluginWithRAG(prompt: String) {
        // Check if we should use RAG
        guard let knowledgeBase = selectedKnowledgeBase else {
            // No knowledge base selected, execute normally
            executePlugin(originalPrompt: prompt, enhancedPrompt: prompt)
            return
        }

        // Perform RAG enhancement
        Task { @MainActor in
            do {
                let ragContext = try await ragService.enhancePrompt(prompt, using: knowledgeBase)
                currentRAGContext = ragContext

                print(
                    "PluginViewModel: RAG enhanced prompt with \(ragContext.retrievedChunks.count) results"
                )

                print("PluginViewModel: RAG enhancement completed")
                print("PluginViewModel: Original prompt length: \(prompt.count)")
                print("PluginViewModel: Enhanced prompt length: \(ragContext.enhancedPrompt.count)")
                print(
                    "PluginViewModel: Enhanced prompt preview: \(String(ragContext.enhancedPrompt.prefix(200)))..."
                )

                // Execute with original prompt for display, enhanced prompt for AI
                executePlugin(originalPrompt: prompt, enhancedPrompt: ragContext.enhancedPrompt)

            } catch {
                print("PluginViewModel: RAG enhancement failed: \(error)")
                // Fallback to original prompt
                executePlugin(originalPrompt: prompt, enhancedPrompt: prompt)
            }
        }
    }

    private func executePlugin(originalPrompt: String, enhancedPrompt: String) {
        print("PluginViewModel: executePlugin called")
        print("PluginViewModel: Original prompt: '\(originalPrompt)'")
        print(
            "PluginViewModel: Enhanced prompt differs from original: \(enhancedPrompt != originalPrompt)"
        )

        // Store the enhanced prompt for AI calls
        currentEnhancedPrompt = enhancedPrompt

        // Escape the original prompt for display
        let escapedPrompt =
            originalPrompt
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")

        // Escape the enhanced prompt for JavaScript injection
        let escapedEnhancedPrompt =
            enhancedPrompt
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")

        // First, inject the enhanced prompt into INITIAL_SETTINGS
        let updateSettingsScript = """
            (function() {
                if (window.INITIAL_SETTINGS) {
                    window.INITIAL_SETTINGS.enhancedPrompt = '\(escapedEnhancedPrompt)';
                    console.log('Updated INITIAL_SETTINGS.enhancedPrompt (length: \(enhancedPrompt.count))');
                    console.log('Enhanced prompt preview:', '\(escapedEnhancedPrompt)'.substring(0, 200) + '...');
                } else {
                    console.error('INITIAL_SETTINGS not found when trying to inject enhanced prompt');
                }
            })();
            """

        // Then call the plugin with original prompt
        let runPluginScript = """
            (function() {
                if (typeof runPlugin === 'function') {
                    runPlugin('\(escapedPrompt)');
                }
                return null;
            })();
            """

        // Execute both scripts sequentially
        webView?.evaluateJavaScript(updateSettingsScript) { [weak self] result, error in
            if let error = error {
                print("PluginViewModel: Error updating settings: \(error)")
            } else {
                print("PluginViewModel: Successfully injected enhanced prompt to JavaScript")
            }

            self?.webView?.evaluateJavaScript(runPluginScript) { result, error in
                if let error = error {
                    print("PluginViewModel: Error executing plugin: \(error)")
                } else {
                    print("PluginViewModel: Successfully called runPlugin with original prompt")
                }
            }
        }
    }

    private func loadPluginScript(plugin: Plugin) -> String? {
        do {
            let content = try String(contentsOf: plugin.filePath, encoding: .utf8)
            print(
                "PluginViewModel: Loaded plugin script from \(plugin.filePath), length: \(content.count)"
            )
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
        guard
            let activeProvider = settings.aiProviders.first(where: {
                $0.id == settings.activeProviderId
            }),
            let selectedModel = settings.availableModels.first(where: {
                $0.id == settings.selectedModelId
            })
        else {
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
                image.draw(
                    in: NSRect(origin: .zero, size: targetSize),
                    from: NSRect(origin: .zero, size: image.size),
                    operation: .copy,
                    fraction: 1.0)
                resizedImage.unlockFocus()

                if let tiffData = resizedImage.tiffRepresentation,
                    let bitmapImage = NSBitmapImageRep(data: tiffData),
                    let jpegData = bitmapImage.representation(
                        using: .jpeg, properties: [.compressionFactor: 0.7])
                {
                    let base64String = jpegData.base64EncodedString()
                    avatarValue = "data:image/jpeg;base64,\(base64String)"
                    print("PluginViewModel: Avatar data URL size: \(jpegData.count) bytes")
                }
            }
        }

        var settingsDict: [String: Any] = [
            "apiEndpoint": activeProvider.apiEndpoint,
            "selectedModel": selectedModel.id,
            "selectedModelName": selectedModel.name,
            "userName": settings.userName.isEmpty ? "User" : settings.userName,
            "userAvatar": avatarValue,
        ]

        // Add RAG context if available
        if let ragContext = currentRAGContext {
            let ragInfo: [String: Any] = [
                "hasKnowledgeBase": true,
                "knowledgeBaseName": ragContext.knowledgeBase.name,
                "resultsCount": ragContext.retrievedChunks.count,
                "averageSimilarity": ragContext.averageSimilarity,
                "contextLength": ragContext.contextText.count,
            ]
            settingsDict["ragContext"] = ragInfo

            // Add system prompt with RAG context
            settingsDict["systemPrompt"] = ragService.buildSystemPrompt(with: ragContext)

            // Add enhanced prompt for AI calls
            if let enhancedPrompt = currentEnhancedPrompt {
                settingsDict["enhancedPrompt"] = enhancedPrompt
            }
        } else if selectedKnowledgeBase != nil {
            settingsDict["hasKnowledgeBase"] = true
            settingsDict["knowledgeBaseName"] = selectedKnowledgeBase?.name ?? ""
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: settingsDict),
            let jsonString = String(data: jsonData, encoding: .utf8)
        {
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
                image.draw(
                    in: NSRect(origin: .zero, size: targetSize),
                    from: NSRect(origin: .zero, size: image.size),
                    operation: .copy,
                    fraction: 1.0)
                resizedImage.unlockFocus()

                if let tiffData = resizedImage.tiffRepresentation,
                    let bitmapImage = NSBitmapImageRep(data: tiffData),
                    let jpegData = bitmapImage.representation(
                        using: .jpeg, properties: [.compressionFactor: 0.7])
                {
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
            webView.evaluateJavaScript("document.documentElement.outerHTML") {
                htmlResult, htmlError in
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
                            let sessionTitle =
                                title ?? historyManager.generateDefaultTitle(for: plugin.name)
                            session = ConversationSession(
                                pluginId: plugin.id.uuidString,
                                pluginName: plugin.name,
                                title: sessionTitle,
                                messageCount: messageCount
                            )
                            self.currentSession = session
                        }

                        // 保存会话（包含RAG上下文信息）
                        historyManager.saveSession(session, htmlContent: html)
                        self.hasInteraction = true
                        completion(true)
                    }
                }
            }
        }
    }

    // MARK: - RAG Support Methods

    /// 设置知识库
    func setKnowledgeBase(_ knowledgeBase: KnowledgeBase?) {
        selectedKnowledgeBase = knowledgeBase
        currentRAGContext = nil
        print("PluginViewModel: Knowledge base set to: \(knowledgeBase?.name ?? "None")")
    }

    /// 获取当前RAG上下文信息
    func getCurrentRAGInfo() -> String? {
        guard let context = currentRAGContext else { return nil }

        let info = """
            Knowledge Base: \(context.knowledgeBase.name)
            Retrieved \(context.retrievedChunks.count) relevant chunks
            Average similarity: \(String(format: "%.3f", context.averageSimilarity))
            """

        return info
    }

    /// 加载已有会话
    func loadSession(_ session: ConversationSession, plugin: Plugin, historyManager: HistoryManager)
    {
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
