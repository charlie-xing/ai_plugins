import AppKit
import Combine
import Foundation

// MARK: - Knowledge Base Service Manager

@MainActor
class KnowledgeBaseService: ObservableObject {
    static let shared = KnowledgeBaseService()

    @Published var isProcessing = false
    @Published var currentKnowledgeBase: KnowledgeBase?
    @Published var processingProgress: Double = 0.0
    @Published var processingStatus = ""

    // Processors
    private let localFolderProcessor = LocalFolderProcessor()
    private let webCrawlerProcessor = WebCrawlerProcessor()
    private let enterpriseAPIProcessor = EnterpriseAPIProcessor()

    // Vector database manager
    private let vectorDBManager = VectorDatabaseManager()

    // Current processing task
    private var currentProcessingTask: Task<Void, Never>?

    private init() {
        // Observe individual processors
        setupProcessorObservers()
    }

    // MARK: - Public Methods

    func processKnowledgeBase(_ knowledgeBase: KnowledgeBase) async throws -> ProcessingResult {
        guard !isProcessing else {
            throw ProcessingError.processingFailed("另一个知识库正在处理中")
        }

        isProcessing = true
        currentKnowledgeBase = knowledgeBase
        processingProgress = 0.0
        processingStatus = NSLocalizedString("starting_processing", bundle: .module, comment: "")

        defer {
            isProcessing = false
            currentKnowledgeBase = nil
            processingProgress = 0.0
            processingStatus = ""
        }

        do {
            // 1. 验证配置
            try validateKnowledgeBaseConfiguration(knowledgeBase)

            // 2. 根据类型选择处理器
            let result: ProcessingResult

            switch knowledgeBase.type {
            case .localFolder:
                result = try await localFolderProcessor.processKnowledgeBase(knowledgeBase)
            case .webSite:
                result = try await webCrawlerProcessor.processKnowledgeBase(knowledgeBase)
            case .enterpriseAPI:
                result = try await enterpriseAPIProcessor.processKnowledgeBase(knowledgeBase)
            }

            // 3. 处理向量化
            if !result.documents.isEmpty {
                processingStatus = NSLocalizedString(
                    "vectorizing_documents", bundle: .module, comment: "")
                try await vectorizeDocuments(result.documents, for: knowledgeBase)
            }

            // 4. 更新知识库信息
            try await updateKnowledgeBaseStats(knowledgeBase, result: result)

            processingStatus = NSLocalizedString(
                "processing_completed", bundle: .module, comment: "")

            return result

        } catch {
            if error is CancellationError {
                processingStatus = NSLocalizedString(
                    "processing_cancelled", bundle: .module, comment: "")
                throw ProcessingError.cancelled
            }

            processingStatus = "处理失败: \(error.localizedDescription)"
            throw error
        }
    }

    func cancelProcessing() {
        currentProcessingTask?.cancel()

        // Cancel individual processors
        localFolderProcessor.cancelProcessing()
        webCrawlerProcessor.cancelProcessing()
        enterpriseAPIProcessor.cancelProcessing()

        isProcessing = false
        processingStatus = NSLocalizedString("processing_cancelled", bundle: .module, comment: "")
    }

    func testConnection(_ knowledgeBase: KnowledgeBase) async throws -> Bool {
        switch knowledgeBase.type {
        case .localFolder:
            return try await testLocalFolderConnection(knowledgeBase)
        case .webSite:
            return try await testWebSiteConnection(knowledgeBase)
        case .enterpriseAPI:
            return try await testEnterpriseAPIConnection(knowledgeBase)
        }
    }

    func getProcessingStats(_ knowledgeBase: KnowledgeBase) async -> ProcessingStats? {
        return await vectorDBManager.getStats(for: knowledgeBase)
    }

    func clearKnowledgeBaseData(_ knowledgeBase: KnowledgeBase) async throws {
        try await vectorDBManager.clearDatabase(for: knowledgeBase)
    }

