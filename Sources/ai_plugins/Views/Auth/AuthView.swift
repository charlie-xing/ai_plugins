import SwiftUI

struct AuthView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to AI Plugins")
                .font(.largeTitle)
            
            Text("Please configure your AI provider.")
            
            TextField("API Base URL", text: .constant(""))
            TextField("API Key", text: .constant(""))
            
            Button("Save Configuration") {
                // Save logic here
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}
