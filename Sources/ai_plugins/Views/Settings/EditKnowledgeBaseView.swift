import AppKit
import SwiftUI

struct EditKnowledgeBaseView: View {
    let knowledgeBase: KnowledgeBase
    @ObservedObject var manager: KnowledgeBaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var description: String
    @State private var isEnabled: Bool
    @State private var showingFolderPicker = false
    @State private var isValidConfiguration = true
    @State private var isProcessing = false
    @State private var processingStatus = ""

    // Local Folder Config
    @State private var folderPath: String
    @State private var includeSubfolders: Bool
    @State private var supportedExtensions: String

    // Web Site Config
    @State private var webURL: String
    @State private var crawlDepth: Int
    @State private var maxPages: Int
    @State private var respectRobotsTxt: Bool

    // Enterprise API Config
    @State private var apiEndpoint: String
    @State private var apiKey: String
    @State private var timeout: Double

    init(knowledgeBase: KnowledgeBase, manager: KnowledgeBaseManager) {
        self.knowledgeBase = knowledgeBase
        self.manager = manager

        // Initialize state from knowledge base
        self._name = State(initialValue: knowledgeBase.name)
        self._description = State(initialValue: knowledgeBase.description)
        self._isEnabled = State(initialValue: knowledgeBase.isEnabled)

        // Initialize type-specific configs
        switch knowledgeBase.type {
        case .localFolder:
            let config = knowledgeBase.localFolderConfig ?? LocalFolderConfig(folderPath: "")
            self._folderPath = State(initialValue: config.folderPath)
            self._includeSubfolders = State(initialValue: config.includeSubfolders)
            self._supportedExtensions = State(
                initialValue: config.supportedExtensions.joined(separator: ","))

            // Initialize unused configs with defaults
            self._webURL = State(initialValue: "")
            self._crawlDepth = State(initialValue: 2)
            self._maxPages = State(initialValue: 100)
            self._respectRobotsTxt = State(initialValue: true)
            self._apiEndpoint = State(initialValue: "")
            self._apiKey = State(initialValue: "")
            self._timeout = State(initialValue: 30.0)

        case .webSite:
            let config = knowledgeBase.webSiteConfig ?? WebSiteConfig(baseURL: "")
            self._webURL = State(initialValue: config.baseURL)
            self._crawlDepth = State(initialValue: config.crawlDepth)
            self._maxPages = State(initialValue: config.maxPages)
            self._respectRobotsTxt = State(initialValue: config.respectRobotsTxt)

            // Initialize unused configs with defaults
            self._folderPath = State(initialValue: "")
            self._includeSubfolders = State(initialValue: true)
            self._supportedExtensions = State(initialValue: "txt,md")
            self._apiEndpoint = State(initialValue: "")
            self._apiKey = State(initialValue: "")
            self._timeout = State(initialValue: 30.0)

        case .enterpriseAPI:
            let config =
                knowledgeBase.enterpriseAPIConfig
                ?? EnterpriseAPIConfig(apiEndpoint: "", apiKey: "")
            self._apiEndpoint = State(initialValue: config.apiEndpoint)
            self._apiKey = State(initialValue: config.apiKey)
            self._timeout = State(initialValue: config.timeout)

            // Initialize unused configs with defaults
            self._folderPath = State(initialValue: "")
            self._includeSubfolders = State(initialValue: true)
            self._supportedExtensions = State(initialValue: "txt,md")
            self._webURL = State(initialValue: "")
            self._crawlDepth = State(initialValue: 2)
            self._maxPages = State(initialValue: 100)
            self._respectRobotsTxt = State(initialValue: true)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("edit_knowledge_base", bundle: .module, comment: ""))
                        .font(.title2)
                        .fontWeight(.semibold)

                    HStack(spacing: 8) {
                        Image(systemName: knowledgeBase.type.icon)
                            .font(.system(size: 14))
                            .foregroundColor(.accentColor)

                        Text(
                            NSLocalizedString(
                                knowledgeBase.type.localizedNameKey, bundle: .module, comment: "")
                        )
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                        StatusBadge(status: knowledgeBase.displayStatus)
                    }
                }

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
                    // Status and Statistics
                    statusSection

