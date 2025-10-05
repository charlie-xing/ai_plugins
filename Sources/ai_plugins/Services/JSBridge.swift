import Foundation
@preconcurrency import JavaScriptCore

struct JSResult: Decodable {
    let content: String
    let type: String
    let replace: Bool
}

// Helper classes to store results from async tasks
private class ResultBox: @unchecked Sendable {
    var value: String = ""
}

private class ErrorBox: @unchecked Sendable {
    var value: Error?
}

class JSBridge {
    private var context = JSContext()
    private var settings: AppSettings?
    private var loadedPlugins: Set<String> = []  // Track which plugins have been loaded
    private let tabId: UUID

    init(tabId: UUID, settings: AppSettings? = nil) {
        self.tabId = tabId
        self.settings = settings
        setupBridgedFunctions()
    }

    /// Executes a function from a JavaScript plugin file.
    /// - Parameters:
    ///   - plugin: The `Plugin` object containing file path and metadata.
    ///   - args: An array of arguments to pass to the JS function.
    /// - Returns: The value returned by the JavaScript function, or `nil` on error.
    func runPlugin(plugin: Plugin, args: [Any]) -> JSValue? {
        do {
            let pluginKey = plugin.filePath.path

            // Only load the script if it hasn't been loaded yet
            if !loadedPlugins.contains(pluginKey) {
                print("JSBridge: Loading plugin from: \(plugin.filePath.path)")
                let script = try String(contentsOf: plugin.filePath, encoding: .utf8)
                print("JSBridge: Script loaded, length: \(script.count)")

                context?.evaluateScript(script)

                if let exception = context?.exception {
                    print("JSBridge: Exception during script evaluation: \(exception)")
                    return nil
                }

                loadedPlugins.insert(pluginKey)
                print("JSBridge: Plugin loaded and cached")
            } else {
                print("JSBridge: Using cached plugin")
            }

            let functionName = plugin.entryFunction
            print("JSBridge: Looking for entry function: '\(functionName)'")

            guard let pluginFunction = context?.objectForKeyedSubscript(functionName) else {
                print("JSBridge: Error - Entry function '\(functionName)' not found in plugin '\(plugin.name)'.")
                return nil
            }

            print("JSBridge: Found function, calling with args: \(args)")
            let result = pluginFunction.call(withArguments: args)

            if let exception = context?.exception {
                print("JSBridge: Exception during function call: \(exception)")
                return nil
            }

            print("JSBridge: Function returned successfully")
            return result
        } catch {
            print("JSBridge: Error reading or executing plugin script: \(error)")
            return nil
        }
    }
    
