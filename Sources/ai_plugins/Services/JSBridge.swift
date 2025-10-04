import Foundation
import JavaScriptCore

struct JSResult: Decodable {
    let content: String
    let type: String
    let replace: Bool
}

class JSBridge {
    private var context = JSContext()

    init() {
        setupBridgedFunctions()
    }

    /// Executes a function from a JavaScript plugin file.
    /// - Parameters:
    ///   - plugin: The `Plugin` object containing file path and metadata.
    ///   - args: An array of arguments to pass to the JS function.
    /// - Returns: The value returned by the JavaScript function, or `nil` on error.
    func runPlugin(plugin: Plugin, args: [Any]) -> JSValue? {
        do {
            let script = try String(contentsOf: plugin.filePath, encoding: .utf8)
            context?.evaluateScript(script)
            
            let functionName = plugin.entryFunction
            guard let pluginFunction = context?.objectForKeyedSubscript(functionName) else {
                print("Error: Entry function '\(functionName)' not found in plugin '\(plugin.name)'.")
                return nil
            }
            
            return pluginFunction.call(withArguments: args)
        } catch {
            print("Error reading or executing plugin script: \(error)")
            return nil
        }
    }
    
    /// Sets up functions that JavaScript plugins can call back into Swift.
    func setupBridgedFunctions() {
        let log: @convention(block) (String) -> Void = { message in
            print("[Plugin Log]: \(message)")
        }
        context?.setObject(log, forKeyedSubscript: "log" as NSString)
        
        // TODO: Expose `fetchAIResult` and `getConfiguration` here.
    }
}