    func searchInKnowledgeBase(_ knowledgeBase: KnowledgeBase, query: String, limit: Int = 10)
        async throws -> [SearchResult]
    {
        return try await vectorDBManager.search(in: knowledgeBase, query: query, limit: limit)
    }

    // MARK: - Private Methods

    private func setupProcessorObservers() {
        // Observe local folder processor
        localFolderProcessor.$isProcessing.sink { [weak self] _ in
            Task { @MainActor in
                self?.updateProcessingState()
            }
        }.store(in: &cancellables)

        localFolderProcessor.$progress.sink { [weak self] progress in
            Task { @MainActor in
                self?.processingProgress = progress
            }
        }.store(in: &cancellables)

        localFolderProcessor.$currentStatus.sink { [weak self] status in
            Task { @MainActor in
                if !status.isEmpty {
                    self?.processingStatus = status
                }
            }
        }.store(in: &cancellables)

        // Observe web crawler processor
        webCrawlerProcessor.$isProcessing.sink { [weak self] _ in
            Task { @MainActor in
                self?.updateProcessingState()
            }
        }.store(in: &cancellables)

        webCrawlerProcessor.$progress.sink { [weak self] progress in
            Task { @MainActor in
                self?.processingProgress = progress
            }
        }.store(in: &cancellables)

        webCrawlerProcessor.$currentStatus.sink { [weak self] status in
            Task { @MainActor in
                if !status.isEmpty {
                    self?.processingStatus = status
                }
            }
        }.store(in: &cancellables)

        // Observe enterprise API processor
        enterpriseAPIProcessor.$isProcessing.sink { [weak self] _ in
            Task { @MainActor in
                self?.updateProcessingState()
            }
        }.store(in: &cancellables)

        enterpriseAPIProcessor.$progress.sink { [weak self] progress in
            Task { @MainActor in
                self?.processingProgress = progress
            }
        }.store(in: &cancellables)

        enterpriseAPIProcessor.$currentStatus.sink { [weak self] status in
            Task { @MainActor in
                if !status.isEmpty {
                    self?.processingStatus = status
                }
            }
        }.store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    private func updateProcessingState() {
        // Update overall processing state based on individual processors
        let anyProcessing =
            localFolderProcessor.isProcessing || webCrawlerProcessor.isProcessing
            || enterpriseAPIProcessor.isProcessing

        if isProcessing != anyProcessing {
            isProcessing = anyProcessing
        }
    }

    private func validateKnowledgeBaseConfiguration(_ knowledgeBase: KnowledgeBase) throws {
        switch knowledgeBase.type {
        case .localFolder:
            guard let config = knowledgeBase.localFolderConfig else {
                throw ProcessingError.invalidConfiguration("本地文件夹配置缺失")
            }

            guard !config.folderPath.isEmpty else {
                throw ProcessingError.invalidConfiguration("文件夹路径不能为空")
            }

            guard FileManager.default.fileExists(atPath: config.folderPath) else {
                throw ProcessingError.folderNotFound("指定的文件夹不存在")
            }

        case .webSite:
            guard let config = knowledgeBase.webSiteConfig else {
                throw ProcessingError.invalidConfiguration("网站配置缺失")
            }

            guard !config.baseURL.isEmpty else {
                throw ProcessingError.invalidConfiguration("网站地址不能为空")
            }

            guard URL(string: config.baseURL) != nil else {
                throw ProcessingError.invalidConfiguration("无效的网站地址")
            }

        case .enterpriseAPI:
            guard let config = knowledgeBase.enterpriseAPIConfig else {
                throw ProcessingError.invalidConfiguration("企业API配置缺失")
            }

            guard !config.apiEndpoint.isEmpty else {
                throw ProcessingError.invalidConfiguration("API端点不能为空")
            }

            guard !config.apiKey.isEmpty else {
                throw ProcessingError.invalidConfiguration("API密钥不能为空")
            }

            guard URL(string: config.apiEndpoint) != nil else {
                throw ProcessingError.invalidConfiguration("无效的API端点地址")
            }
        }
    }

    private func testLocalFolderConnection(_ knowledgeBase: KnowledgeBase) async throws -> Bool {
        guard let config = knowledgeBase.localFolderConfig else {
            throw ProcessingError.invalidConfiguration("本地文件夹配置缺失")
        }

        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: config.folderPath, isDirectory: &isDirectory) else {
            throw ProcessingError.folderNotFound("文件夹不存在")
        }

        guard isDirectory.boolValue else {
            throw ProcessingError.invalidConfiguration("指定路径不是文件夹")
        }

        // 检查读取权限
        guard fileManager.isReadableFile(atPath: config.folderPath) else {
            throw ProcessingError.processingFailed("没有读取文件夹的权限")
        }

        return true
    }

