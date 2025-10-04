import SwiftUI

struct PluginDetailView: View {
    let plugin: Plugin
    @StateObject private var viewModel = PluginViewModel()
    
    var body: some View {
        VStack {
            // Header
            VStack(alignment: .leading) {
                Text(plugin.name)
                    .font(.title)
                Text(plugin.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // WebView for output
            WebView(htmlContent: viewModel.webViewContent)
            
            // Input area
            HStack {
                TextField("Enter your prompt here...", text: $viewModel.prompt)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Run") {
                    viewModel.runPlugin(plugin: plugin)
                }
            }
            .padding()
        }
    }
}