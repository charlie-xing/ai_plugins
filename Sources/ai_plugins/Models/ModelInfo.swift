import Foundation

// 模型信息
struct ModelInfo: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var providerId: UUID
    var description: String?
    var contextWindow: Int?
    var isDefault: Bool

    init(id: String,
         name: String,
         providerId: UUID,
         description: String? = nil,
         contextWindow: Int? = nil,
         isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.providerId = providerId
        self.description = description
        self.contextWindow = contextWindow
        self.isDefault = isDefault
    }
}
