import AppKit
import Foundation

// MARK: - Enterprise API Processing Service

@MainActor
class EnterpriseAPIProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var currentStatus = ""
    @Published var syncedDocuments = 0
    @Published var totalDocuments = 0
    @Published var currentBatch = 0

    private var processingTask: Task<Void, Never>?
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public Methods

    func processKnowledgeBase(_ knowledgeBase: KnowledgeBase) async throws -> ProcessingResult {
        guard let config = knowledgeBase.enterpriseAPIConfig else {
            throw ProcessingError.invalidConfiguration("企业API配置缺失")
        }

        guard URL(string: config.apiEndpoint) != nil else {
            throw ProcessingError.invalidConfiguration("无效的API端点地址")
        }

        guard !config.apiKey.isEmpty else {
            throw ProcessingError.invalidConfiguration("API密钥不能为空")
        }

        isProcessing = true
        progress = 0.0
        syncedDocuments = 0
        totalDocuments = 0
        currentBatch = 0
        currentStatus = NSLocalizedString("connecting_to_api", bundle: .module, comment: "")

        defer {
            isProcessing = false
            currentStatus = ""
        }

        do {
            // 1. 测试API连接
            try await testConnection(config)

            // 2. 获取文档总数
            currentStatus = NSLocalizedString(
                "fetching_document_count", bundle: .module, comment: "")
            totalDocuments = try await fetchDocumentCount(config)

            if totalDocuments == 0 {
                return ProcessingResult(
                    documents: [],
                    totalFiles: 0,
                    processedFiles: 0,
                    vectorCount: 0,
                    processingTime: Date()
                )
            }

            currentStatus = NSLocalizedString("syncing_documents", bundle: .module, comment: "")

            // 3. 批量获取文档
            var allDocuments: [Document] = []
            let batchSize = config.batchSize
            let totalBatches = (totalDocuments + batchSize - 1) / batchSize

            for batchIndex in 0..<totalBatches {
                try Task.checkCancellation()

                currentBatch = batchIndex + 1
                currentStatus = "正在同步第 \(currentBatch)/\(totalBatches) 批数据"

                let offset = batchIndex * batchSize
                let documents = try await fetchDocuments(config, offset: offset, limit: batchSize)

                allDocuments.append(contentsOf: documents)
                syncedDocuments = allDocuments.count
                progress = Double(syncedDocuments) / Double(totalDocuments)

                // 添加延迟避免过度请求
                if batchIndex < totalBatches - 1 {
                    try await Task.sleep(nanoseconds: 500_000_000)  // 0.5秒
                }
            }

            currentStatus = NSLocalizedString("completing_processing", bundle: .module, comment: "")

            return ProcessingResult(
                documents: allDocuments,
                totalFiles: totalDocuments,
                processedFiles: allDocuments.count,
                vectorCount: allDocuments.reduce(0) { $0 + $1.chunks.count },
                processingTime: Date()
            )

        } catch {
            if error is CancellationError {
                throw ProcessingError.cancelled
            }
            throw ProcessingError.processingFailed("API同步失败: \(error.localizedDescription)")
        }
    }

    func testConnection(_ config: EnterpriseAPIConfig) async throws {
        let testURL =
            URL(string: "\(config.apiEndpoint)/health")
            ?? URL(string: config.apiEndpoint)!

        var request = URLRequest(url: testURL)
        request.httpMethod = "GET"
        request.timeoutInterval = config.timeout

        // 添加认证头
        request.addValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        // 添加自定义头部
        for (key, value) in config.authHeaders {
            request.addValue(value, forHTTPHeaderField: key)
        }

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProcessingError.processingFailed("无效的服务器响应")
        }

        guard 200...299 ~= httpResponse.statusCode else {
            throw ProcessingError.processingFailed("连接测试失败，状态码: \(httpResponse.statusCode)")
        }
    }

    func cancelProcessing() {
        processingTask?.cancel()
        isProcessing = false
        currentStatus = NSLocalizedString("cancelled", bundle: .module, comment: "")
    }

    // MARK: - Private Methods

    private func fetchDocumentCount(_ config: EnterpriseAPIConfig) async throws -> Int {
        let countURL = URL(string: "\(config.apiEndpoint)/documents/count")!

        var request = URLRequest(url: countURL)
        request.httpMethod = "GET"
        request.timeoutInterval = config.timeout

        // 添加认证
        request.addValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        for (key, value) in config.authHeaders {
            request.addValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProcessingError.processingFailed("无效的响应")
        }

        guard httpResponse.statusCode == 200 else {
            throw ProcessingError.processingFailed("获取文档数量失败，状态码: \(httpResponse.statusCode)")
        }

        // 解析响应
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let count = json["count"] as? Int
        {
            return count
        }

        // 如果API不支持count端点，尝试获取第一页来估算
        return try await estimateDocumentCount(config)
    }

    private func estimateDocumentCount(_ config: EnterpriseAPIConfig) async throws -> Int {
        // 获取第一批文档来估算总数
        let documents = try await fetchDocuments(config, offset: 0, limit: config.batchSize)

        // 如果返回的文档数少于批次大小，说明这就是全部
        if documents.count < config.batchSize {
            return documents.count
        }

        // 否则假设有更多文档，返回一个合理的估算值
        return min(config.batchSize * 10, 1000)  // 最多假设有1000个文档
    }

    private func fetchDocuments(_ config: EnterpriseAPIConfig, offset: Int, limit: Int) async throws
        -> [Document]
    {
        let documentsURL = URL(string: "\(config.apiEndpoint)/documents")!
        var urlComponents = URLComponents(url: documentsURL, resolvingAgainstBaseURL: false)!

        urlComponents.queryItems = [
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "format", value: "json"),
        ]

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "GET"
        request.timeoutInterval = config.timeout

        // 添加认证
        request.addValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        for (key, value) in config.authHeaders {
            request.addValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProcessingError.processingFailed("无效的响应")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
            throw ProcessingError.processingFailed(
                "获取文档失败，状态码: \(httpResponse.statusCode)，错误: \(errorMessage)")
        }

        // 解析JSON响应
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProcessingError.processingFailed("无法解析JSON响应")
        }

        // 处理不同的响应格式
        let documentsData: [[String: Any]]

        if let documents = json["documents"] as? [[String: Any]] {
            documentsData = documents
        } else if let data = json["data"] as? [[String: Any]] {
            documentsData = data
        } else if let results = json["results"] as? [[String: Any]] {
            documentsData = results
        } else if let items = json["items"] as? [[String: Any]] {
            documentsData = items
        } else {
            // 如果是单个文档，包装成数组
            documentsData = [json]
        }

        // 转换为Document对象
        var documents: [Document] = []

        for (index, docData) in documentsData.enumerated() {
            if let document = try await parseDocument(docData, index: offset + index) {
                documents.append(document)
            }
        }

        return documents
    }

    private func parseDocument(_ data: [String: Any], index: Int) async throws -> Document? {
        // 提取必要字段
        guard
            let id = data["id"] as? String ?? data["_id"] as? String ?? data["document_id"]
                as? String
        else {
            print("文档缺少ID字段: \(data)")
            return nil
        }

        let title =
            data["title"] as? String
            ?? data["name"] as? String
            ?? data["filename"] as? String
            ?? "Document \(index + 1)"

        let content =
            data["content"] as? String
            ?? data["text"] as? String
            ?? data["body"] as? String
            ?? ""

        guard !content.isEmpty else {
            print("文档内容为空: \(id)")
            return nil
        }

        let source =
            data["source"] as? String
            ?? data["url"] as? String
            ?? data["path"] as? String
            ?? "Enterprise API"

        // 提取元数据
        var metadata: [String: String] = [
            "document_id": id,
            "title": title,
            "source": source,
            "synced_at": ISO8601DateFormatter().string(from: Date()),
            "batch_index": "\(index)",
        ]

        // 添加其他可用的元数据
        for (key, value) in data {
            if let stringValue = value as? String {
                metadata["api_\(key)"] = stringValue
            } else if let numberValue = value as? NSNumber {
                metadata["api_\(key)"] = numberValue.stringValue
            }
        }

        // 确定文档类型
        let documentType = determineDocumentType(from: data)

        // 创建文档
        let document = Document(
            id: id,
            title: title,
            content: content,
            source: source,
            type: documentType,
            metadata: metadata
        )

        // 将内容分块
        let chunks = await chunkContent(content, maxChunkSize: 1000, overlap: 100)
        document.chunks = chunks.enumerated().map { chunkIndex, chunk in
            DocumentChunk(
                id: "\(document.id)_\(chunkIndex)",
                documentId: document.id,
                content: chunk,
                chunkIndex: chunkIndex,
                metadata: document.metadata
            )
        }

        return document
    }

    private func determineDocumentType(from data: [String: Any]) -> DocumentType {
        // 尝试从多个字段推断文档类型
        if let type = data["type"] as? String ?? data["content_type"] as? String ?? data["format"]
            as? String
        {
            switch type.lowercased() {
            case "markdown", "md":
                return .markdown
            case "pdf":
                return .pdf
            case "html", "htm":
                return .html
            case "rtf":
                return .rtf
            default:
                return .text
            }
        }

        // 从文件扩展名推断
        if let filename = data["filename"] as? String ?? data["name"] as? String {
            let ext = (filename as NSString).pathExtension.lowercased()
            switch ext {
            case "md", "markdown":
                return .markdown
            case "pdf":
                return .pdf
            case "html", "htm":
                return .html
            case "rtf":
                return .rtf
            default:
                return .text
            }
        }

        return .text
    }

    private func chunkContent(_ content: String, maxChunkSize: Int, overlap: Int) async -> [String]
    {
        let sentences = content.components(separatedBy: CharacterSet(charactersIn: ".!?。！？\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var chunks: [String] = []
        var currentChunk = ""

        for sentence in sentences {
            let potentialChunk = currentChunk.isEmpty ? sentence : currentChunk + ". " + sentence

            if potentialChunk.count <= maxChunkSize {
                currentChunk = potentialChunk
            } else {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk)

                    // 添加重叠内容
                    if overlap > 0 && currentChunk.count > overlap {
                        let startIndex = currentChunk.index(
                            currentChunk.endIndex, offsetBy: -overlap)
                        currentChunk = String(currentChunk[startIndex...])
                    } else {
                        currentChunk = ""
                    }
                }

                // 如果单个句子就超过了最大长度，直接分割
                if sentence.count > maxChunkSize {
                    let subChunks = sentence.chunked(into: maxChunkSize)
                    chunks.append(contentsOf: subChunks)
                } else {
                    currentChunk = currentChunk.isEmpty ? sentence : currentChunk + ". " + sentence
                }
            }
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }

        return chunks.filter { !$0.isEmpty }
    }
}

// MARK: - API Response Models

struct APIDocumentResponse: Codable {
    let documents: [APIDocument]?
    let data: [APIDocument]?
    let results: [APIDocument]?
    let items: [APIDocument]?
    let count: Int?
    let total: Int?
    let hasMore: Bool?
}

struct APIDocument: Codable {
    let id: String?
    let documentId: String?
    let title: String?
    let name: String?
    let content: String?
    let text: String?
    let body: String?
    let source: String?
    let url: String?
    let type: String?
    let contentType: String?
    let filename: String?
    let createdAt: String?
    let updatedAt: String?

    private enum CodingKeys: String, CodingKey {
        case id, title, name, content, text, body, source, url, type, filename
        case documentId = "document_id"
        case contentType = "content_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct APICountResponse: Codable {
    let count: Int
    let total: Int?
}

struct APIErrorResponse: Codable {
    let error: String?
    let message: String?
    let details: String?
}
