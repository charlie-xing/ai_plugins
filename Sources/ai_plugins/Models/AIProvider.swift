import Foundation

// AI 服务提供商类型
enum ProviderType: String, Codable, CaseIterable, Identifiable {
    case openai = "OpenAI"
    case claude = "Claude"
    case gemini = "Gemini"
    case deepseek = "DeepSeek"
    case grok = "Grok"
    case qwen = "Qwen"
    case ollama = "Ollama"
    case openrouter = "OpenRouter"
    case custom = "Custom"

    var id: String { rawValue }

    var defaultEndpoint: String {
        switch self {
        case .openai:
            return "https://api.openai.com/v1"
        case .claude:
            return "https://api.anthropic.com/v1"
        case .gemini:
            return "https://generativelanguage.googleapis.com/v1"
        case .deepseek:
            return "https://api.deepseek.com/v1"
        case .grok:
            return "https://api.x.ai/v1"
        case .qwen:
            return "https://dashscope.aliyuncs.com/api/v1"
        case .ollama:
            return "http://localhost:11434/api"
        case .openrouter:
            return "https://openrouter.ai/api/v1"
        case .custom:
            return ""
        }
    }

    var icon: String {
        switch self {
        case .openai:
            return "cloud.fill"
        case .claude:
            return "brain.head.profile"
        case .gemini:
            return "sparkles"
        case .deepseek:
            return "magnifyingglass"
        case .grok:
            return "bolt.fill"
        case .qwen:
            return "text.bubble.fill"
        case .ollama:
            return "server.rack"
        case .openrouter:
            return "arrow.triangle.2.circlepath"
        case .custom:
            return "gearshape.fill"
        }
    }
}

// AI 服务提供商配置
struct AIProvider: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var providerType: ProviderType
    var apiEndpoint: String
    var apiKey: String
    var isActive: Bool
    var lastTested: Date?
    var isConnected: Bool

    init(id: UUID = UUID(),
         name: String = "",
         providerType: ProviderType = .openai,
         apiEndpoint: String = "",
         apiKey: String = "",
         isActive: Bool = false,
         lastTested: Date? = nil,
         isConnected: Bool = false) {
        self.id = id
        self.name = name
        self.providerType = providerType
        self.apiEndpoint = apiEndpoint.isEmpty ? providerType.defaultEndpoint : apiEndpoint
        self.apiKey = apiKey
        self.isActive = isActive
        self.lastTested = lastTested
        self.isConnected = isConnected
    }
}
