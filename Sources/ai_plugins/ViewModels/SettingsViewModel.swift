import Foundation

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    func saveSettings() {
        // TODO: Save settings to UserDefaults or Keychain
    }
}
