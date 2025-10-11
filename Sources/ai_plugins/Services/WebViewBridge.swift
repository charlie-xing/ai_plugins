import AppKit
import Foundation
import WebKit

/// Bridge between WKWebView JavaScript and Swift
/// Replaces JSCore-based JSBridge with a simpler WKWebView-only approach
class WebViewBridge: NSObject, WKScriptMessageHandler, @unchecked Sendable {

    let tabId: UUID
    weak var webView: WKWebView?
    var settings: AppSettings?

    init(tabId: UUID, settings: AppSettings?) {
        self.tabId = tabId
        self.settings = settings
        super.init()
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(
        _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any],
            let action = body["action"] as? String
        else {
            print("WebViewBridge: Invalid message format")
            return
        }

        print("WebViewBridge [\(tabId.uuidString.prefix(4))]: Received action: \(action)")

        switch action {
        case "consoleLog":
            // Handle JavaScript console.log output
            if let level = body["level"] as? String,
               let message = body["message"] as? String {
                print("[JS Console.\(level)]: \(message)")
            }

        case "log":
            if let logMessage = body["message"] as? String {
                print("[Plugin Log]: \(logMessage)")
            }

        case "callAIStream":
            // Handle both current message and conversation history
            let messages = body["messages"] as? [[String: Any]] ?? []
            let currentMessage = body["message"] as? String
            handleStreamRequest(messages: messages, currentMessage: currentMessage)

        case "getSettings":
            handleGetSettings()

        case "executeCode":
            if let command = body["command"] as? String,
                let args = body["args"] as? [String],
                let callbackId = body["callbackId"] as? String
            {
                handleExecuteCode(command: command, args: args, callbackId: callbackId)
            }

        case "runPythonScript":
            if let scriptName = body["script"] as? String,
                let input = body["input"] as? String
            {
                handleRunPythonScript(scriptName: scriptName, input: input)
            }

        default:
            print("WebViewBridge: Unknown action: \(action)")
        }
    }

    // MARK: - Handler Methods

    private func handleRunPythonScript(scriptName: String, input: String) {
        print("WebViewBridge: Running Python script: \(scriptName)")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Get the script path from the Resources directory
            // Try module bundle first (for SPM), then main bundle
            var scriptPath: String?
            if let modulePath = Bundle.module.path(forResource: scriptName.replacingOccurrences(of: ".py", with: ""), ofType: "py") {
                scriptPath = modulePath
            } else if let mainPath = Bundle.main.path(forResource: scriptName.replacingOccurrences(of: ".py", with: ""), ofType: "py") {
                scriptPath = mainPath
            }

            guard let scriptPath = scriptPath else {
                print("WebViewBridge: Python script not found: \(scriptName)")
                let errorScript = "window.onPythonScriptError?.('Script not found: \(scriptName)')"
                DispatchQueue.main.async {
                    self.callJavaScript(errorScript)
                }
                return
            }

            print("WebViewBridge: Script path: \(scriptPath)")
            print("WebViewBridge: Input JSON length: \(input.count) characters")
            print("WebViewBridge: Input JSON preview: \(String(input.prefix(200)))...")

            let process = Process()

            // Try to use venv python if available, otherwise fall back to system python
            let venvPython = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("rime/ai_plugins/venv/bin/python3")
            let pythonPath = FileManager.default.fileExists(atPath: venvPython.path)
                ? venvPython.path
                : "/usr/bin/python3"

            print("WebViewBridge: Using Python at: \(pythonPath)")
            process.executableURL = URL(fileURLWithPath: pythonPath)
            process.arguments = [scriptPath]

            let inputPipe = Pipe()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.standardInput = inputPipe
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            // Write JSON input to stdin
            if let inputData = input.data(using: .utf8) {
                print("WebViewBridge: Writing \(inputData.count) bytes to Python stdin")
                inputPipe.fileHandleForWriting.write(inputData)
                inputPipe.fileHandleForWriting.closeFile()
                print("WebViewBridge: Input pipe closed")
            } else {
                print("WebViewBridge: ERROR - Failed to convert input to UTF8 data")
            }

            // Read output line by line for progress updates
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.count > 0, let output = String(data: data, encoding: .utf8) {
                    // Split by newlines and process each line
                    let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
                    for line in lines {
                        print("WebViewBridge: Python output: \(line)")
                        // Escape the output for JavaScript
                        let escapedOutput = line
                            .replacingOccurrences(of: "\\", with: "\\\\")
                            .replacingOccurrences(of: "'", with: "\\'")
                            .replacingOccurrences(of: "\n", with: "\\n")
                            .replacingOccurrences(of: "\r", with: "\\r")
                        let script = "window.onPythonScriptOutput?.('\(escapedOutput)')"
                        DispatchQueue.main.async {
                            self.callJavaScript(script)
                        }
                    }
                }
            }

