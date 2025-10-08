import AppKit
import Foundation
import Network

// MARK: - Web Crawler Processing Service

@MainActor
class WebCrawlerProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var currentStatus = ""
    @Published var crawledPages = 0
    @Published var totalPages = 0
    @Published var currentURL = ""

    private var processingTask: Task<Void, Never>?
    private var visitedURLs: Set<String> = []
    private var urlQueue: [CrawlURL] = []
    private let session = URLSession.shared

    // MARK: - Public Methods

    func processKnowledgeBase(_ knowledgeBase: KnowledgeBase) async throws -> ProcessingResult {
        guard let config = knowledgeBase.webSiteConfig else {
            throw ProcessingError.invalidConfiguration("网站配置缺失")
        }

        guard let baseURL = URL(string: config.baseURL) else {
            throw ProcessingError.invalidConfiguration("无效的网站地址")
        }

        // 检查网络连接
        guard await isNetworkAvailable() else {
            throw ProcessingError.processingFailed("无网络连接")
        }

        isProcessing = true
        progress = 0.0
        crawledPages = 0
        totalPages = 0
        currentURL = ""
        currentStatus = NSLocalizedString("initializing_crawler", bundle: .module, comment: "")

        visitedURLs.removeAll()
        urlQueue.removeAll()

        defer {
            isProcessing = false
            currentStatus = ""
            currentURL = ""
        }

        do {
            // 1. 检查robots.txt
            if config.respectRobotsTxt {
                currentStatus = NSLocalizedString("checking_robots", bundle: .module, comment: "")
                let robotsChecker = RobotsChecker(baseURL: baseURL)
                if !(await robotsChecker.canCrawl(baseURL.absoluteString)) {
                    throw ProcessingError.processingFailed("robots.txt 禁止爬取此网站")
                }
            }

            // 2. 初始化爬取队列
            urlQueue.append(CrawlURL(url: baseURL, depth: 0))
            totalPages = min(config.maxPages, 1000)  // 设置合理上限

            currentStatus = NSLocalizedString("crawling_website", bundle: .module, comment: "")

            // 3. 开始爬取
            var documents: [Document] = []

            while !urlQueue.isEmpty && crawledPages < config.maxPages {
                try Task.checkCancellation()

                let crawlURL = urlQueue.removeFirst()

                // 跳过已访问的URL
                if visitedURLs.contains(crawlURL.url.absoluteString) {
                    continue
                }

                currentURL = crawlURL.url.absoluteString
                currentStatus = "正在爬取: \(crawlURL.url.host ?? "")"

                do {
                    if let document = try await crawlPage(crawlURL, config: config) {
                        documents.append(document)
                    }

                    visitedURLs.insert(crawlURL.url.absoluteString)
                    crawledPages += 1
                    progress = Double(crawledPages) / Double(min(totalPages, config.maxPages))

                    // 添加延迟以避免过度请求
                    try await Task.sleep(nanoseconds: 1_000_000_000)  // 1秒

                } catch {
                    print("爬取页面失败 \(crawlURL.url): \(error)")
                }
            }

            currentStatus = NSLocalizedString("completing_processing", bundle: .module, comment: "")

            return ProcessingResult(
                documents: documents,
                totalFiles: crawledPages,
                processedFiles: documents.count,
                vectorCount: documents.reduce(0) { $0 + $1.chunks.count },
                processingTime: Date()
            )

        } catch {
            throw ProcessingError.processingFailed("爬取失败: \(error.localizedDescription)")
        }
    }

    func cancelProcessing() {
        processingTask?.cancel()
        isProcessing = false
        currentStatus = NSLocalizedString("cancelled", bundle: .module, comment: "")
    }

    // MARK: - Private Methods

    private func isNetworkAvailable() async -> Bool {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")

        return await withCheckedContinuation { continuation in
            monitor.pathUpdateHandler = { path in
                continuation.resume(returning: path.status == .satisfied)
                monitor.cancel()
            }
            monitor.start(queue: queue)
        }
    }

    private func crawlPage(_ crawlURL: CrawlURL, config: WebSiteConfig) async throws -> Document? {
        let request = URLRequest(url: crawlURL.url, timeoutInterval: 30)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProcessingError.processingFailed("无效的响应")
        }

        guard httpResponse.statusCode == 200 else {
            throw ProcessingError.processingFailed("HTTP错误: \(httpResponse.statusCode)")
        }

        // 检查内容类型
        guard let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
            contentType.lowercased().contains("text/html")
        else {
            return nil  // 跳过非HTML内容
        }

        guard let htmlContent = String(data: data, encoding: .utf8) else {
            return nil  // 无法解码内容
        }

        // 提取页面内容
        let pageContent = extractContent(from: htmlContent)
        guard !pageContent.title.isEmpty && !pageContent.text.isEmpty else {
            return nil  // 跳过空内容
        }

        // 提取链接并添加到队列
        if crawlURL.depth < config.crawlDepth {
            let links = extractLinks(from: htmlContent, baseURL: crawlURL.url)
            let filteredLinks = filterLinks(links, config: config, baseURL: crawlURL.url)

            for link in filteredLinks {
                if !visitedURLs.contains(link.absoluteString)
                    && !urlQueue.contains(where: { $0.url.absoluteString == link.absoluteString })
                {
                    urlQueue.append(CrawlURL(url: link, depth: crawlURL.depth + 1))
                }
            }
        }

        // 创建文档
        let document = Document(
            id: UUID().uuidString,
            title: pageContent.title,
            content: pageContent.text,
            source: crawlURL.url.absoluteString,
            type: .html,
            metadata: [
                "url": crawlURL.url.absoluteString,
                "title": pageContent.title,
                "depth": "\(crawlURL.depth)",
                "content_type": contentType,
                "crawled_at": ISO8601DateFormatter().string(from: Date()),
            ]
        )

        // 将内容分块
        let chunks = await chunkContent(pageContent.text, maxChunkSize: 1000, overlap: 100)
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
    }

    private func extractContent(from html: String) -> (title: String, text: String) {
        // 简单的HTML内容提取（实际项目中应使用专门的HTML解析库）
        var title = ""
        var text = ""

        // 提取标题
        if let titleRange = html.range(of: "<title>(.*?)</title>", options: .regularExpression) {
            let titleHTML = String(html[titleRange])
            title = titleHTML.replacingOccurrences(
                of: "<[^>]*>", with: "", options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 移除script和style标签
        var cleanHTML = html.replacingOccurrences(
            of: "<script[^>]*>.*?</script>",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        cleanHTML = cleanHTML.replacingOccurrences(
            of: "<style[^>]*>.*?</style>",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // 移除HTML标签
        text = cleanHTML.replacingOccurrences(of: "<[^>]*>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (title: title, text: text)
    }

    private func extractLinks(from html: String, baseURL: URL) -> [URL] {
        var links: [URL] = []

        // 使用正则表达式提取链接
        let linkPattern = "<a[^>]*href\\s*=\\s*[\"']([^\"']*)[\"'][^>]*>"

        do {
            let regex = try NSRegularExpression(pattern: linkPattern, options: .caseInsensitive)
            let matches = regex.matches(
                in: html, options: [], range: NSRange(location: 0, length: html.count))

            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    let href = String(html[range])

                    // 处理相对链接
                    if let url = URL(string: href, relativeTo: baseURL) {
                        links.append(url)
                    }
                }
            }
        } catch {
            print("链接提取错误: \(error)")
        }

        return links
    }

    private func filterLinks(_ links: [URL], config: WebSiteConfig, baseURL: URL) -> [URL] {
        return links.filter { link in
            // 只爬取同域名的链接
            guard link.host == baseURL.host else { return false }

            // 跳过锚点链接
            guard link.fragment == nil || link.fragment!.isEmpty else { return false }

            // 应用包含和排除模式
            let urlString = link.absoluteString

            // 检查排除模式
            for pattern in config.excludePatterns {
                if urlString.contains(pattern) {
                    return false
                }
            }

            // 检查包含模式（如果指定了）
            if !config.includePatterns.isEmpty {
                let matches = config.includePatterns.contains { pattern in
                    urlString.contains(pattern)
                }
                if !matches {
                    return false
                }
            }

            return true
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

struct CrawlURL {
    let url: URL
    let depth: Int
}

// MARK: - Robots.txt Checker

class RobotsChecker {
    private let baseURL: URL
    private var robotsRules: [String] = []

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func canCrawl(_ urlString: String) async -> Bool {
        if robotsRules.isEmpty {
            await loadRobotsTxt()
        }

        // 简单的robots.txt检查实现
        // 实际项目中应使用更完整的robots.txt解析器
        guard let url = URL(string: urlString) else { return false }
        let path = url.path

        for rule in robotsRules {
            if rule.lowercased().contains("disallow:") {
                let disallowedPath = rule.replacingOccurrences(of: "disallow:", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if path.hasPrefix(disallowedPath) {
                    return false
                }
            }
        }

        return true
    }

    private func loadRobotsTxt() async {
        guard let robotsURL = URL(string: "/robots.txt", relativeTo: baseURL) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: robotsURL)
            if let robotsContent = String(data: data, encoding: .utf8) {
                robotsRules = robotsContent.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            }
        } catch {
            print("无法加载robots.txt: \(error)")
        }
    }
}
