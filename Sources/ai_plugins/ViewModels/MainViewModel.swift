import Foundation
import Combine

@MainActor
class MainViewModel: ObservableObject {
    @Published var plugins: [Plugin] = []
    @Published var selectedPlugin: Plugin?
    
    private let pluginManager = PluginManager()
    
    // The init is now empty. Data loading is deferred to the View's onAppear.
    init() {}
    
    func loadPlugins() {
        // In a real app, this path would come from AppSettings
        let fileManager = FileManager.default
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        let pluginDirectory = homeDirectory.appendingPathComponent("ai_plugins_data/plugins")
        
        // Create the directory if it doesn't exist
        if !fileManager.fileExists(atPath: pluginDirectory.path) {
            do {
                try fileManager.createDirectory(at: pluginDirectory, withIntermediateDirectories: true, attributes: nil)
                print("Created plugin directory at: \(pluginDirectory.path)")
            } catch {
                print("Error creating plugin directory: \(error)")
                return
            }
        }
        
        self.plugins = pluginManager.discoverPlugins(in: pluginDirectory)
        print("Loaded \(plugins.count) plugins.")
    }
}