    private func testWebSiteConnection(_ knowledgeBase: KnowledgeBase) async throws -> Bool {
        guard let config = knowledgeBase.webSiteConfig else {
            throw ProcessingError.invalidConfiguration("网站配置缺失")
        }

        guard let url = URL(string: config.baseURL) else {
            throw ProcessingError.invalidConfiguration("无效的网站地址")
        }

        let request = URLRequest(url: url, timeoutInterval: 10)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProcessingError.processingFailed("无效的响应")
            }

            guard 200...399 ~= httpResponse.statusCode else {
                throw ProcessingError.processingFailed("网站返回错误状态码: \(httpResponse.statusCode)")
            }

            return true

        } catch {
            throw ProcessingError.processingFailed("无法连接到网站: \(error.localizedDescription)")
        }
    }

    private func testEnterpriseAPIConnection(_ knowledgeBase: KnowledgeBase) async throws -> Bool {
        guard let config = knowledgeBase.enterpriseAPIConfig else {
            throw ProcessingError.invalidConfiguration("企业API配置缺失")
        }

        try await enterpriseAPIProcessor.testConnection(config)
        return true
    }

    private func vectorizeDocuments(_ documents: [Document], for knowledgeBase: KnowledgeBase)
        async throws
    {
        let totalDocuments = documents.count
        var processedDocuments = 0

        for document in documents {
            try await vectorDBManager.storeDocument(document, in: knowledgeBase)

            processedDocuments += 1
            processingProgress = 0.8 + (0.2 * Double(processedDocuments) / Double(totalDocuments))
        }
    }

    private func updateKnowledgeBaseStats(_ knowledgeBase: KnowledgeBase, result: ProcessingResult)
        async throws
    {
        // 更新知识库统计信息
        // 这个方法应该在KnowledgeBaseManager中实现

        // 发送通知以更新UI
        NotificationCenter.default.post(
            name: .knowledgeBaseUpdated,
            object: knowledgeBase,
            userInfo: [
                "result": result,
                "timestamp": Date(),
            ]
        )
    }
}

// MARK: - Vector Database Manager

@MainActor
class VectorDatabaseManager {
    private var databases: [String: SQLiteVectorDB] = [:]
    private let embeddingService = EmbeddingService.shared

    func getDatabase(for knowledgeBase: KnowledgeBase) -> SQLiteVectorDB {
        let kbId = knowledgeBase.id.uuidString

        if let existingDB = databases[kbId] {
            return existingDB
        }

        let dbPath = getDatabasePath(for: knowledgeBase)
        let vectorDB = SQLiteVectorDB(
            dbPath: dbPath,
            vectorDimension: embeddingService.getVectorDimension()
        )

        databases[kbId] = vectorDB
        return vectorDB
    }

