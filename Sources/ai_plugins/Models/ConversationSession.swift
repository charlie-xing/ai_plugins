import Foundation

/// 会话模型
struct ConversationSession: Identifiable, Codable {
    let id: UUID
    var pluginId: String
    var pluginName: String
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var messageCount: Int

    init(id: UUID = UUID(), pluginId: String, pluginName: String, title: String, messageCount: Int = 0) {
        self.id = id
        self.pluginId = pluginId
        self.pluginName = pluginName
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.messageCount = messageCount
    }

    /// 获取会话HTML文件路径
    func htmlFilePath() -> URL {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let historyDir = homeDir.appendingPathComponent(".ai_plugins_data/history/sessions")
        return historyDir.appendingPathComponent("\(id.uuidString).html")
    }

    /// 格式化显示时间
    func formattedTime() -> String {
        let now = Date()
        let calendar = Calendar.current

        if calendar.isDateInToday(updatedAt) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: updatedAt)
        } else if calendar.isDateInYesterday(updatedAt) {
            return NSLocalizedString("yesterday", bundle: .module, comment: "")
        } else {
            let days = calendar.dateComponents([.day], from: updatedAt, to: now).day ?? 0
            if days < 7 {
                return String(format: NSLocalizedString("days_ago", bundle: .module, comment: ""), days)
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                return formatter.string(from: updatedAt)
            }
        }
    }
}

/// 会话索引文件结构
struct SessionIndex: Codable {
    var sessions: [ConversationSession]

    init(sessions: [ConversationSession] = []) {
        self.sessions = sessions
    }
}
