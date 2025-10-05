import AppKit
import Foundation

/// Manages window title updates with localization support
@MainActor
class WindowTitleManager {
    static let shared = WindowTitleManager()

    private init() {}

    /// Sets the window title with localized section and subsection
    /// - Parameters:
    ///   - section: The main section key (e.g., "plugins", "settings")
    ///   - subsection: Optional subsection (e.g., plugin name, setting name)
    func setTitle(section: String, subsection: String? = nil) {
        guard let window = NSApplication.shared.windows.first else { return }

        let localizedSection = NSLocalizedString(section, comment: "")
        let separator = NSLocalizedString("title_separator", comment: "")

        if let subsection = subsection {
            window.title = "\(localizedSection) \(separator) \(subsection)"
        } else {
            window.title = localizedSection
        }
    }

    /// Sets the window title for a plugin
    /// - Parameter pluginName: The name of the plugin
    func setPluginTitle(_ pluginName: String) {
        setTitle(section: "plugins", subsection: pluginName)
    }

    /// Sets the window title for a settings section
    /// - Parameter settingKey: The localization key for the setting
    func setSettingsTitle(_ settingKey: String) {
        let localizedSetting = NSLocalizedString(settingKey, comment: "")
        setTitle(section: "settings", subsection: localizedSetting)
    }
}
