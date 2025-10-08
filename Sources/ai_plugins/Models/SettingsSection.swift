import Foundation

// 设置分类
enum SettingsSection: String, CaseIterable, Identifiable {
    case aiProvider = "AI Service Provider"
    case inputMethod = "Input Method"
    case modelSelection = "Model Selection"
    case knowledgeBase = "Knowledge Base"
    case embeddingService = "Embedding Service"
    case ragConfiguration = "RAG Configuration"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .aiProvider:
            return "key.fill"
        case .inputMethod:
            return "keyboard.fill"
        case .modelSelection:
            return "cpu.fill"
        case .knowledgeBase:
            return "book.fill"
        case .embeddingService:
            return "brain.head.profile"
        case .ragConfiguration:
            return "brain.head.profile.fill"
        }
    }

    var localizedNameKey: String {
        switch self {
        case .aiProvider:
            return "ai_provider"
        case .inputMethod:
            return "input_method"
        case .modelSelection:
            return "model_selection"
        case .knowledgeBase:
            return "knowledge_base"
        case .embeddingService:
            return "embedding_service"
        case .ragConfiguration:
            return "rag_configuration"
        }
    }
}
