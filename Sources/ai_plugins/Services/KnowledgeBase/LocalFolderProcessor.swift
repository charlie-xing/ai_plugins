import AppKit
import Foundation

// MARK: - Local Folder Processing Service

@MainActor
class LocalFolderProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var currentStatus = ""
    @Published var processedFiles = 0
    @Published var totalFiles = 0

    private var processingTask: Task<Void, Never>?

    // MARK: - Public Methods

    func processKnowledgeBase(_ knowledgeBase: KnowledgeBase) async throws -> ProcessingResult {
        guard let config = knowledgeBase.localFolderConfig else {
            throw ProcessingError.invalidConfiguration("本地文件夹配置缺失")
        }

        guard FileManager.default.fileExists(atPath: config.folderPath) else {
            throw ProcessingError.folderNotFound("指定的文件夹不存在：\(config.folderPath)")
        }

        isProcessing = true
        progress = 0.0
        processedFiles = 0
        totalFiles = 0
        currentStatus = NSLocalizedString("scanning_folder", bundle: .module, comment: "")

        defer {
            isProcessing = false
            currentStatus = ""
        }

        do {
            // 1. 扫描文件夹获取所有支持的文件
            let files = try await scanFolder(
                path: config.folderPath,
                includeSubfolders: config.includeSubfolders,
                extensions: config.supportedExtensions,
                maxFileSize: config.maxFileSize
            )

            totalFiles = files.count
            currentStatus = NSLocalizedString("processing_files", bundle: .module, comment: "")

            // 2. 处理文件并提取内容
            var documents: [Document] = []

            for (index, file) in files.enumerated() {
                try Task.checkCancellation()

                currentStatus = "正在处理: \(file.lastPathComponent)"

                if let document = try await processFile(file, maxSize: config.maxFileSize) {
                    documents.append(document)
                }

                processedFiles = index + 1
                progress = Double(processedFiles) / Double(totalFiles)

                // 给UI更新的时间
                try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
            }

            currentStatus = NSLocalizedString("completing_processing", bundle: .module, comment: "")

            return ProcessingResult(
                documents: documents,
                totalFiles: files.count,
                processedFiles: documents.count,
                vectorCount: documents.reduce(0) { $0 + $1.chunks.count },
                processingTime: Date()
            )

        } catch {
            throw ProcessingError.processingFailed("处理失败: \(error.localizedDescription)")
        }
    }

    func cancelProcessing() {
        processingTask?.cancel()
        isProcessing = false
        currentStatus = NSLocalizedString("cancelled", bundle: .module, comment: "")
    }

    // MARK: - Private Methods

    private func scanFolder(
        path: String,
        includeSubfolders: Bool,
        extensions: [String],
        maxFileSize: Int
    ) async throws -> [URL] {
        let url = URL(fileURLWithPath: path)

        // Collect all candidate URLs synchronously
        let candidateURLs = try collectURLs(from: url, includeSubfolders: includeSubfolders)

        var validFiles: [URL] = []

        // Then filter them asynchronously
        for fileURL in candidateURLs {
            if try await shouldIncludeFile(
                fileURL, extensions: extensions, maxSize: maxFileSize)
            {
                validFiles.append(fileURL)
            }
        }

        return validFiles
    }

    private func collectURLs(from baseURL: URL, includeSubfolders: Bool) throws -> [URL] {
        let fileManager = FileManager.default
        var allURLs: [URL] = []

        let resourceKeys: [URLResourceKey] = [
            .isRegularFileKey,
            .isDirectoryKey,
            .fileSizeKey,
            .nameKey,
        ]

        if includeSubfolders {
            // Use recursive directory enumeration
            guard
                let enumerator = fileManager.enumerator(
                    at: baseURL,
                    includingPropertiesForKeys: resourceKeys,
                    options: [.skipsHiddenFiles],
                    errorHandler: { url, error in
                        print("扫描错误 \(url): \(error)")
                        return true
                    }
                )
            else {
                throw ProcessingError.processingFailed("无法创建目录枚举器")
            }

            // Collect all URLs synchronously
            while let fileURL = enumerator.nextObject() as? URL {
                allURLs.append(fileURL)
            }
        } else {
            // Only scan current folder
            let contents = try fileManager.contentsOfDirectory(
                at: baseURL,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            )
            allURLs = contents
        }

        return allURLs.sorted { $0.path < $1.path }
    }

    private func shouldIncludeFile(_ url: URL, extensions: [String], maxSize: Int) async throws
        -> Bool
    {
        let resourceValues = try url.resourceValues(forKeys: [
            .isRegularFileKey,
            .isDirectoryKey,
            .fileSizeKey,
        ])

        // 跳过目录
        guard resourceValues.isRegularFile == true else {
            return false
        }

        // 检查文件扩展名
        let fileExtension = url.pathExtension.lowercased()
        guard extensions.contains(fileExtension) else {
            return false
        }

        // 检查文件大小
        if let fileSize = resourceValues.fileSize, fileSize > maxSize {
            return false
        }

        return true
    }

    private func processFile(_ url: URL, maxSize: Int) async throws -> Document? {
        do {
            let data = try Data(contentsOf: url)

            // 检查文件大小
            if data.count > maxSize {
                print("跳过过大文件: \(url.path)")
                return nil
            }

            // 尝试解码为文本
            guard let content = String(data: data, encoding: .utf8) else {
                print("无法解码文件: \(url.path)")
                return nil
            }

            // 过滤空文件
            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedContent.isEmpty {
                return nil
            }

            // 创建文档并分块
            let document = Document(
                id: UUID().uuidString,
                title: url.lastPathComponent,
                content: content,
                source: url.path,
                type: getDocumentType(from: url.pathExtension),
                metadata: [
                    "file_path": url.path,
                    "file_name": url.lastPathComponent,
                    "file_size": "\(data.count)",
                    "file_extension": url.pathExtension,
                    "created_at": ISO8601DateFormatter().string(from: Date()),
                ]
            )

            // 将内容分块
            let chunks = await chunkContent(content, maxChunkSize: 1000, overlap: 100)
            document.chunks = chunks.enumerated().map { index, chunk in
                DocumentChunk(
                    id: "\(document.id)_\(index)",
                    documentId: document.id,
                    content: chunk,
                    chunkIndex: index,
                    metadata: document.metadata
                )
            }

            return document

        } catch {
            print("处理文件错误 \(url.path): \(error)")
            return nil
        }
    }

    private func getDocumentType(from extension: String) -> DocumentType {
        switch `extension`.lowercased() {
        case "md", "markdown":
            return .markdown
        case "txt":
            return .text
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

// MARK: - Supporting Types

struct ProcessingResult {
    let documents: [Document]
    let totalFiles: Int
    let processedFiles: Int
    let vectorCount: Int
    let processingTime: Date
}

class Document: ObservableObject {
    let id: String
    let title: String
    let content: String
    let source: String
    let type: DocumentType
    let metadata: [String: String]
    var chunks: [DocumentChunk] = []

    init(
        id: String,
        title: String,
        content: String,
        source: String,
        type: DocumentType,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.source = source
        self.type = type
        self.metadata = metadata
    }
}

struct DocumentChunk {
    let id: String
    let documentId: String
    let content: String
    let chunkIndex: Int
    let metadata: [String: String]
    var embedding: [Float]?
}

enum DocumentType: String, CaseIterable {
    case text = "text"
    case markdown = "markdown"
    case pdf = "pdf"
    case html = "html"
    case rtf = "rtf"

    var icon: String {
        switch self {
        case .text:
            return "doc.text"
        case .markdown:
            return "doc.richtext"
        case .pdf:
            return "doc.text.fill"
        case .html:
            return "safari"
        case .rtf:
            return "doc.richtext.fill"
        }
    }
}

enum ProcessingError: LocalizedError {
    case invalidConfiguration(String)
    case folderNotFound(String)
    case processingFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let message):
            return "配置错误: \(message)"
        case .folderNotFound(let message):
            return "文件夹未找到: \(message)"
        case .processingFailed(let message):
            return "处理失败: \(message)"
        case .cancelled:
            return "处理已取消"
        }
    }
}

// MARK: - String Extension

extension String {
    func chunked(into size: Int) -> [String] {
        var chunks: [String] = []
        var startIndex = self.startIndex

        while startIndex < self.endIndex {
            let endIndex =
                self.index(startIndex, offsetBy: size, limitedBy: self.endIndex) ?? self.endIndex
            chunks.append(String(self[startIndex..<endIndex]))
            startIndex = endIndex
        }

        return chunks
    }
}