            do {
                print("WebViewBridge: Starting Python process with arguments: \(process.arguments ?? [])")
                try process.run()

                print("WebViewBridge: Python process started, PID: \(process.processIdentifier)")
                process.waitUntilExit()

                // Read all error output
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

                print("WebViewBridge: Python process terminated with status: \(process.terminationStatus)")

                if !errorOutput.isEmpty {
                    print("WebViewBridge: Python stderr output:")
                    print("--- START STDERR ---")
                    print(errorOutput)
                    print("--- END STDERR ---")
                }

                if process.terminationStatus != 0 {
                    print("WebViewBridge: Python script FAILED with exit code: \(process.terminationStatus)")

                    var errorMessage = errorOutput
                    if errorMessage.isEmpty {
                        errorMessage = "Python script failed with exit code \(process.terminationStatus)"
                    }

                    let escapedError = errorMessage
                        .replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "'", with: "\\'")
                        .replacingOccurrences(of: "\n", with: "\\n")
                    let errorScript = "window.onPythonScriptError?.('\(escapedError)')"
                    DispatchQueue.main.async {
                        self.callJavaScript(errorScript)
                    }
                } else {
                    print("WebViewBridge: Python script completed successfully (exit code 0)")
                }
            } catch {
                print("WebViewBridge: EXCEPTION when running Python script: \(error)")
                print("WebViewBridge: Error description: \(error.localizedDescription)")
                let errorScript = "window.onPythonScriptError?.('Failed to execute: \(error.localizedDescription)')"
                DispatchQueue.main.async {
                    self.callJavaScript(errorScript)
                }
            }
        }
    }

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
                        self?.callExecuteCallback(
                            callbackId: callbackId, success: true, output: output)
                    } else {
                        let errorMessage = error.isEmpty ? "Exit code: \(exitCode)" : error
                        self?.callExecuteCallback(
                            callbackId: callbackId, success: false, output: errorMessage)
                    }
                }
            } catch {
                Task { @MainActor in
                    self?.callExecuteCallback(
                        callbackId: callbackId, success: false, output: error.localizedDescription)
                }
            }
        }
    }

    private func callExecuteCallback(callbackId: String, success: Bool, output: String) {
        let escapedOutput =
            output
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

    private func handleStreamRequest(messages: [[String: Any]], currentMessage: String?) {
        guard let settings = settings,
            let activeProvider = settings.aiProviders.first(where: {
                $0.id == settings.activeProviderId
            }),
            let selectedModel = settings.availableModels.first(where: {
                $0.id == settings.selectedModelId
            })
        else {
            callJavaScript(
                "window.onStreamError?.('Please configure AI provider and select a model in Settings first.')"
            )
            return
        }

        let endpoint = "\(activeProvider.apiEndpoint)/chat/completions"
        guard let url = URL(string: endpoint) else {
            callJavaScript("window.onStreamError?.('Invalid API endpoint')")
            return
        }

        // Build final messages array including current message (which may be RAG-enhanced)
        var finalMessages = messages
        if let currentMessage = currentMessage, !currentMessage.isEmpty {
            finalMessages.append(["role": "user", "content": currentMessage])

            // Log RAG enhancement info
            if currentMessage.contains("Based on the following relevant information") {
                print("WebViewBridge: Using RAG-enhanced prompt (length: \(currentMessage.count))")
                print(
                    "WebViewBridge: Enhanced prompt preview: \(String(currentMessage.prefix(200)))..."
                )
            } else {
                print("WebViewBridge: Using original prompt (length: \(currentMessage.count))")
            }
        }

        print(
            "WebViewBridge: Starting stream to \(endpoint) with \(finalMessages.count) total messages (\(messages.count) history + current)"
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(activeProvider.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        let requestBody: [String: Any] = [
            "model": selectedModel.id,
            "messages": finalMessages,  // Use full conversation history + current message
            "temperature": 0.7,
            "max_tokens": 2000,
            "stream": true,
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

            let delegate = StreamingDelegate(bridge: self)
            let session = URLSession(
                configuration: .default, delegate: delegate, delegateQueue: nil)
            session.dataTask(with: request).resume()

        } catch {
            callJavaScript("window.onStreamError?.('\(error.localizedDescription)')")
        }
    }

    private func handleGetSettings() {
        guard let settings = settings,
            let activeProvider = settings.aiProviders.first(where: {
                $0.id == settings.activeProviderId
            }),
            let selectedModel = settings.availableModels.first(where: {
                $0.id == settings.selectedModelId
            })
        else {
            callJavaScript("window.onSettings?.({})")
            return
        }

        // Convert avatar image to data URL if it's a file path
        var avatarValue = "👤"
        if !settings.userAvatarPath.isEmpty {
            if let image = NSImage(contentsOfFile: settings.userAvatarPath),
                let tiffData = image.tiffRepresentation,
                let bitmapImage = NSBitmapImageRep(data: tiffData),
                let pngData = bitmapImage.representation(using: .png, properties: [:])
            {
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
            "userAvatar": avatarValue,
        ]

        print("WebViewBridge: Sending settings to JS - userName: \(settings.userName)")

        if let jsonData = try? JSONSerialization.data(withJSONObject: settingsDict),
            let jsonString = String(data: jsonData, encoding: .utf8)
        {
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
        let escapedChunk =
            chunk
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")

        callJavaScript("window.onStreamChunk?.('\(escapedChunk)')")
    }

    func sendComplete(error: String? = nil) {
        if let error = error {
            let escapedError =
                error
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
        print("StreamingDelegate: Received \(data.count) bytes")
        guard let chunk = String(data: data, encoding: .utf8) else {
            print("StreamingDelegate: Failed to decode data as UTF-8")
            return
        }
        buffer += chunk
        print("StreamingDelegate: Buffer size: \(buffer.count) characters")

        var lines = buffer.components(separatedBy: "\n")
        buffer = lines.popLast() ?? ""

        print("StreamingDelegate: Processing \(lines.count) lines")
        for line in lines {
            guard !line.isEmpty, !line.hasPrefix(": ") else { continue }

            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))
                if jsonString == "[DONE]" {
                    print("StreamingDelegate: Received [DONE] signal")
                    continue
                }

                print("StreamingDelegate: Parsing JSON: \(jsonString.prefix(100))...")
                guard let jsonData = jsonString.data(using: .utf8),
                    let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                    let choices = json["choices"] as? [[String: Any]],
                    let firstChoice = choices.first,
                    let delta = firstChoice["delta"] as? [String: Any],
                    let content = delta["content"] as? String
                else {
                    print("StreamingDelegate: Failed to parse JSON or extract content")
                    continue
                }

                print("StreamingDelegate: Extracted content: \(content)")
                Task { @MainActor in
                    self.bridge?.sendChunk(content)
                }
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
    {
        print("StreamingDelegate: Request completed")
        Task { @MainActor in
            if let error = error {
                print("StreamingDelegate: Completed with error: \(error.localizedDescription)")
                self.bridge?.sendComplete(error: error.localizedDescription)
            } else {
                print("StreamingDelegate: Completed successfully")
                self.bridge?.sendComplete()
            }
        }
    }

    func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        print("StreamingDelegate: Received response")
        guard let httpResponse = response as? HTTPURLResponse else {
            print("StreamingDelegate: Invalid response type")
            completionHandler(.cancel)
            Task { @MainActor in
                self.bridge?.sendComplete(error: "Invalid response")
            }
            return
        }

        print("StreamingDelegate: HTTP status code: \(httpResponse.statusCode)")
        if httpResponse.statusCode != 200 {
            print("StreamingDelegate: Non-200 status code, cancelling")
            completionHandler(.cancel)
            Task { @MainActor in
                self.bridge?.sendComplete(
                    error: "API returned status code \(httpResponse.statusCode)")
            }
            return
        }

        print("StreamingDelegate: Response OK, allowing data")
        completionHandler(.allow)
    }
}
