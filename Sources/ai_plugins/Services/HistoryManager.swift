import Foundation

/// 会话历史管理器
@MainActor
class HistoryManager: ObservableObject {
    @Published var sessions: [ConversationSession] = []

    private let indexFileURL: URL
    private let sessionsDirectory: URL

    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let historyDir = homeDir.appendingPathComponent(".ai_plugins_data/history")

        self.indexFileURL = historyDir.appendingPathComponent("sessions.json")
        self.sessionsDirectory = historyDir.appendingPathComponent("sessions")

        // 创建目录
        createDirectoriesIfNeeded()

        // 加载会话
        loadSessions()
    }

    /// 创建必要的目录
    private func createDirectoriesIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
            print("HistoryManager: Created sessions directory at \(sessionsDirectory.path)")
        } catch {
            print("HistoryManager: Error creating directories: \(error)")
        }
    }

    /// 加载所有会话
    func loadSessions() {
        do {
            let data = try Data(contentsOf: indexFileURL)
            let index = try JSONDecoder().decode(SessionIndex.self, from: data)
            self.sessions = index.sessions.sorted { $0.updatedAt > $1.updatedAt }
            print("HistoryManager: Loaded \(sessions.count) sessions")
        } catch {
            print("HistoryManager: No existing sessions or error loading: \(error)")
            self.sessions = []
        }
    }

    /// 保存会话索引
    private func saveIndex() {
        do {
            let index = SessionIndex(sessions: sessions)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(index)
            try data.write(to: indexFileURL)
            print("HistoryManager: Saved sessions index")
        } catch {
            print("HistoryManager: Error saving index: \(error)")
        }
    }

    /// 保存新会话
    func saveSession(_ session: ConversationSession, htmlContent: String) {
        do {
            // 保存 HTML 内容
            try htmlContent.write(to: session.htmlFilePath(), atomically: true, encoding: .utf8)

            // 更新或添加到索引
            if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[index] = session
            } else {
                sessions.insert(session, at: 0)
            }

            // 保存索引
            saveIndex()

            print("HistoryManager: Saved session '\(session.title)'")
        } catch {
            print("HistoryManager: Error saving session: \(error)")
        }
    }

    /// 加载会话的 HTML 内容
    func loadSessionHTML(_ session: ConversationSession) -> String? {
        do {
            let html = try String(contentsOf: session.htmlFilePath(), encoding: .utf8)
            return html
        } catch {
            print("HistoryManager: Error loading session HTML: \(error)")
            return nil
        }
    }

    /// 删除会话
    func deleteSession(_ session: ConversationSession) {
        do {
            // 删除 HTML 文件
            try FileManager.default.removeItem(at: session.htmlFilePath())

            // 从索引中移除
            sessions.removeAll { $0.id == session.id }

            // 保存索引
            saveIndex()

            print("HistoryManager: Deleted session '\(session.title)'")
        } catch {
            print("HistoryManager: Error deleting session: \(error)")
        }
    }

    /// 按插件分组会话
    func sessionsByPlugin() -> [String: [ConversationSession]] {
        Dictionary(grouping: sessions, by: { $0.pluginId })
    }

    /// 获取插件的所有会话
    func sessions(for pluginId: String) -> [ConversationSession] {
        sessions.filter { $0.pluginId == pluginId }
    }

    /// 更新会话
    func updateSession(_ session: ConversationSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
            sessions.sort { $0.updatedAt > $1.updatedAt }
            saveIndex()
        }
    }

    /// 生成默认会话标题
    func generateDefaultTitle(for pluginName: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        let timeString = formatter.string(from: Date())
        return "\(pluginName) - \(timeString)"
    }
}
