import Foundation

/// Represents a tab item for plugin sessions with its own ViewModel
@MainActor
class TabItem: Identifiable, ObservableObject, Equatable {
    let id: UUID
    let plugin: Plugin
    @Published var viewModel: PluginViewModel

    init(plugin: Plugin, settings: AppSettings) {
        let tabId = UUID()
        self.id = tabId
        self.plugin = plugin
        self.viewModel = PluginViewModel(tabId: tabId, settings: settings)
    }

    nonisolated static func == (lhs: TabItem, rhs: TabItem) -> Bool {
        lhs.id == rhs.id
    }
}
