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
    let settingsViewModel: SettingsViewModel

    init(settings: AppSettings) {
        self.settingsViewModel = SettingsViewModel(settings: settings)
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
        // Load plugins from app bundle
        // Swift Package Manager creates a .bundle with resources
        let fileManager = FileManager.default

        // First try to find the bundle (for built app)
        if let bundleURL = Bundle.main.url(forResource: "ai_plugins_ai_plugins", withExtension: "bundle"),
           Bundle(url: bundleURL) != nil {
            let pluginDirectory = bundleURL
            allPlugins = pluginManager.discoverPlugins(in: pluginDirectory)
            plugins = filteredPlugins
            print("Loaded \(allPlugins.count) plugins from bundle: \(pluginDirectory.path)")
            return
        }

        // Fallback to old path for backward compatibility (development/testing)
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        let pluginDirectory = homeDirectory.appendingPathComponent("ai_plugins_data/plugins")

        if fileManager.fileExists(atPath: pluginDirectory.path) {
            allPlugins = pluginManager.discoverPlugins(in: pluginDirectory)
            plugins = filteredPlugins
            print("Loaded \(allPlugins.count) plugins from: \(pluginDirectory.path)")
        } else {
            print("Error: No plugin directory found")
        }
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
            let newTab = TabItem(plugin: plugin, settings: settingsViewModel.settings)
            print("Creating new tab with id: \(newTab.id.uuidString)")
            openTabs.append(newTab)
            activeTabId = newTab.id
        }

        // Update window title
        WindowTitleManager.shared.setPluginTitle(plugin.name)
        print("After change: openTabs count = \(openTabs.count), activeTabId = \(activeTabId?.uuidString ?? "nil")")
        print("----------------------------------------------------")
    }

    /// 打开带会话的新标签
    func openPluginInNewTab(_ plugin: Plugin, session: ConversationSession, historyManager: HistoryManager) {
        // 创建新标签
        let newTab = TabItem(plugin: plugin, settings: settingsViewModel.settings)
        openTabs.append(newTab)
        activeTabId = newTab.id
        selectedPlugin = plugin

        // 加载会话到 ViewModel
        newTab.viewModel.loadSession(session, plugin: plugin, historyManager: historyManager)

        WindowTitleManager.shared.setPluginTitle(plugin.name)
        print("MainViewModel: Opened plugin '\(plugin.name)' with session '\(session.title)'")
    }

    /// Closes the tab with the given ID
    func closeTab(_ tabId: UUID, historyManager: HistoryManager? = nil) {
        print("--- MainViewModel: closeTab called for tabId: \(tabId.uuidString) ---")
        print("Before close: openTabs count = \(openTabs.count), activeTabId = \(activeTabId?.uuidString ?? "nil")")

        guard let index = openTabs.firstIndex(where: { $0.id == tabId }) else {
            print("MainViewModel: Tab not found with id: \(tabId.uuidString)")
            print("----------------------------------------------------")
            return
        }

        print("Closing tab at index \(index), plugin: \(openTabs[index].plugin.name)")

        // 保存会话（如果有交互内容）- 保持 tab 引用直到保存完成
        let tab = openTabs[index]

        if let historyManager = historyManager {
            // 先保存，保存完成后再删除标签页
            tab.viewModel.saveCurrentSession(historyManager: historyManager) { [weak self] saved in
                guard let self = self else { return }

                if saved {
                    print("MainViewModel: Session saved for tab: \(tab.plugin.name)")
                }

                // 保存完成后，执行实际的关闭逻辑
                self.performCloseTab(tabId)
            }
        } else {
            // 没有 historyManager，直接关闭
            performCloseTab(tabId)
        }
    }

    /// 实际执行关闭标签页的逻辑
    private func performCloseTab(_ tabId: UUID) {
        guard let index = openTabs.firstIndex(where: { $0.id == tabId }) else {
            print("MainViewModel: Tab not found during performCloseTab")
            return
        }

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
