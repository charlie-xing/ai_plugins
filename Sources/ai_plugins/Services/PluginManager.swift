import Foundation

class PluginManager {

    /// 合并发现动态插件和旧版插件
    /// - Parameter directory: 旧版插件目录 (Resources/plugins)
    /// - Returns: 所有插件的数组
    @MainActor
    func discoverAllPlugins(in directory: URL) -> [Plugin] {
        var allPlugins: [Plugin] = []

        // 1. 从DynamicPluginManager加载新版插件
        let dynamicPlugins = DynamicPluginManager.shared.discoverPlugins()
        for dynamicPlugin in dynamicPlugins {
            let plugin = dynamicPlugin.toLegacyPlugin()
            allPlugins.append(plugin)
        }
        print("PluginManager: Loaded \(dynamicPlugins.count) dynamic plugins")

        // 2. 加载旧版插件（仅从Resources目录）
        let legacyPlugins = discoverLegacyPlugins(in: directory)
        allPlugins.append(contentsOf: legacyPlugins)
        print("PluginManager: Loaded \(legacyPlugins.count) legacy plugins")

        print("PluginManager: Total \(allPlugins.count) plugins available")
        return allPlugins
    }

    /// Scans a given directory for `.js` files and parses their metadata to create Plugin objects.
    /// - Parameter directory: The URL of the directory to scan.
    /// - Returns: An array of `Plugin` objects found in the directory.
    @MainActor
    func discoverPlugins(in directory: URL) -> [Plugin] {
        return discoverAllPlugins(in: directory)
    }

    /// 仅发现旧版插件（用于向后兼容）
    private func discoverLegacyPlugins(in directory: URL) -> [Plugin] {
        var discoveredPlugins: [Plugin] = []
        let fileManager = FileManager.default

        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            for url in fileURLs {
                if url.pathExtension == "js" {
                    if let plugin = parsePlugin(from: url) {
                        discoveredPlugins.append(plugin)
                    }
                }
            }
        } catch {
            print("PluginManager: Error scanning legacy plugin directory: \(error)")
        }

        return discoveredPlugins
    }
    
    /// Parses a single JavaScript file to extract plugin metadata.
    /// - Parameter fileURL: The URL of the `.js` file.
    /// - Returns: A `Plugin` object if metadata is successfully parsed, otherwise `nil`.
    private func parsePlugin(from fileURL: URL) -> Plugin? {
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            
            // Use regex to find metadata in the comment block
            let name = extractMetadata(from: content, key: "name") ?? "Untitled"
            let description = extractMetadata(from: content, key: "description") ?? ""
            let author = extractMetadata(from: content, key: "author") ?? "Unknown"
            let version = extractMetadata(from: content, key: "version") ?? "1.0"
            let entryFunction = extractMetadata(from: content, key: "entryFunction") ?? "runPlugin"
            let modeString = extractMetadata(from: content, key: "mode") ?? "Unknown"
            let mode = PluginMode(rawValue: modeString) ?? .unknown
            
            return Plugin(
                name: name,
                description: description,
                author: author,
                version: version,
                entryFunction: entryFunction,
                mode: mode,
                filePath: fileURL
            )
        } catch {
            print("Error reading plugin file: \(fileURL.lastPathComponent), error: \(error)")
            return nil
        }
    }
    
    /// Extracts a metadata value from the plugin script content using regex.
    /// - Parameters:
    ///   - content: The full string content of the `.js` file.
    ///   - key: The metadata key to look for (e.g., "name", "version").
    /// - Returns: The found value as a String, or `nil` if not found.
    private func extractMetadata(from content: String, key: String) -> String? {
        // Looks for patterns like `* @key value`
        let pattern = "\\*\\s*@\(key)\\s+(.*)"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: content.utf16.count)
        
        if let match = regex?.firstMatch(in: content, options: [], range: range) {
            if let valueRange = Range(match.range(at: 1), in: content) {
                return String(content[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
}