import Foundation

// Represents the metadata of a JavaScript plugin
struct Plugin: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let description: String
    let author: String
    let version: String
    let entryFunction: String
    let mode: PluginMode
    let filePath: URL
    
    // Default initializer
    init(name: String, description: String, author: String, version: String, entryFunction: String, mode: PluginMode, filePath: URL) {
        self.name = name
        self.description = description
        self.author = author
        self.version = version
        self.entryFunction = entryFunction
        self.mode = mode
        self.filePath = filePath
    }
}

enum PluginMode: String, Codable {
    case chat = "Chat"
    case bot = "BOT"
    case agent = "Agent"
    case role = "Role"
    case unknown = "Unknown"
}
