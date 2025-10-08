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
        let totalChunks = documents.reduce(0) { $0 + $1.chunks.count }
        var processedChunks = 0

        for document in documents {
            for chunk in document.chunks {
                // 这里应该调用实际的向量化服务
                // 现在我们使用模拟的向量化
                let embedding = try await generateEmbedding(for: chunk.content)

                // 存储向量
                try await vectorDBManager.storeVector(
                    id: chunk.id,
                    embedding: embedding,
                    content: chunk.content,
                    metadata: chunk.metadata,
                    in: knowledgeBase
                )

                processedChunks += 1
                processingProgress = 0.8 + (0.2 * Double(processedChunks) / Double(totalChunks))
            }
        }
    }

    private func generateEmbedding(for text: String) async throws -> [Float] {
        // 这里应该调用实际的向量化服务，比如OpenAI的embedding API
        // 现在返回模拟的向量

        // 模拟API调用延迟
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1秒

        // 返回随机向量作为占位符（实际应该是1536维度的向量）
        return (0..<384).map { _ in Float.random(in: -1...1) }
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

    func storeVector(
        id: String,
        embedding: [Float],
        content: String,
        metadata: [String: String],
        in knowledgeBase: KnowledgeBase
    ) async throws {
        // 实现向量存储逻辑
        // 这里可以使用SQLite、Core Data或专门的向量数据库

        // 现在只是打印日志
        print("存储向量: \(id) 在知识库 \(knowledgeBase.name)")
    }

    func getStats(for knowledgeBase: KnowledgeBase) async -> ProcessingStats? {
        // 返回知识库的统计信息
        return ProcessingStats(
            documentCount: 0,
            vectorCount: 0,
            lastUpdated: Date(),
            storageSize: 0
        )
    }

    func clearDatabase(for knowledgeBase: KnowledgeBase) async throws {
        // 清除知识库的所有向量数据
        print("清除知识库数据: \(knowledgeBase.name)")
    }

    func search(in knowledgeBase: KnowledgeBase, query: String, limit: Int) async throws
        -> [SearchResult]
    {
        // 实现向量搜索逻辑
        return []
    }
}

// MARK: - Supporting Types

struct ProcessingStats {
    let documentCount: Int
    let vectorCount: Int
    let lastUpdated: Date
    let storageSize: Int  // 字节
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
