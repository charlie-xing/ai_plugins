import Foundation

// MARK: - Knowledge Base Types

enum KnowledgeBaseType: String, CaseIterable, Identifiable, Codable {
    case localFolder = "local_folder"
    case webSite = "web_site"
    case enterpriseAPI = "enterprise_api"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .localFolder:
            return "folder.fill"
        case .webSite:
            return "globe"
        case .enterpriseAPI:
            return "server.rack"
        }
    }

    var localizedNameKey: String {
        switch self {
        case .localFolder:
            return "local_folder_kb"
        case .webSite:
            return "web_site_kb"
        case .enterpriseAPI:
            return "enterprise_api_kb"
        }
    }

    var descriptionKey: String {
        switch self {
        case .localFolder:
            return "local_folder_kb_desc"
        case .webSite:
            return "web_site_kb_desc"
        case .enterpriseAPI:
            return "enterprise_api_kb_desc"
        }
    }
}

// MARK: - Knowledge Base Configuration

struct LocalFolderConfig: Codable, Equatable {
    var folderPath: String
    var includeSubfolders: Bool = true
    var supportedExtensions: [String] = ["txt", "md"]
    var maxFileSize: Int = 10 * 1024 * 1024  // 10MB
    var lastIndexed: Date?
    var totalFiles: Int = 0
}

struct WebSiteConfig: Codable, Equatable {
    var baseURL: String
    var crawlDepth: Int = 2
    var includePatterns: [String] = []
    var excludePatterns: [String] = []
    var respectRobotsTxt: Bool = true
    var maxPages: Int = 100
    var crawlInterval: TimeInterval = 24 * 3600  // 24 hours
    var lastCrawled: Date?
    var totalPages: Int = 0
}

struct EnterpriseAPIConfig: Codable, Equatable {
    var apiEndpoint: String
    var apiKey: String
    var authHeaders: [String: String] = [:]
    var timeout: TimeInterval = 30
    var batchSize: Int = 50
    var lastSynced: Date?
    var totalDocuments: Int = 0
}

// MARK: - Knowledge Base Model

struct KnowledgeBase: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var type: KnowledgeBaseType
    var description: String
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    // Type-specific configurations
    var localFolderConfig: LocalFolderConfig?
    var webSiteConfig: WebSiteConfig?
    var enterpriseAPIConfig: EnterpriseAPIConfig?

    // Vector database info
    var vectorDatabasePath: String?
    var totalVectors: Int = 0
    var lastVectorized: Date?

    init(name: String, type: KnowledgeBaseType, description: String = "") {
        self.id = UUID()
        self.name = name
        self.type = type
        self.description = description
        self.isEnabled = true
        self.createdAt = Date()
        self.updatedAt = Date()

        // Initialize type-specific config
        switch type {
        case .localFolder:
            self.localFolderConfig = LocalFolderConfig(folderPath: "")
        case .webSite:
            self.webSiteConfig = WebSiteConfig(baseURL: "")
        case .enterpriseAPI:
            self.enterpriseAPIConfig = EnterpriseAPIConfig(apiEndpoint: "", apiKey: "")
        }
    }

    // MARK: - Helper Methods

    var displayStatus: KnowledgeBaseStatus {
        if !isEnabled {
            return .disabled
        }

        switch type {
        case .localFolder:
            guard let config = localFolderConfig,
                !config.folderPath.isEmpty
            else {
                return .notConfigured
            }
            return config.lastIndexed != nil ? .ready : .needsIndexing

        case .webSite:
            guard let config = webSiteConfig,
                !config.baseURL.isEmpty
            else {
                return .notConfigured
            }
            return config.lastCrawled != nil ? .ready : .needsCrawling

        case .enterpriseAPI:
            guard let config = enterpriseAPIConfig,
                !config.apiEndpoint.isEmpty,
                !config.apiKey.isEmpty
            else {
                return .notConfigured
            }
            return config.lastSynced != nil ? .ready : .needsSync
        }
    }

    var statusText: String {
        switch displayStatus {
        case .ready:
            return NSLocalizedString("kb_status_ready", bundle: .module, comment: "")
        case .notConfigured:
            return NSLocalizedString("kb_status_not_configured", bundle: .module, comment: "")
        case .needsIndexing:
            return NSLocalizedString("kb_status_needs_indexing", bundle: .module, comment: "")
        case .needsCrawling:
            return NSLocalizedString("kb_status_needs_crawling", bundle: .module, comment: "")
        case .needsSync:
            return NSLocalizedString("kb_status_needs_sync", bundle: .module, comment: "")
        case .disabled:
            return NSLocalizedString("kb_status_disabled", bundle: .module, comment: "")
        case .processing:
            return NSLocalizedString("kb_status_processing", bundle: .module, comment: "")
        case .error:
            return NSLocalizedString("kb_status_error", bundle: .module, comment: "")
        }
    }

    mutating func updateTimestamp() {
        self.updatedAt = Date()
    }
}

