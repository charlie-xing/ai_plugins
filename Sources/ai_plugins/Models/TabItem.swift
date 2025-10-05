import Foundation

/// Represents a tab item for plugin sessions with its own ViewModel
@MainActor
class TabItem: Identifiable, ObservableObject, Equatable {
    let id: UUID
    let plugin: Plugin
    @Published var viewModel: PluginViewModel

    init(plugin: Plugin, settings: AppSettings) {
        self.id = UUID()
        self.plugin = plugin
        self.viewModel = PluginViewModel(settings: settings)
    }

    nonisolated static func == (lhs: TabItem, rhs: TabItem) -> Bool {
        lhs.id == rhs.id
    }
}
