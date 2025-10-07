import Foundation
import SwiftUI

class AppSettings: ObservableObject {
    // 用户设置
    @AppStorage("userName") var userName: String = ""
    @AppStorage("userAvatarPath") var userAvatarPath: String = ""
    @AppStorage("isDarkMode") var isDarkMode: Bool = false

    // 旧的设置（保留兼容性）
    @AppStorage("apiProvider") var apiProvider: String = "OpenRouter.ai"
    @AppStorage("apiBaseURL") var apiBaseURL: String = "https://openrouter.ai/api/v1"
    @AppStorage("apiKey") var apiKey: String = ""
    @AppStorage("defaultModel") var defaultModel: String = "gryphe/mythomax-l2-13b"
    @AppStorage("pluginDirectory") var pluginDirectory: String = ""

    // AI 服务提供商列表
    @Published var aiProviders: [AIProvider] = []
    @Published var activeProviderId: UUID?

    // 输入法设置
    @Published var inputMethodSettings = InputMethodSettings()

    // 模型列表
    @Published var availableModels: [ModelInfo] = []
    @Published var selectedModelId: String?

    // 用户输入统计
    @Published var userInputStats = UserInputStats()

    init() {
        loadProviders()
        loadInputMethodSettings()
        loadModels()
        loadUserInputStats()
    }

    // MARK: - Persistence

    func saveProviders() {
        if let encoded = try? JSONEncoder().encode(aiProviders) {
            UserDefaults.standard.set(encoded, forKey: "aiProviders")
        }
        if let activeId = activeProviderId {
            UserDefaults.standard.set(activeId.uuidString, forKey: "activeProviderId")
        }
    }

    func loadProviders() {
        if let data = UserDefaults.standard.data(forKey: "aiProviders"),
           let decoded = try? JSONDecoder().decode([AIProvider].self, from: data) {
            aiProviders = decoded
        }
        if let idString = UserDefaults.standard.string(forKey: "activeProviderId"),
           let uuid = UUID(uuidString: idString) {
            activeProviderId = uuid
        }
    }

    func saveInputMethodSettings() {
        if let encoded = try? JSONEncoder().encode(inputMethodSettings) {
            UserDefaults.standard.set(encoded, forKey: "inputMethodSettings")
        }
    }

    func loadInputMethodSettings() {
        if let data = UserDefaults.standard.data(forKey: "inputMethodSettings"),
           let decoded = try? JSONDecoder().decode(InputMethodSettings.self, from: data) {
            inputMethodSettings = decoded
        }
    }

    func saveModels() {
        if let encoded = try? JSONEncoder().encode(availableModels) {
            UserDefaults.standard.set(encoded, forKey: "availableModels")
        }
        if let modelId = selectedModelId {
            UserDefaults.standard.set(modelId, forKey: "selectedModelId")
        }
    }

    func loadModels() {
        if let data = UserDefaults.standard.data(forKey: "availableModels"),
           let decoded = try? JSONDecoder().decode([ModelInfo].self, from: data) {
            availableModels = decoded
        }
        selectedModelId = UserDefaults.standard.string(forKey: "selectedModelId")
    }

    func saveUserInputStats() {
        if let encoded = try? JSONEncoder().encode(userInputStats) {
            UserDefaults.standard.set(encoded, forKey: "userInputStats")
        }
    }

    func loadUserInputStats() {
        if let data = UserDefaults.standard.data(forKey: "userInputStats"),
           let decoded = try? JSONDecoder().decode(UserInputStats.self, from: data) {
            userInputStats = decoded
        }
    }
}

enum SidebarSection: String, CaseIterable, Identifiable {
    case plugins
    case history
    case settings

    var id: String { rawValue }

    var localizedName: String {
        NSLocalizedString(rawValue, bundle: .module, comment: "")
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
