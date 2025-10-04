import Foundation

// For OpenAI compatible API requests and responses
struct AIRequest: Codable {
    let model: String
    let messages: [AIMessage]
}

struct AIMessage: Codable {
    let role: String
    let content: String
}

struct AIResponse: Codable {
    let choices: [AIChoice]
}

struct AIChoice: Codable {
    let message: AIMessage
}
