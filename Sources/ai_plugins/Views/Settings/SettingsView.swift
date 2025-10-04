import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section(header: Text("API Configuration")) {
                TextField("Provider", text: .constant("OpenRouter.ai"))
                TextField("API Base URL", text: .constant("https://openrouter.ai/api/v1"))
                SecureField("API Key", text: .constant("..."))
            }
            
            Section(header: Text("Model")) {
                Picker("Default Model", selection: .constant("default")) {
                    Text("gryphe/mythomax-l2-13b").tag("default")
                }
            }
        }
        .padding()
        .navigationTitle("Settings")
    }
}
