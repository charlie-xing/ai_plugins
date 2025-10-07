import Foundation
import WebKit
import AppKit

/// Bridge between WKWebView JavaScript and Swift
/// Replaces JSCore-based JSBridge with a simpler WKWebView-only approach
class WebViewBridge: NSObject, WKScriptMessageHandler {

    let tabId: UUID
    weak var webView: WKWebView?
    var settings: AppSettings?

    init(tabId: UUID, settings: AppSettings?) {
        self.tabId = tabId
        self.settings = settings
        super.init()
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else {
            print("WebViewBridge: Invalid message format")
            return
        }

        print("WebViewBridge [\(tabId.uuidString.prefix(4))]: Received action: \(action)")

        switch action {
        case "log":
            if let logMessage = body["message"] as? String {
                print("[Plugin Log]: \(logMessage)")
            }

        case "callAIStream":
            // Accept both old format (single message) and new format (message history)
            if let messages = body["messages"] as? [[String: Any]] {
                handleStreamRequest(messages: messages)
            } else if let userMessage = body["message"] as? String {
                // Fallback to old single-message format
                let singleMessage = [["role": "user", "content": userMessage]]
                handleStreamRequest(messages: singleMessage)
            }

        case "getSettings":
            handleGetSettings()

        case "executeCode":
            if let command = body["command"] as? String,
               let args = body["args"] as? [String],
               let callbackId = body["callbackId"] as? String {
                handleExecuteCode(command: command, args: args, callbackId: callbackId)
            }

        default:
            print("WebViewBridge: Unknown action: \(action)")
        }
    }

    // MARK: - Handler Methods

    private func handleExecuteCode(command: String, args: [String], callbackId: String) {
        print("WebViewBridge: Executing command: \(command) with args: \(args)")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [command] + args

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let output = String(data: outputData, encoding: .utf8) ?? ""
                let error = String(data: errorData, encoding: .utf8) ?? ""

                let exitCode = process.terminationStatus

                Task { @MainActor in
                    if exitCode == 0 {
                        self?.callExecuteCallback(callbackId: callbackId, success: true, output: output)
                    } else {
                        let errorMessage = error.isEmpty ? "Exit code: \(exitCode)" : error
                        self?.callExecuteCallback(callbackId: callbackId, success: false, output: errorMessage)
                    }
                }
            } catch {
                Task { @MainActor in
                    self?.callExecuteCallback(callbackId: callbackId, success: false, output: error.localizedDescription)
                }
            }
        }
    }

    private func callExecuteCallback(callbackId: String, success: Bool, output: String) {
        let escapedOutput = output
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")

        let script = """
        (function() {
            if (window.executeCallbacks && window.executeCallbacks['\(callbackId)']) {
                window.executeCallbacks['\(callbackId)'](\(success), '\(escapedOutput)');
                delete window.executeCallbacks['\(callbackId)'];
            }
        })();
        """
        callJavaScript(script)
    }

    private func handleStreamRequest(messages: [[String: Any]]) {
        guard let settings = settings,
              let activeProvider = settings.aiProviders.first(where: { $0.id == settings.activeProviderId }),
              let selectedModel = settings.availableModels.first(where: { $0.id == settings.selectedModelId }) else {
            callJavaScript("window.onStreamError?.('Please configure AI provider and select a model in Settings first.')")
            return
        }

        let endpoint = "\(activeProvider.apiEndpoint)/chat/completions"
        guard let url = URL(string: endpoint) else {
            callJavaScript("window.onStreamError?.('Invalid API endpoint')")
            return
        }

        print("WebViewBridge: Starting stream to \(endpoint) with \(messages.count) messages in context")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(activeProvider.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        let requestBody: [String: Any] = [
            "model": selectedModel.id,
            "messages": messages,  // Use full conversation history
            "temperature": 0.7,
            "max_tokens": 2000,
            "stream": true
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

            let delegate = StreamingDelegate(bridge: self)
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            session.dataTask(with: request).resume()

        } catch {
            callJavaScript("window.onStreamError?.('\(error.localizedDescription)')")
        }
    }

    private func handleGetSettings() {
        guard let settings = settings,
              let activeProvider = settings.aiProviders.first(where: { $0.id == settings.activeProviderId }),
              let selectedModel = settings.availableModels.first(where: { $0.id == settings.selectedModelId }) else {
            callJavaScript("window.onSettings?.({})")
            return
        }

        // Convert avatar image to data URL if it's a file path
        var avatarValue = "👤"
        if !settings.userAvatarPath.isEmpty {
            if let image = NSImage(contentsOfFile: settings.userAvatarPath),
               let tiffData = image.tiffRepresentation,
               let bitmapImage = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                let base64String = pngData.base64EncodedString()
                avatarValue = "data:image/png;base64,\(base64String)"
                print("WebViewBridge: Converted avatar to data URL, size: \(pngData.count) bytes")
            } else {
                print("WebViewBridge: Failed to load avatar image from: \(settings.userAvatarPath)")
            }
        }

        let settingsDict: [String: Any] = [
            "apiEndpoint": activeProvider.apiEndpoint,
            "selectedModel": selectedModel.id,
            "selectedModelName": selectedModel.name,
            "userName": settings.userName.isEmpty ? "User" : settings.userName,
            "userAvatar": avatarValue
        ]

        print("WebViewBridge: Sending settings to JS - userName: \(settings.userName)")

        if let jsonData = try? JSONSerialization.data(withJSONObject: settingsDict),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            callJavaScript("window.onSettings?.(\(jsonString))")
        }
    }

    // MARK: - JavaScript Execution

    func callJavaScript(_ script: String) {
        Task { @MainActor in
            webView?.evaluateJavaScript(script) { result, error in
                if let error = error {
                    print("WebViewBridge JS Error: \(error)")
                }
            }
        }
    }

    func sendChunk(_ chunk: String) {
        // Escape the chunk for JavaScript string
        let escapedChunk = chunk
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")

        callJavaScript("window.onStreamChunk?.('\(escapedChunk)')")
    }

    func sendComplete(error: String? = nil) {
        if let error = error {
            let escapedError = error
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            callJavaScript("window.onStreamError?.('\(escapedError)')")
        } else {
            callJavaScript("window.onStreamComplete?.()")
        }
    }
}

// MARK: - Streaming Delegate

private final class StreamingDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    weak var bridge: WebViewBridge?
    var buffer = ""

    init(bridge: WebViewBridge) {
        self.bridge = bridge
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        buffer += chunk

        var lines = buffer.components(separatedBy: "\n")
        buffer = lines.popLast() ?? ""

        for line in lines {
            guard !line.isEmpty, !line.hasPrefix(": ") else { continue }

            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))
                if jsonString == "[DONE]" { continue }

                guard let jsonData = jsonString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let delta = firstChoice["delta"] as? [String: Any],
                      let content = delta["content"] as? String else {
                    continue
                }

                Task { @MainActor in
                    self.bridge?.sendChunk(content)
                }
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.bridge?.sendComplete(error: error.localizedDescription)
            } else {
                self.bridge?.sendComplete()
            }
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let httpResponse = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            Task { @MainActor in
                self.bridge?.sendComplete(error: "Invalid response")
            }
            return
        }

        if httpResponse.statusCode != 200 {
            completionHandler(.cancel)
            Task { @MainActor in
                self.bridge?.sendComplete(error: "API returned status code \(httpResponse.statusCode)")
            }
            return
        }

        completionHandler(.allow)
    }
}