// MARK: - Knowledge Base Status

enum KnowledgeBaseStatus: String, CaseIterable {
    case ready = "ready"
    case notConfigured = "not_configured"
    case needsIndexing = "needs_indexing"
    case needsCrawling = "needs_crawling"
    case needsSync = "needs_sync"
    case disabled = "disabled"
    case processing = "processing"
    case error = "error"

    var color: String {
        switch self {
        case .ready:
            return "green"
        case .notConfigured, .needsIndexing, .needsCrawling, .needsSync:
            return "orange"
        case .disabled:
            return "gray"
        case .processing:
            return "blue"
        case .error:
            return "red"
        }
    }
}

// MARK: - Knowledge Base Manager

@MainActor
class KnowledgeBaseManager: ObservableObject {
    @Published var knowledgeBases: [KnowledgeBase] = []
    @Published var isLoading = false

    private let dataDirectory: URL
    private let configFileName = "knowledge_bases.json"

    init() {
        // Create ~/.ai_plugins_data directory
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        self.dataDirectory = homeDirectory.appendingPathComponent(
            ".ai_plugins_data/knowledge_bases")

        createDataDirectoryIfNeeded()
        loadKnowledgeBases()
    }

    // MARK: - Data Management

    private func createDataDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: dataDirectory.path) {
            try? FileManager.default.createDirectory(
                at: dataDirectory, withIntermediateDirectories: true)
        }
    }

    private func configFileURL() -> URL {
        return dataDirectory.appendingPathComponent(configFileName)
    }

    func loadKnowledgeBases() {
        let configURL = configFileURL()

        guard FileManager.default.fileExists(atPath: configURL.path) else {
            knowledgeBases = []
            return
        }

        do {
            let data = try Data(contentsOf: configURL)
            knowledgeBases = try JSONDecoder().decode([KnowledgeBase].self, from: data)
        } catch {
            print("Failed to load knowledge bases: \(error)")
            knowledgeBases = []
        }
    }

    func saveKnowledgeBases() {
        let configURL = configFileURL()

        do {
            let data = try JSONEncoder().encode(knowledgeBases)
            try data.write(to: configURL)
        } catch {
            print("Failed to save knowledge bases: \(error)")
        }
    }

    // MARK: - CRUD Operations

    func addKnowledgeBase(_ knowledgeBase: KnowledgeBase) {
        knowledgeBases.append(knowledgeBase)
        saveKnowledgeBases()
    }

    func updateKnowledgeBase(_ knowledgeBase: KnowledgeBase) {
        if let index = knowledgeBases.firstIndex(where: { $0.id == knowledgeBase.id }) {
            var updatedKB = knowledgeBase
            updatedKB.updateTimestamp()
            knowledgeBases[index] = updatedKB
            saveKnowledgeBases()
        }
    }

    func deleteKnowledgeBase(_ knowledgeBase: KnowledgeBase) {
        knowledgeBases.removeAll { $0.id == knowledgeBase.id }

        // Also delete the vector database if it exists
        if let vectorPath = knowledgeBase.vectorDatabasePath {
            try? FileManager.default.removeItem(atPath: vectorPath)
        }

        saveKnowledgeBases()
    }

    func toggleKnowledgeBase(_ knowledgeBase: KnowledgeBase) {
        if let index = knowledgeBases.firstIndex(where: { $0.id == knowledgeBase.id }) {
            knowledgeBases[index].isEnabled.toggle()
            knowledgeBases[index].updateTimestamp()
            saveKnowledgeBases()
        }
    }

    // MARK: - Vector Database Path

    func vectorDatabasePath(for knowledgeBase: KnowledgeBase) -> URL {
        return dataDirectory.appendingPathComponent("vectors/\(knowledgeBase.id.uuidString)")
    }
}
