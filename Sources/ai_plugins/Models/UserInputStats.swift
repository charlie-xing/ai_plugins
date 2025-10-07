import Foundation

/// 用户输入统计数据
struct UserInputStats: Codable {
    var totalKeystrokes: Int = 0
    var totalAIAccepts: Int = 0
    var sessionStartTime: Date = Date()

    /// 平均输入速度（每分钟按键次数）
    var averageKeystrokesPerMinute: Double {
        let elapsed = Date().timeIntervalSince(sessionStartTime) / 60.0 // 转换为分钟
        guard elapsed > 0 else { return 0 }
        return Double(totalKeystrokes) / elapsed
    }

    /// AI候选词采用率
    var aiAcceptanceRate: Double {
        guard totalKeystrokes > 0 else { return 0 }
        return (Double(totalAIAccepts) / Double(totalKeystrokes)) * 100.0
    }

    mutating func recordKeystroke() {
        totalKeystrokes += 1
    }

    mutating func recordAIAccept() {
        totalAIAccepts += 1
        totalKeystrokes += 1
    }

    mutating func reset() {
        totalKeystrokes = 0
        totalAIAccepts = 0
        sessionStartTime = Date()
    }
}
