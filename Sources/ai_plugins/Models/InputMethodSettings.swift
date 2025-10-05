import Foundation

// 皮肤主题
enum SkinTheme: String, Codable, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"

    var id: String { rawValue }
}

// 输入法设置
struct InputMethodSettings: Codable {
    var localModelURL: String
    var modelName: String
    var inputInterval: Int  // 毫秒
    var skinTheme: SkinTheme

    init(localModelURL: String = "http://localhost:8080",
         modelName: String = "rime-input-model",
         inputInterval: Int = 300,
         skinTheme: SkinTheme = .system) {
        self.localModelURL = localModelURL
        self.modelName = modelName
        self.inputInterval = inputInterval
        self.skinTheme = skinTheme
    }
}
