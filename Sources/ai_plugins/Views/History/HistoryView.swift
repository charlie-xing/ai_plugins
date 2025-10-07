import SwiftUI

struct HistoryView: View {
    @ObservedObject var historyManager: HistoryManager
    let onSessionSelect: (ConversationSession) -> Void

    @State private var expandedPluginIds: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            if historyManager.sessions.isEmpty {
                emptyStateView
            } else {
                sessionListView
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text(NSLocalizedString("no_history", bundle: .module, comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Session List

    @ViewBuilder
    private var sessionListView: some View {
        ScrollView {
            LazyVStack(spacing: 4, pinnedViews: []) {
                ForEach(groupedSessions.sorted(by: { $0.key < $1.key }), id: \.key) { pluginName, sessions in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedPluginIds.contains(getPluginId(from: sessions)) },
                            set: { isExpanded in
                                let pluginId = getPluginId(from: sessions)
                                if isExpanded {
                                    expandedPluginIds.insert(pluginId)
                                } else {
                                    expandedPluginIds.remove(pluginId)
                                }
                            }
                        )
                    ) {
                        // Session items under this plugin
                        ForEach(sessions.sorted(by: { $0.updatedAt > $1.updatedAt })) { session in
                            sessionRow(session: session)
                        }
                    } label: {
                        pluginGroupHeader(pluginName: pluginName, sessionCount: sessions.count)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Plugin Group Header

    @ViewBuilder
    private func pluginGroupHeader(pluginName: String, sessionCount: Int) -> some View {
        HStack(spacing: 8) {
            // 使用首字母作为图标（透明背景）
            Text(getInitial(from: pluginName))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.accentColor)
                .frame(width: 20)

            Text(cleanPluginName(pluginName))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            Text("\(sessionCount)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                )
        }
        .padding(.vertical, 4)
    }

    // MARK: - Session Row

    @ViewBuilder
    private func sessionRow(session: ConversationSession) -> some View {
        Button(action: {
            onSessionSelect(session)
        }) {
            HStack(spacing: 8) {
                // Indent indicator
                Rectangle()
                    .fill(Color.accentColor.opacity(0.3))
                    .frame(width: 2, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text(session.formattedTime())
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)

                        if session.messageCount > 0 {
                            Text("•")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)

                            Text("\(session.messageCount) \(NSLocalizedString("messages", bundle: .module, comment: ""))")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()
            }
            .padding(.leading, 12)
            .padding(.vertical, 6)
            .background(Color.clear)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: {
                deleteSession(session)
            }) {
                Label(NSLocalizedString("delete_session", bundle: .module, comment: ""), systemImage: "trash")
            }
        }
    }

    // MARK: - Computed Properties

    private var groupedSessions: [String: [ConversationSession]] {
        Dictionary(grouping: historyManager.sessions, by: { $0.pluginName })
    }

    // MARK: - Helper Methods

    private func getPluginId(from sessions: [ConversationSession]) -> String {
        sessions.first?.pluginId ?? ""
    }

    private func deleteSession(_ session: ConversationSession) {
        historyManager.deleteSession(session)
    }

    /// 清理插件名称，移除 "(WKWebView)" 等后缀
    private func cleanPluginName(_ name: String) -> String {
        let suffixesToRemove = ["(WKWebView)", "(WebView)"]
        var cleaned = name.trimmingCharacters(in: .whitespaces)

        for suffix in suffixesToRemove {
            if cleaned.hasSuffix(suffix) {
                cleaned = cleaned.replacingOccurrences(of: suffix, with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }

        return cleaned
    }

    /// 获取插件名称的首字母
    private func getInitial(from name: String) -> String {
        let cleaned = cleanPluginName(name)

        // 尝试获取第一个字符
        if let firstChar = cleaned.first {
            // 如果是中文，返回第一个汉字
            if firstChar.unicodeScalars.first?.value ?? 0 > 0x4E00 {
                return String(firstChar)
            }
            // 如果是英文，返回大写首字母
            return String(firstChar).uppercased()
        }

        return "?"
    }
}