                    // Basic Information
                    basicInfoSection

                    // Configuration
                    configurationSection

                    // Actions
                    actionsSection
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

                Button(NSLocalizedString("save_changes", bundle: .module, comment: "")) {
                    saveChanges()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValidConfiguration || isProcessing)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 700, height: 800)
        .onChange(of: name) { _ in validateConfiguration() }
        .onChange(of: folderPath) { _ in validateConfiguration() }
        .onChange(of: webURL) { _ in validateConfiguration() }
        .onChange(of: apiEndpoint) { _ in validateConfiguration() }
        .onChange(of: apiKey) { _ in validateConfiguration() }
        .onAppear { validateConfiguration() }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("current_status", bundle: .module, comment: ""))
                .font(.headline)

            HStack(spacing: 20) {
                // Status Info
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(NSLocalizedString("status", bundle: .module, comment: ""))
                            .font(.system(size: 13, weight: .medium))

                        StatusBadge(status: knowledgeBase.displayStatus)
                    }

                    if knowledgeBase.totalVectors > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)

                            Text(
                                "\(knowledgeBase.totalVectors) \(NSLocalizedString("vectors", bundle: .module, comment: ""))"
                            )
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        }
                    }

                    if let lastUpdate = knowledgeBase.lastVectorized {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)

                            Text(
                                NSLocalizedString("last_updated", bundle: .module, comment: "")
                                    + ": "
                                    + RelativeDateTimeFormatter().localizedString(
                                        for: lastUpdate, relativeTo: Date())
                            )
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Enable/Disable Toggle
                VStack(spacing: 8) {
                    Toggle(
                        NSLocalizedString("enabled", bundle: .module, comment: ""), isOn: $isEnabled
                    )
                    .toggleStyle(.switch)

                    if isProcessing {
                        VStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.8)

                            Text(processingStatus)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
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

    // MARK: - Configuration Section

    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("configuration", bundle: .module, comment: ""))
                .font(.headline)

            Group {
                switch knowledgeBase.type {
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

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("actions", bundle: .module, comment: ""))
                .font(.headline)

            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 12
            ) {

                // Process/Index Button
                Button(action: processKnowledgeBase) {
                    HStack(spacing: 8) {
                        Image(systemName: getProcessIcon())
                            .font(.system(size: 16))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(getProcessButtonText())
                                .font(.system(size: 13, weight: .medium))

                            Text(getProcessButtonDescription())
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(isProcessing || !isValidConfiguration)

                // Clear Data Button
                Button(action: clearVectorData) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.red)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("clear_data", bundle: .module, comment: ""))
                                .font(.system(size: 13, weight: .medium))

                            Text(NSLocalizedString("clear_data_desc", bundle: .module, comment: ""))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(isProcessing || knowledgeBase.totalVectors == 0)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }

    // MARK: - Type-specific Configurations (same as AddKnowledgeBaseView)

    private var localFolderConfig: some View {
        VStack(spacing: 16) {
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

            Toggle(
                NSLocalizedString("include_subfolders", bundle: .module, comment: ""),
                isOn: $includeSubfolders
            )
            .font(.system(size: 13))

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

    private var webSiteConfig: some View {
        VStack(spacing: 16) {
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

            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("max_pages", bundle: .module, comment: ""))
                    .font(.system(size: 13, weight: .medium))

                TextField("100", value: $maxPages, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
            }

            Toggle(
                NSLocalizedString("respect_robots_txt", bundle: .module, comment: ""),
                isOn: $respectRobotsTxt
            )
            .font(.system(size: 13))
        }
    }

    private var enterpriseAPIConfig: some View {
        VStack(spacing: 16) {
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
        switch knowledgeBase.type {
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

    private func getProcessIcon() -> String {
        switch knowledgeBase.type {
        case .localFolder:
            return "folder.badge.gearshape"
        case .webSite:
            return "globe.badge.chevron.backward"
        case .enterpriseAPI:
            return "arrow.down.circle"
        }
    }

    private func getProcessButtonText() -> String {
        switch knowledgeBase.type {
        case .localFolder:
            return NSLocalizedString("index_files", bundle: .module, comment: "")
        case .webSite:
            return NSLocalizedString("crawl_website", bundle: .module, comment: "")
        case .enterpriseAPI:
            return NSLocalizedString("sync_data", bundle: .module, comment: "")
        }
    }

    private func getProcessButtonDescription() -> String {
        switch knowledgeBase.type {
        case .localFolder:
            return NSLocalizedString("index_files_desc", bundle: .module, comment: "")
        case .webSite:
            return NSLocalizedString("crawl_website_desc", bundle: .module, comment: "")
        case .enterpriseAPI:
            return NSLocalizedString("sync_data_desc", bundle: .module, comment: "")
        }
    }

    private func saveChanges() {
        var updatedKB = knowledgeBase
        updatedKB.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedKB.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedKB.isEnabled = isEnabled

        // Update type-specific configuration
        switch knowledgeBase.type {
        case .localFolder:
            var config = updatedKB.localFolderConfig ?? LocalFolderConfig(folderPath: "")
            config.folderPath = folderPath.trimmingCharacters(in: .whitespacesAndNewlines)
            config.includeSubfolders = includeSubfolders
            config.supportedExtensions =
                supportedExtensions
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            updatedKB.localFolderConfig = config

        case .webSite:
            var config = updatedKB.webSiteConfig ?? WebSiteConfig(baseURL: "")
            config.baseURL = webURL.trimmingCharacters(in: .whitespacesAndNewlines)
            config.crawlDepth = crawlDepth
            config.maxPages = maxPages
            config.respectRobotsTxt = respectRobotsTxt
            updatedKB.webSiteConfig = config

        case .enterpriseAPI:
            var config =
                updatedKB.enterpriseAPIConfig ?? EnterpriseAPIConfig(apiEndpoint: "", apiKey: "")
            config.apiEndpoint = apiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
            config.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            config.timeout = timeout
            updatedKB.enterpriseAPIConfig = config
        }

        manager.updateKnowledgeBase(updatedKB)
        dismiss()
    }

    private func processKnowledgeBase() {
        isProcessing = true
        processingStatus = NSLocalizedString("processing", bundle: .module, comment: "")

        // Simulate processing - in real implementation this would call actual processing services
        Task {
            await MainActor.run {
                switch knowledgeBase.type {
                case .localFolder:
                    processingStatus = NSLocalizedString(
                        "indexing_files", bundle: .module, comment: "")
                case .webSite:
                    processingStatus = NSLocalizedString(
                        "crawling_website", bundle: .module, comment: "")
                case .enterpriseAPI:
                    processingStatus = NSLocalizedString(
                        "syncing_data", bundle: .module, comment: "")
                }
            }

            // Simulate work
            try? await Task.sleep(nanoseconds: 3_000_000_000)  // 3 seconds

            await MainActor.run {
                isProcessing = false
                processingStatus = ""
                // Here you would update the knowledge base with actual results
            }
        }
    }

    private func clearVectorData() {
        // In real implementation, this would clear the vector database
        var updatedKB = knowledgeBase
        updatedKB.totalVectors = 0
        updatedKB.lastVectorized = nil
        manager.updateKnowledgeBase(updatedKB)
    }
}

// MARK: - Preview

#Preview {
    let sampleKB = KnowledgeBase(
        name: "Sample Knowledge Base",
        type: .localFolder,
        description: "A sample knowledge base for testing"
    )

    return EditKnowledgeBaseView(
        knowledgeBase: sampleKB,
        manager: KnowledgeBaseManager()
    )
}
