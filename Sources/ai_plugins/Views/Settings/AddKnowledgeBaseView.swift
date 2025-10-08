import AppKit
import SwiftUI

struct AddKnowledgeBaseView: View {
    @ObservedObject var manager: KnowledgeBaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var selectedType: KnowledgeBaseType = .localFolder
    @State private var showingFolderPicker = false
    @State private var isValidConfiguration = false

    // Local Folder Config
    @State private var folderPath: String = ""
    @State private var includeSubfolders: Bool = true
    @State private var supportedExtensions: String = "txt,md"

    // Web Site Config
    @State private var webURL: String = ""
    @State private var crawlDepth: Int = 2
    @State private var maxPages: Int = 100
    @State private var respectRobotsTxt: Bool = true

    // Enterprise API Config
    @State private var apiEndpoint: String = ""
    @State private var apiKey: String = ""
    @State private var timeout: Double = 30.0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(NSLocalizedString("add_knowledge_base", bundle: .module, comment: ""))
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 24) {
                    // Basic Information
                    basicInfoSection

                    // Type Selection
                    typeSelectionSection

                    // Type-specific Configuration
                    configurationSection
                }
                .padding(24)
            }

            Divider()

            // Footer Buttons
            HStack(spacing: 12) {
                Button(NSLocalizedString("cancel", bundle: .module, comment: "")) {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Button(NSLocalizedString("save", bundle: .module, comment: "")) {
                    saveKnowledgeBase()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValidConfiguration)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 600, height: 700)
        .onChange(of: name) { _ in validateConfiguration() }
        .onChange(of: selectedType) { _ in validateConfiguration() }
        .onChange(of: folderPath) { _ in validateConfiguration() }
        .onChange(of: webURL) { _ in validateConfiguration() }
        .onChange(of: apiEndpoint) { _ in validateConfiguration() }
        .onChange(of: apiKey) { _ in validateConfiguration() }
        .onAppear { validateConfiguration() }
    }

    // MARK: - Basic Information Section

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("basic_information", bundle: .module, comment: ""))
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("knowledge_base_name", bundle: .module, comment: ""))
                    .font(.system(size: 13, weight: .medium))

                TextField(
                    NSLocalizedString("enter_kb_name", bundle: .module, comment: ""),
                    text: $name
                )
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("description_optional", bundle: .module, comment: ""))
                    .font(.system(size: 13, weight: .medium))

                TextField(
                    NSLocalizedString("enter_kb_description", bundle: .module, comment: ""),
                    text: $description,
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .lineLimit(3...6)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }

    // MARK: - Type Selection Section

    private var typeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("knowledge_base_type", bundle: .module, comment: ""))
                .font(.headline)

            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 12
            ) {
                ForEach(KnowledgeBaseType.allCases) { type in
                    TypeSelectionCard(
                        type: type,
                        isSelected: selectedType == type,
                        onSelect: {
                            selectedType = type
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }

    // MARK: - Configuration Section

    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("configuration", bundle: .module, comment: ""))
                .font(.headline)

            Group {
                switch selectedType {
                case .localFolder:
                    localFolderConfig
                case .webSite:
                    webSiteConfig
                case .enterpriseAPI:
                    enterpriseAPIConfig
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }

    // MARK: - Local Folder Configuration

    private var localFolderConfig: some View {
        VStack(spacing: 16) {
            // Folder Path
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("folder_path", bundle: .module, comment: ""))
                    .font(.system(size: 13, weight: .medium))

                HStack {
                    TextField(
                        NSLocalizedString("select_folder", bundle: .module, comment: ""),
                        text: $folderPath
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))

                    Button(NSLocalizedString("browse", bundle: .module, comment: "")) {
                        showFolderPicker()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            // Include Subfolders
            Toggle(
                NSLocalizedString("include_subfolders", bundle: .module, comment: ""),
                isOn: $includeSubfolders
            )
            .font(.system(size: 13))

            // Supported Extensions
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("supported_extensions", bundle: .module, comment: ""))
                    .font(.system(size: 13, weight: .medium))

                TextField(
                    NSLocalizedString("extensions_placeholder", bundle: .module, comment: ""),
                    text: $supportedExtensions
                )
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))

                Text(NSLocalizedString("extensions_hint", bundle: .module, comment: ""))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Web Site Configuration

    private var webSiteConfig: some View {
        VStack(spacing: 16) {
            // Base URL
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("website_url", bundle: .module, comment: ""))
                    .font(.system(size: 13, weight: .medium))

                TextField(
                    NSLocalizedString("enter_website_url", bundle: .module, comment: ""),
                    text: $webURL
                )
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
            }

            // Crawl Depth
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("crawl_depth", bundle: .module, comment: ""))
                    .font(.system(size: 13, weight: .medium))

                HStack {
                    Slider(
                        value: Binding(
                            get: { Double(crawlDepth) },
                            set: { crawlDepth = Int($0) }
                        ), in: 1...5, step: 1)

                    Text("\(crawlDepth)")
                        .font(.system(size: 13))
                        .frame(width: 20)
                }

                Text(NSLocalizedString("crawl_depth_hint", bundle: .module, comment: ""))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            // Max Pages
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("max_pages", bundle: .module, comment: ""))
                    .font(.system(size: 13, weight: .medium))

                TextField("100", value: $maxPages, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
            }

            // Respect robots.txt
            Toggle(
                NSLocalizedString("respect_robots_txt", bundle: .module, comment: ""),
                isOn: $respectRobotsTxt
            )
            .font(.system(size: 13))
        }
    }

    // MARK: - Enterprise API Configuration

    private var enterpriseAPIConfig: some View {
        VStack(spacing: 16) {
            // API Endpoint
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("api_endpoint", bundle: .module, comment: ""))
                    .font(.system(size: 13, weight: .medium))

                TextField(
                    NSLocalizedString("enter_api_endpoint", bundle: .module, comment: ""),
                    text: $apiEndpoint
                )
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
            }

            // API Key
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("api_key", bundle: .module, comment: ""))
                    .font(.system(size: 13, weight: .medium))

                SecureField(
                    NSLocalizedString("enter_api_key", bundle: .module, comment: ""),
                    text: $apiKey
                )
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
            }

            // Timeout
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("timeout_seconds", bundle: .module, comment: ""))
                    .font(.system(size: 13, weight: .medium))

                TextField("30", value: $timeout, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
            }
        }
    }

    // MARK: - Helper Methods

    private func showFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = NSLocalizedString("select", bundle: .module, comment: "")

        if panel.runModal() == .OK, let url = panel.url {
            folderPath = url.path
        }
    }

    private func validateConfiguration() {
        let hasName = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        let hasValidConfig: Bool
        switch selectedType {
        case .localFolder:
            hasValidConfig = !folderPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .webSite:
            hasValidConfig =
                !webURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && (webURL.hasPrefix("http://") || webURL.hasPrefix("https://"))
        case .enterpriseAPI:
            hasValidConfig =
                !apiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        isValidConfiguration = hasName && hasValidConfig
    }

    private func saveKnowledgeBase() {
        var kb = KnowledgeBase(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            type: selectedType,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines))

        // Configure type-specific settings
        switch selectedType {
        case .localFolder:
            var config = LocalFolderConfig(
                folderPath: folderPath.trimmingCharacters(in: .whitespacesAndNewlines))
            config.includeSubfolders = includeSubfolders
            config.supportedExtensions =
                supportedExtensions
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            kb.localFolderConfig = config

        case .webSite:
            var config = WebSiteConfig(
                baseURL: webURL.trimmingCharacters(in: .whitespacesAndNewlines))
            config.crawlDepth = crawlDepth
            config.maxPages = maxPages
            config.respectRobotsTxt = respectRobotsTxt
            kb.webSiteConfig = config

        case .enterpriseAPI:
            var config = EnterpriseAPIConfig(
                apiEndpoint: apiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines),
                apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            config.timeout = timeout
            kb.enterpriseAPIConfig = config
        }

        // Set vector database path
        kb.vectorDatabasePath = manager.vectorDatabasePath(for: kb).path

        manager.addKnowledgeBase(kb)
        dismiss()
    }
}

// MARK: - Type Selection Card

struct TypeSelectionCard: View {
    let type: KnowledgeBaseType
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : .accentColor)
                    .frame(width: 48, height: 48)
                    .background(isSelected ? Color.accentColor : Color.accentColor.opacity(0.1))
                    .cornerRadius(12)

                VStack(spacing: 4) {
                    Text(NSLocalizedString(type.localizedNameKey, bundle: .module, comment: ""))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)

                    Text(NSLocalizedString(type.descriptionKey, bundle: .module, comment: ""))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(
                isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    AddKnowledgeBaseView(manager: KnowledgeBaseManager())
}