    func storeDocument(_ document: Document, in knowledgeBase: KnowledgeBase) async throws {
        let vectorDB = getDatabase(for: knowledgeBase)

        // Create knowledge base entry if not exists
        try await vectorDB.createKnowledgeBase(knowledgeBase)

        // Generate embeddings for all chunks
        for chunk in document.chunks {
            if chunk.embedding == nil {
                let embedding = try await embeddingService.generateEmbedding(for: chunk.content)
                chunk.embedding = embedding
            }
        }

        // Store document with embeddings
        try await vectorDB.storeDocument(document, kbId: knowledgeBase.id.uuidString)
    }

    func getStats(for knowledgeBase: KnowledgeBase) async -> ProcessingStats? {
        let vectorDB = getDatabase(for: knowledgeBase)

        do {
            if let stats = try await vectorDB.getKnowledgeBaseStats(id: knowledgeBase.id.uuidString)
            {
                return ProcessingStats(
                    documentCount: stats.documentCount,
                    vectorCount: stats.vectorCount,
                    lastUpdated: stats.lastUpdated,
                    storageSize: try await vectorDB.getStorageSize()
                )
            }
        } catch {
            print("Failed to get stats for knowledge base \(knowledgeBase.name): \(error)")
        }

        return nil
    }

    func clearDatabase(for knowledgeBase: KnowledgeBase) async throws {
        let vectorDB = getDatabase(for: knowledgeBase)
        try await vectorDB.clearKnowledgeBase(id: knowledgeBase.id.uuidString)
    }

    func search(in knowledgeBase: KnowledgeBase, query: String, limit: Int) async throws
        -> [SearchResult]
    {
        let vectorDB = getDatabase(for: knowledgeBase)

        // Generate embedding for query
        let queryEmbedding = try await embeddingService.generateEmbedding(for: query)

        // Search similar vectors
        let results = try await vectorDB.searchSimilar(
            query: queryEmbedding,
            kbId: knowledgeBase.id.uuidString,
            limit: limit
        )

        // Convert to SearchResult format
        return results.map { result in
            SearchResult(
                id: result.chunkId,
                content: result.content,
                similarity: result.similarity,
                metadata: result.metadata
            )
        }
    }

    func vacuum(for knowledgeBase: KnowledgeBase) async throws {
        let vectorDB = getDatabase(for: knowledgeBase)
        try await vectorDB.vacuum()
    }

    private func getDatabasePath(for knowledgeBase: KnowledgeBase) -> String {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let kbDataDir =
            homeDirectory
            .appendingPathComponent(".ai_plugins_data")
            .appendingPathComponent("knowledge_bases")
            .appendingPathComponent("vectors")
            .appendingPathComponent(knowledgeBase.id.uuidString)

        // Create directory if needed
        try? FileManager.default.createDirectory(
            at: kbDataDir,
            withIntermediateDirectories: true
        )

        return kbDataDir.appendingPathComponent("vectors.db").path
    }
}

// MARK: - Supporting Types

struct ProcessingStats {
    let documentCount: Int
    let vectorCount: Int
    let lastUpdated: Date
    let storageSize: Int64  // 字节
}

struct SearchResult {
    let id: String
    let content: String
    let similarity: Float
    let metadata: [String: String]
}

// MARK: - Notifications

extension Notification.Name {
    static let knowledgeBaseUpdated = Notification.Name("KnowledgeBaseUpdated")
    static let knowledgeBaseProcessingStarted = Notification.Name("KnowledgeBaseProcessingStarted")
    static let knowledgeBaseProcessingCompleted = Notification.Name(
        "KnowledgeBaseProcessingCompleted")
    static let knowledgeBaseProcessingFailed = Notification.Name("KnowledgeBaseProcessingFailed")
}

// MARK: - Combine Support

extension KnowledgeBaseService {
    var processingPublisher: AnyPublisher<Bool, Never> {
        $isProcessing.eraseToAnyPublisher()
    }

    var progressPublisher: AnyPublisher<Double, Never> {
        $processingProgress.eraseToAnyPublisher()
    }

    var statusPublisher: AnyPublisher<String, Never> {
        $processingStatus.eraseToAnyPublisher()
    }
}
