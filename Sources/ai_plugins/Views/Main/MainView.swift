import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    
    var body: some View {
        NavigationSplitView {
            List(viewModel.plugins, selection: $viewModel.selectedPlugin) { plugin in
                NavigationLink(value: plugin) {
                    VStack(alignment: .leading) {
                        Text(plugin.name).font(.headline)
                        Text(plugin.description).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Plugins")
            .onAppear {
                viewModel.loadPlugins()
            }
        } detail: {
            if let selectedPlugin = viewModel.selectedPlugin {
                PluginDetailView(plugin: selectedPlugin)
            } else {
                Text("Select a plugin to start.")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
            }
        }
    }
}