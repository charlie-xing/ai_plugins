import Foundation

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var settings = AppSettings()
    
    func saveSettings() {
        // TODO: Save settings to UserDefaults or Keychain
    }
}
