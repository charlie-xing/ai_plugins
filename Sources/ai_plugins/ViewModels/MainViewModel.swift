import Foundation
import Combine

@MainActor
class MainViewModel: ObservableObject {
    @Published var plugins: [Plugin] = []
    @Published var selectedPlugin: Plugin?
    @Published var searchText: String = ""
    @Published var openTabs: [TabItem] = []
    @Published var activeTabId: UUID?

    private let pluginManager = PluginManager()
    private var allPlugins: [Plugin] = []
    private var settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    var activeTab: TabItem? {
        openTabs.first { $0.id == activeTabId }
    }

    // Computed property for filtered and sorted plugins
    var filteredPlugins: [Plugin] {
        let filtered: [Plugin]

        if searchText.isEmpty {
            filtered = allPlugins
        } else {
            filtered = allPlugins.filter { plugin in
                plugin.name.localizedCaseInsensitiveContains(searchText) ||
                plugin.description.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort alphabetically by name
        return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

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

        allPlugins = pluginManager.discoverPlugins(in: pluginDirectory)
        plugins = filteredPlugins
        print("Loaded \(allPlugins.count) plugins.")
    }

    func updateFilteredPlugins() {
        plugins = filteredPlugins
    }

    /// Opens a new tab for the given plugin
    func openTab(for plugin: Plugin) {
        print("--- MainViewModel: openTab called for plugin: \(plugin.name) ---")
        print("Before change: openTabs count = \(openTabs.count), activeTabId = \(activeTabId?.uuidString ?? "nil")")

        // Check if tab already exists
        if let existingTab = openTabs.first(where: { $0.plugin.id == plugin.id }) {
            print("Tab already exists. Setting active.")
            activeTabId = existingTab.id
        } else {
            // Create new tab with its own ViewModel
            let newTab = TabItem(plugin: plugin, settings: settings)
            print("Creating new tab with id: \(newTab.id.uuidString)")
            openTabs.append(newTab)
            activeTabId = newTab.id
        }

        // Update window title
        WindowTitleManager.shared.setPluginTitle(plugin.name)
        print("After change: openTabs count = \(openTabs.count), activeTabId = \(activeTabId?.uuidString ?? "nil")")
        print("----------------------------------------------------")
    }

    /// Closes the tab with the given ID
    func closeTab(_ tabId: UUID) {
        print("--- MainViewModel: closeTab called for tabId: \(tabId.uuidString) ---")
        print("Before close: openTabs count = \(openTabs.count), activeTabId = \(activeTabId?.uuidString ?? "nil")")

        guard let index = openTabs.firstIndex(where: { $0.id == tabId }) else {
            print("MainViewModel: Tab not found with id: \(tabId.uuidString)")
            print("----------------------------------------------------")
            return
        }

        print("Closing tab at index \(index), plugin: \(openTabs[index].plugin.name)")
        openTabs.remove(at: index)
        print("Remaining tabs count: \(openTabs.count)")

        // Update active tab if the closed tab was active
        if activeTabId == tabId {
            print("Closed tab was active, updating active tab")
            if let newActiveTab = openTabs.last {
                activeTabId = newActiveTab.id
                selectedPlugin = newActiveTab.plugin
                WindowTitleManager.shared.setPluginTitle(newActiveTab.plugin.name)
                print("New active tab: \(newActiveTab.plugin.name) (\(newActiveTab.id.uuidString))")
            } else {
                print("No tabs remaining, clearing selection")
                activeTabId = nil
                selectedPlugin = nil
                WindowTitleManager.shared.setTitle(section: "plugins")
            }
        } else {
            print("Closed tab was not active, keeping current active tab: \(activeTabId?.uuidString ?? "nil")")
        }
        print("After close: openTabs count = \(openTabs.count), activeTabId = \(activeTabId?.uuidString ?? "nil")")
        print("----------------------------------------------------")
    }
}
