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
    @State private var processingProgress: Double = 0.0
    @State private var currentFile = ""
    @State private var totalFiles = 0
    @State private var processedFiles = 0
    @State private var currentStep = ""

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

            // Progress Section - Only show when processing
            if isProcessing {
                VStack(alignment: .leading, spacing: 12) {
                    // Progress Bar
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(currentStep.isEmpty ? "Processing..." : currentStep)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)

                            Spacer()

                            // Cancel Button
                            Button(action: {
                                Task {
                                    await cancelProcessing()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                    Text("Cancel")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundColor(.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)

                            if totalFiles > 0 {
                                Text("\(processedFiles)/\(totalFiles)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 8)
                            }
                        }

                        ProgressView(value: processingProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(height: 8)
                    }

                    // Current File Info
                    if !currentFile.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            Text(currentFile)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }

                    // Status Message
                    if !processingStatus.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.blue)

                            Text(processingStatus)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
                .cornerRadius(8)
            }

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
        // Reset progress state
        isProcessing = true
        processingProgress = 0.0
        currentFile = ""
        totalFiles = 0
        processedFiles = 0
        currentStep = "Preparing..."
        processingStatus = ""

        Task {
            do {
                // Step 1: Save changes
                await MainActor.run {
                    currentStep = "Saving configuration..."
                    processingProgress = 0.1
                    saveChanges()
                }

                // Get the updated knowledge base
                guard
                    let updatedKB = manager.knowledgeBases.first(where: {
                        $0.id == knowledgeBase.id
                    })
                else {
                    throw ProcessingError.processingFailed("Knowledge base not found")
                }

                // Step 2: Setup progress tracking
                await MainActor.run {
                    currentStep = "Initializing processing..."
                    processingProgress = 0.2
                }

                // Get processing service and setup observers
                let service = KnowledgeBaseService.shared

                // Monitor processing progress
                let progressTask = Task {
                    while isProcessing {
                        await MainActor.run {
                            processingProgress = service.processingProgress
                            processingStatus = service.processingStatus

                            // Update step based on progress
                            if processingProgress < 0.3 {
                                currentStep = "Scanning files..."
                            } else if processingProgress < 0.7 {
                                currentStep = "Processing documents..."
                            } else if processingProgress < 0.9 {
                                currentStep = "Generating embeddings..."
                            } else {
                                currentStep = "Saving to vector database..."
                            }
                        }

                        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
                    }
                }

                // Step 3: Call the actual processing service
                await MainActor.run {
                    currentStep = "Starting file processing..."
                    processingProgress = 0.3
                }

                let result = try await service.processKnowledgeBase(updatedKB)

                // Cancel progress monitoring
                progressTask.cancel()

                await MainActor.run {
                    currentStep = "Updating knowledge base..."
                    processingProgress = 0.95

                    // Update the knowledge base with processing results
                    var processedKB = updatedKB
                    processedKB.totalDocuments = result.totalFiles
                    processedKB.totalChunks = result.documents.reduce(0) { $0 + $1.chunks.count }
                    processedKB.totalVectors = result.vectorCount
                    processedKB.lastVectorized = Date()

                    // Update the appropriate config timestamp based on type
                    let currentDate = Date()
                    switch processedKB.type {
                    case .localFolder:
                        processedKB.localFolderConfig?.lastIndexed = currentDate
                        processedKB.localFolderConfig?.totalFiles = result.totalFiles
                    case .webSite:
                        processedKB.webSiteConfig?.lastCrawled = currentDate
                        processedKB.webSiteConfig?.totalPages = result.totalFiles
                    case .enterpriseAPI:
                        processedKB.enterpriseAPIConfig?.lastSynced = currentDate
                        processedKB.enterpriseAPIConfig?.totalDocuments = result.totalFiles
                    }

                    processedKB.updateTimestamp()
                    manager.updateKnowledgeBase(processedKB)

                    // Final step
                    currentStep = "Completed successfully!"
                    processingProgress = 1.0
                    totalFiles = result.totalFiles
                    processedFiles = result.processedFiles
                    currentFile = ""

                    processingStatus =
                        "Processed \(result.processedFiles) files, created \(result.vectorCount) vectors"

                    // Clear processing state after a delay
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)  // 3 seconds
                        await MainActor.run {
                            isProcessing = false
                            processingProgress = 0.0
                            currentStep = ""
                            currentFile = ""
                            processingStatus = ""
                            totalFiles = 0
                            processedFiles = 0
                        }
                    }
                }

            } catch {
                await MainActor.run {
                    isProcessing = false
                    currentStep = "Error occurred"
                    processingProgress = 0.0
                    currentFile = ""
                    totalFiles = 0
                    processedFiles = 0
                    processingStatus = "Failed: \(error.localizedDescription)"

                    // Clear error message after a delay
                    Task {
                        try? await Task.sleep(nanoseconds: 8_000_000_000)  // 8 seconds
                        await MainActor.run {
                            processingStatus = ""
                            currentStep = ""
                        }
                    }
                }
                print("Knowledge base processing failed: \(error)")
            }
        }
    }

    private func clearVectorData() {
        Task {
            do {
                // Call the actual service to clear vector data
                try await KnowledgeBaseService.shared.clearKnowledgeBaseData(knowledgeBase)

                await MainActor.run {
                    // Update the knowledge base status
                    var updatedKB = knowledgeBase
                    updatedKB.totalDocuments = 0
                    updatedKB.totalChunks = 0
                    updatedKB.totalVectors = 0
                    updatedKB.lastVectorized = nil

                    // Clear the appropriate config timestamp based on type
                    switch updatedKB.type {
                    case .localFolder:
                        updatedKB.localFolderConfig?.lastIndexed = nil
                        updatedKB.localFolderConfig?.totalFiles = 0
                    case .webSite:
                        updatedKB.webSiteConfig?.lastCrawled = nil
                        updatedKB.webSiteConfig?.totalPages = 0
                    case .enterpriseAPI:
                        updatedKB.enterpriseAPIConfig?.lastSynced = nil
                        updatedKB.enterpriseAPIConfig?.totalDocuments = 0
                    }

                    updatedKB.updateTimestamp()

                    manager.updateKnowledgeBase(updatedKB)
                }

            } catch {
                print("Failed to clear vector data: \(error)")
                await MainActor.run {
                    processingStatus = "Failed to clear data: \(error.localizedDescription)"

                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        await MainActor.run {
                            processingStatus = ""
                        }
                    }
                }
            }
        }
    }

    private func cancelProcessing() async {
        await MainActor.run {
            currentStep = "Cancelling..."
            processingStatus = "Processing cancelled by user"
        }

        // Cancel the processing service
        KnowledgeBaseService.shared.cancelProcessing()

        await MainActor.run {
            isProcessing = false
            processingProgress = 0.0
            currentStep = ""
            currentFile = ""
            totalFiles = 0
            processedFiles = 0

            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
                await MainActor.run {
                    processingStatus = ""
                }
            }
        }
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
