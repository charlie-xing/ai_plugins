import AppKit
import SwiftUI

struct KnowledgeBaseSettingsView: View {
    @ObservedObject var settings: AppSettings
    @StateObject private var knowledgeBaseManager = KnowledgeBaseManager()

    @State private var showingAddSheet = false
    @State private var editingKB: KnowledgeBase?
    @State private var selectedType: KnowledgeBaseType = .localFolder
    @State private var showingDeleteAlert = false
    @State private var kbToDelete: KnowledgeBase?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(
                            NSLocalizedString(
                                "knowledge_base_settings", bundle: .module, comment: "")
                        )
                        .font(.headline)

                        Spacer()

                        Button(action: {
                            showingAddSheet = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .medium))
                                Text(
                                    NSLocalizedString(
                                        "add_knowledge_base", bundle: .module, comment: "")
                                )
                                .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                    }

                    Text(
                        NSLocalizedString(
                            "knowledge_base_description", bundle: .module, comment: "")
                    )
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)

                // Knowledge Base List
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(
                            NSLocalizedString(
                                "configured_knowledge_bases", bundle: .module, comment: "")
                        )
                        .font(.headline)

                        Spacer()

                        Text(
                            "\(knowledgeBaseManager.knowledgeBases.count) \(NSLocalizedString("knowledge_bases_count", bundle: .module, comment: ""))"
                        )
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    }

                    if knowledgeBaseManager.knowledgeBases.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text(
                                NSLocalizedString(
                                    "no_knowledge_bases", bundle: .module, comment: "")
                            )
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            Text(
                                NSLocalizedString(
                                    "add_knowledge_base_hint", bundle: .module, comment: "")
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(knowledgeBaseManager.knowledgeBases) { kb in
                                KnowledgeBaseRow(
                                    knowledgeBase: kb,
                                    onEdit: {
                                        editingKB = kb
                                    },
                                    onDelete: {
                                        kbToDelete = kb
                                        showingDeleteAlert = true
                                    },
                                    onToggle: {
                                        knowledgeBaseManager.toggleKnowledgeBase(kb)
                                    }
                                )
                            }
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showingAddSheet) {
            AddKnowledgeBaseView(manager: knowledgeBaseManager)
        }
        .sheet(item: $editingKB) { kb in
            EditKnowledgeBaseView(knowledgeBase: kb, manager: knowledgeBaseManager)
        }
        .alert(
            NSLocalizedString("delete_knowledge_base", bundle: .module, comment: ""),
            isPresented: $showingDeleteAlert
        ) {
            Button(NSLocalizedString("cancel", bundle: .module, comment: ""), role: .cancel) {}
            Button(NSLocalizedString("delete", bundle: .module, comment: ""), role: .destructive) {
                if let kb = kbToDelete {
                    knowledgeBaseManager.deleteKnowledgeBase(kb)
                }
            }
        } message: {
            if let kb = kbToDelete {
                Text(
                    NSLocalizedString("delete_knowledge_base_message", bundle: .module, comment: "")
                        + " \"\(kb.name)\"?")
            }
        }
        .onAppear {
            WindowTitleManager.shared.setSettingsTitle("knowledge_base")
        }
    }
}

// MARK: - Knowledge Base Row Component

struct KnowledgeBaseRow: View {
    let knowledgeBase: KnowledgeBase
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Type Icon
            Image(systemName: knowledgeBase.type.icon)
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)

            // Knowledge Base Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(knowledgeBase.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)

                    StatusBadge(status: knowledgeBase.displayStatus)
                }

                Text(
                    NSLocalizedString(
                        knowledgeBase.type.localizedNameKey, bundle: .module, comment: "")
                )
                .font(.system(size: 11))
                .foregroundColor(.secondary)

                if !knowledgeBase.description.isEmpty {
                    Text(knowledgeBase.description)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                // Statistics
                HStack(spacing: 12) {
                    if knowledgeBase.totalVectors > 0 {
                        Label("\(knowledgeBase.totalVectors)", systemImage: "doc.text.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }

                    if let lastUpdate = knowledgeBase.lastVectorized {
                        Label(
                            RelativeDateTimeFormatter().localizedString(
                                for: lastUpdate, relativeTo: Date()), systemImage: "clock.fill"
                        )
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Controls
            VStack(spacing: 8) {
                // Enable/Disable Toggle
                Toggle(
                    "",
                    isOn: Binding(
                        get: { knowledgeBase.isEnabled },
                        set: { _ in onToggle() }
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.mini)

                // Action Buttons
                HStack(spacing: 4) {
                    Button(action: onEdit) {
                        Image(systemName: "gear")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .help(NSLocalizedString("configure", bundle: .module, comment: ""))

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                    .help(NSLocalizedString("delete", bundle: .module, comment: ""))
                }
            }
        }
        .padding(12)
        .background(
            knowledgeBase.isEnabled
                ? Color(NSColor.controlBackgroundColor)
                : Color(NSColor.controlBackgroundColor).opacity(0.5)
        )
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    knowledgeBase.isEnabled ? Color.clear : Color.secondary.opacity(0.3),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Status Badge Component

struct StatusBadge: View {
    let status: KnowledgeBaseStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(statusColor.opacity(0.1))
        .cornerRadius(4)
    }

    private var statusColor: Color {
        switch status.color {
        case "green":
            return .green
        case "orange":
            return .orange
        case "red":
            return .red
        case "blue":
            return .blue
        default:
            return .secondary
        }
    }
}

// MARK: - Preview

#Preview {
    KnowledgeBaseSettingsView(settings: AppSettings())
}
