import Foundation
import SwiftUI

class AppSettings: ObservableObject {
    @AppStorage("userName") var userName: String = ""
    @AppStorage("userAvatarPath") var userAvatarPath: String = ""
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    @AppStorage("apiProvider") var apiProvider: String = "OpenRouter.ai"
    @AppStorage("apiBaseURL") var apiBaseURL: String = "https://openrouter.ai/api/v1"
    @AppStorage("apiKey") var apiKey: String = ""
    @AppStorage("defaultModel") var defaultModel: String = "gryphe/mythomax-l2-13b"
    @AppStorage("pluginDirectory") var pluginDirectory: String = ""
}

enum SidebarSection: String, CaseIterable, Identifiable {
    case plugins
    case history
    case settings

    var id: String { rawValue }

    var localizedName: String {
        NSLocalizedString(rawValue, comment: "")
    }

    var icon: String {
        switch self {
        case .plugins:
            return "puzzlepiece.extension.fill"
        case .history:
            return "clock.fill"
        case .settings:
            return "gearshape.fill"
        }
    }
}