    /// Sets up functions that JavaScript plugins can call back into Swift.
    func setupBridgedFunctions() {
        let log: @convention(block) (String) -> Void = { message in
            print("[Plugin Log]: \(message)")
        }
        context?.setObject(log, forKeyedSubscript: "log" as NSString)

        // Expose synchronous callAISync function to JavaScript
        let callAISync: @convention(block) (String) -> String = { [weak self] userMessage in
            guard let self = self else {
                return "Error: Bridge not available"
            }

            guard let settings = self.settings,
                  let activeProvider = settings.aiProviders.first(where: { $0.id == settings.activeProviderId }),
                  let selectedModel = settings.availableModels.first(where: { $0.id == settings.selectedModelId }) else {
                return "Error: Please configure AI provider and select a model in Settings first."
            }

            let endpoint = "\(activeProvider.apiEndpoint)/chat/completions"
            guard let url = URL(string: endpoint) else {
                return "Error: Invalid API endpoint: \(endpoint)"
            }

            print("JSBridge: Calling AI API at: \(endpoint)")
            print("JSBridge: Using model: \(selectedModel.id)")
            print("JSBridge: Provider: \(activeProvider.name)")

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(activeProvider.apiKey)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 120  // Increased to 60 seconds

            let requestBody: [String: Any] = [
                "model": selectedModel.id,
                "messages": [
                    ["role": "user", "content": userMessage]
                ],
                "temperature": 0.7,
                "max_tokens": 2000
            ]

            print("JSBridge: Request body: \(requestBody)")

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

                let semaphore = DispatchSemaphore(value: 0)
                let resultBox = ResultBox()
                resultBox.value = "Error: Request failed"

                URLSession.shared.dataTask(with: request) { data, response, error in
                    defer { semaphore.signal() }

                    if let error = error {
                        resultBox.value = "Error: \(error.localizedDescription)"
                        return
                    }

                    guard let data = data,
                          let httpResponse = response as? HTTPURLResponse else {
                        resultBox.value = "Error: Invalid response from server"
                        return
                    }

                    guard httpResponse.statusCode == 200 else {
                        // Try to get error message from response
                        var errorMessage = "Error: API returned status code \(httpResponse.statusCode)"
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let error = json["error"] as? [String: Any],
                           let message = error["message"] as? String {
                            errorMessage += " - \(message)"
                        } else if let errorText = String(data: data, encoding: .utf8) {
                            errorMessage += " - \(errorText)"
                        }

                        // Add helpful message for common status codes
                        switch httpResponse.statusCode {
                        case 401:
                            errorMessage += "\n\nPlease check your API key in Settings."
                        case 402:
                            errorMessage += "\n\nYour API account may need payment or has insufficient credits."
                        case 429:
                            errorMessage += "\n\nRate limit exceeded. Please wait and try again."
                        case 500...599:
                            errorMessage += "\n\nServer error. Please try again later."
                        default:
                            break
                        }

                        resultBox.value = errorMessage
                        return
                    }

                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let choices = json["choices"] as? [[String: Any]],
                           let firstChoice = choices.first,
                           let message = firstChoice["message"] as? [String: Any],
                           let content = message["content"] as? String {
                            resultBox.value = content
                        } else {
                            resultBox.value = "Error: Invalid response format from API"
                        }
                    } catch {
                        resultBox.value = "Error: Failed to parse response - \(error.localizedDescription)"
                    }
                }.resume()

                semaphore.wait()
                return resultBox.value

            } catch {
                return "Error: Failed to prepare request - \(error.localizedDescription)"
            }
        }
        context?.setObject(callAISync, forKeyedSubscript: "callAISync" as NSString)

        // Expose streaming callAIStream function to JavaScript
        let callAIStream: @convention(block) (String, JSValue, JSValue) -> Void = { [weak self] userMessage, onChunk, onComplete in
            print("JSBridge: callAIStream called with message: '\(userMessage)'")
            guard let self = self else {
                print("JSBridge: self is nil, returning error")
                onComplete.call(withArguments: ["Error: Bridge not available"])
                return
            }

            // Capture values locally before async dispatch to avoid Sendable warnings
            let settings = self.settings
            print("JSBridge: Starting background task for streaming")

            // Call the non-isolated method directly to handle the async work
            self.callAIStreamAPINonIsolated(
                userMessage: userMessage,
                settings: settings,
                onChunk: onChunk,
                onComplete: onComplete
            )
        }
        context?.setObject(callAIStream, forKeyedSubscript: "callAIStream" as NSString)

        // Expose getSettings function to JavaScript
        let getSettings: @convention(block) () -> [String: Any] = { [weak self] in
            guard let self = self,
                  let settings = self.settings,
                  let activeProvider = settings.aiProviders.first(where: { $0.id == settings.activeProviderId }),
                  let selectedModel = settings.availableModels.first(where: { $0.id == settings.selectedModelId }) else {
                return [:]
            }

            return [
                "apiEndpoint": activeProvider.apiEndpoint,
                "apiKey": activeProvider.apiKey,
                "selectedModel": selectedModel.id,
                "userName": settings.userName.isEmpty ? "User" : settings.userName,
                "userAvatar": "👤"
            ]
        }
        context?.setObject(getSettings, forKeyedSubscript: "getSettings" as NSString)

        // Expose updateUI function to JavaScript to trigger UI refresh
        let updateUI: @convention(block) (String) -> Void = { [weak self] htmlContent in
            guard let self = self else { return }

            print("JSBridge [\(self.tabId.uuidString.prefix(4))]: updateUI called with HTML, length: \(htmlContent.count)")

            // Capture tabId locally to avoid data race when sending to main actor
            let currentTabId = self.tabId

            // Post notification on main thread with the tabId
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("PluginUIUpdate"),
                    object: nil,
                    userInfo: [
                        "htmlContent": htmlContent,
                        "tabId": currentTabId
                    ]
                )
            }
        }
        context?.setObject(updateUI, forKeyedSubscript: "updateUI" as NSString)
    }

    /// Call AI API with streaming support (non-isolated version for background execution)
    private func callAIStreamAPINonIsolated(userMessage: String, settings: AppSettings?, onChunk: JSValue, onComplete: JSValue) {
        // Extract settings data before async dispatch to avoid Sendable warnings
        guard let settings = settings,
              let activeProvider = settings.aiProviders.first(where: { $0.id == settings.activeProviderId }),
              let selectedModel = settings.availableModels.first(where: { $0.id == settings.selectedModelId }) else {
            onComplete.call(withArguments: ["Error: Please configure AI provider and select a model in Settings first."])
            return
        }

        let endpoint = "\(activeProvider.apiEndpoint)/chat/completions"
        let apiKey = activeProvider.apiKey
        let modelId = selectedModel.id

        // Dispatch to background queue with captured immutable values
        DispatchQueue.global(qos: .userInitiated).async {
            guard let url = URL(string: endpoint) else {
                onComplete.call(withArguments: ["Error: Invalid API endpoint: \(endpoint)"])
                return
            }

            print("JSBridge: Starting streaming AI API call at: \(endpoint)")
            print("JSBridge: Using model: \(modelId)")

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 120

            let requestBody: [String: Any] = [
                "model": modelId,
                "messages": [
                    ["role": "user", "content": userMessage]
                ],
                "temperature": 0.7,
                "max_tokens": 2000,
                "stream": true  // Enable streaming
            ]

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

                let semaphore = DispatchSemaphore(value: 0)
                let errorBox = ErrorBox()

                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                defer { semaphore.signal() }

                if let error = error {
                    errorBox.value = error
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    onComplete.call(withArguments: ["Error: Invalid response from server"])
                    return
                }

                guard httpResponse.statusCode == 200 else {
                    var errorMessage = "Error: API returned status code \(httpResponse.statusCode)"
                    if let data = data, let errorText = String(data: data, encoding: .utf8) {
                        errorMessage += "\n\(errorText)"
                    }
                    onComplete.call(withArguments: [errorMessage])
                    return
                }

                guard let data = data,
                      let text = String(data: data, encoding: .utf8) else {
                    onComplete.call(withArguments: ["Error: Failed to read response"])
                    return
                }

                // Process streaming response line by line
                let lines = text.components(separatedBy: "\n")
                var fullContent = ""

                for line in lines {
                    guard !line.isEmpty, line.hasPrefix("data: ") else { continue }
                    let jsonString = String(line.dropFirst(6))

                    if jsonString == "[DONE]" { break }

                    guard let jsonData = jsonString.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                          let choices = json["choices"] as? [[String: Any]],
                          let firstChoice = choices.first,
                          let delta = firstChoice["delta"] as? [String: Any],
                          let content = delta["content"] as? String else {
                        continue
                    }

                    fullContent += content
                    onChunk.call(withArguments: [content])
                }

                print("JSBridge: Stream completed, total content length: \(fullContent.count)")
                onComplete.call(withArguments: [])
            }

            task.resume()
            semaphore.wait()

                if let error = errorBox.value {
                    print("JSBridge: Stream error: \(error)")
                    onComplete.call(withArguments: ["Error: \(error.localizedDescription)"])
                }

            } catch {
                print("JSBridge: Stream setup error: \(error)")
                onComplete.call(withArguments: ["Error: \(error.localizedDescription)"])
            }
        }
    }

}
