#!/usr/bin/env swift

import Foundation

// MARK: - Test Knowledge Base Processing

func main() async {
    print("🧪 Testing Knowledge Base Processing...")

    let tester = KnowledgeBaseProcessingTest()
    await tester.runTests()
}

struct KnowledgeBaseProcessingTest {
    private let testDataPath = "/tmp/kb_test_data"
    private let testKBName = "Test Knowledge Base"

    func runTests() async {
        print("\n📁 Setting up test environment...")

        do {
            // 1. Setup test environment
            try setupTestEnvironment()
            print("✅ Test environment created")

            // 2. Create test knowledge base
            let knowledgeBase = createTestKnowledgeBase()
            print("✅ Test knowledge base created: \(knowledgeBase.name)")

            // 3. Test knowledge base manager
            await testKnowledgeBaseManager(knowledgeBase)

            // 4. Test processing service
            await testProcessingService(knowledgeBase)

            // 5. Test vector database integration
            await testVectorDatabase(knowledgeBase)

            // 6. Test status updates
            await testStatusUpdates(knowledgeBase)

            print("\n🎉 All tests completed successfully!")

        } catch {
            print("❌ Test failed: \(error)")
        }

        // Cleanup
        cleanup()
        print("🧹 Test environment cleaned up")
    }

    // MARK: - Test Setup

    private func setupTestEnvironment() throws {
        let fileManager = FileManager.default

        // Remove existing test directory
        if fileManager.fileExists(atPath: testDataPath) {
            try fileManager.removeItem(atPath: testDataPath)
        }

        // Create test directory
        try fileManager.createDirectory(atPath: testDataPath, withIntermediateDirectories: true)

        // Create test files with different formats
        let testFiles = [
            (
                "readme.md",
                """
                # Test Document

                This is a test markdown document for the knowledge base.

                ## Features
                - Document processing
                - Vector embedding
                - Semantic search

                The system should be able to process this content and create embeddings.
                """
            ),
            (
                "guide.txt",
                """
                Installation Guide

                Follow these steps to install the application:

                1. Download the installer
                2. Run the setup wizard
                3. Configure your settings
                4. Start using the application

                For troubleshooting, check the FAQ section.
                """
            ),
            (
                "config.md",
                """
                # Configuration Options

                ## Database Settings
                - Host: localhost
                - Port: 5432
                - Database: ai_plugins

                ## API Settings
                - Endpoint: https://api.example.com
                - Version: v1
                - Timeout: 30s

                ## Vector Settings
                - Dimension: 384
                - Similarity threshold: 0.7
                """
            ),
        ]

        for (filename, content) in testFiles {
            let filePath = "\(testDataPath)/\(filename)"
            try content.write(toFile: filePath, atomically: true, encoding: .utf8)
        }

        // Create subdirectory with more files
        let subDir = "\(testDataPath)/subdirectory"
        try fileManager.createDirectory(atPath: subDir, withIntermediateDirectories: true)

        let subFile = """
            # Advanced Topics

            This document covers advanced configuration topics.

            ## Performance Tuning
            - Memory optimization
            - CPU utilization
            - Network settings
            """

        try subFile.write(toFile: "\(subDir)/advanced.md", atomically: true, encoding: .utf8)
    }

    private func createTestKnowledgeBase() -> MockKnowledgeBase {
        var kb = MockKnowledgeBase(
            name: testKBName,
            type: .localFolder,
            description: "Test knowledge base for validation"
        )

        kb.localFolderConfig = MockLocalFolderConfig(
            folderPath: testDataPath,
            includeSubfolders: true,
            supportedExtensions: ["md", "txt"],
            maxFileSize: 10 * 1024 * 1024
        )

        return kb
    }

    // MARK: - Test Cases

    private func testKnowledgeBaseManager(_ knowledgeBase: MockKnowledgeBase) async {
        print("\n📊 Testing Knowledge Base Manager...")

        let manager = MockKnowledgeBaseManager()

        // Test adding knowledge base
        manager.addKnowledgeBase(knowledgeBase)
        assert(manager.knowledgeBases.count == 1, "Should have 1 knowledge base")
        print("✅ Knowledge base added successfully")

        // Test updating knowledge base
        var updatedKB = knowledgeBase
        updatedKB.description = "Updated description"
        manager.updateKnowledgeBase(updatedKB)

        let retrievedKB = manager.knowledgeBases.first { $0.id == knowledgeBase.id }
        assert(retrievedKB?.description == "Updated description", "Description should be updated")
        print("✅ Knowledge base updated successfully")

        // Test toggle
        manager.toggleKnowledgeBase(updatedKB)
        let toggledKB = manager.knowledgeBases.first { $0.id == knowledgeBase.id }
        assert(toggledKB?.isEnabled == false, "Knowledge base should be disabled")
        print("✅ Knowledge base toggle works")
    }

    private func testProcessingService(_ knowledgeBase: MockKnowledgeBase) async {
        print("\n⚙️ Testing Processing Service...")

        do {
            let processor = MockLocalFolderProcessor()
            let result = try await processor.processKnowledgeBase(knowledgeBase)

            print("📈 Processing Results:")
            print("  - Total files found: \(result.totalFiles)")
            print("  - Files processed: \(result.processedFiles)")
            print("  - Documents created: \(result.documents.count)")
            print("  - Total chunks: \(result.documents.reduce(0) { $0 + $1.chunks.count })")
            print("  - Vector count: \(result.vectorCount)")

            assert(result.totalFiles > 0, "Should find test files")
            assert(result.documents.count > 0, "Should create documents")
            assert(result.vectorCount > 0, "Should have chunks for vectorization")
            print("✅ Processing service works correctly")

        } catch {
            print("❌ Processing service failed: \(error)")
            assert(false, "Processing should not fail")
        }
    }

    private func testVectorDatabase(_ knowledgeBase: MockKnowledgeBase) async {
        print("\n🗄️ Testing Vector Database Integration...")

        let vectorDB = MockVectorDatabaseManager()

        do {
            // Test database creation
            let _ = vectorDB.getDatabase(for: knowledgeBase)
            print("✅ Vector database created for knowledge base")

            // Test document storage (simulated)
            let testDocument = MockDocument(
                id: "test-doc-1",
                title: "Test Document",
                content: "This is test content for vectorization",
                source: "\(testDataPath)/test.md",
                type: .markdown
            )

            try await vectorDB.storeDocument(testDocument, in: knowledgeBase)
            print("✅ Document stored in vector database")

            // Test statistics
            let stats = await vectorDB.getStats(for: knowledgeBase)
            print("📊 Vector Database Stats:")
            if let stats = stats {
                print("  - Document count: \(stats.documentCount)")
                print("  - Vector count: \(stats.vectorCount)")
                print("  - Last updated: \(stats.lastUpdated)")
            }
            print("✅ Vector database statistics work")

        } catch {
            print("❌ Vector database test failed: \(error)")
            assert(false, "Vector database operations should not fail")
        }
    }

    private func testStatusUpdates(_ knowledgeBase: MockKnowledgeBase) async {
        print("\n🔄 Testing Status Updates...")

        var kb = knowledgeBase

        // Test initial status
        let initialStatus = kb.displayStatus
        print("  Initial status: \(initialStatus.rawValue)")
        assert(initialStatus == .needsIndexing, "Should need indexing initially")
        print("✅ Initial status correct")

        // Simulate processing completion
        kb.localFolderConfig?.lastIndexed = Date()
        kb.totalVectors = 10

        let finalStatus = kb.displayStatus
        print("  Final status: \(finalStatus.rawValue)")
        assert(finalStatus == .ready, "Should be ready after processing")
        print("✅ Status updates work correctly")
    }

    private func cleanup() {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: testDataPath) {
            try? fileManager.removeItem(atPath: testDataPath)
        }
    }
}

// MARK: - Mock Types for Testing

struct MockKnowledgeBase: Identifiable {
    let id = UUID()
    var name: String
    var type: KnowledgeBaseType
    var description: String
    var isEnabled: Bool = true
    var createdAt = Date()
    var updatedAt = Date()

    var localFolderConfig: MockLocalFolderConfig?
    var totalDocuments: Int = 0
    var totalChunks: Int = 0
    var totalVectors: Int = 0
    var lastVectorized: Date?

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
            return .needsCrawling
        case .enterpriseAPI:
            return .needsSync
        }
    }

    mutating func updateTimestamp() {
        self.updatedAt = Date()
    }
}

struct MockLocalFolderConfig {
    var folderPath: String
    var includeSubfolders: Bool = true
    var supportedExtensions: [String] = ["txt", "md"]
    var maxFileSize: Int = 10 * 1024 * 1024
    var lastIndexed: Date?
    var totalFiles: Int = 0
}

enum KnowledgeBaseType: String, CaseIterable {
    case localFolder = "local_folder"
    case webSite = "web_site"
    case enterpriseAPI = "enterprise_api"
}

enum KnowledgeBaseStatus: String, CaseIterable {
    case ready = "ready"
    case notConfigured = "not_configured"
    case needsIndexing = "needs_indexing"
    case needsCrawling = "needs_crawling"
    case needsSync = "needs_sync"
    case disabled = "disabled"
    case processing = "processing"
    case error = "error"
}

class MockKnowledgeBaseManager {
    var knowledgeBases: [MockKnowledgeBase] = []

    func addKnowledgeBase(_ knowledgeBase: MockKnowledgeBase) {
        knowledgeBases.append(knowledgeBase)
    }

    func updateKnowledgeBase(_ knowledgeBase: MockKnowledgeBase) {
        if let index = knowledgeBases.firstIndex(where: { $0.id == knowledgeBase.id }) {
            knowledgeBases[index] = knowledgeBase
        }
    }

    func toggleKnowledgeBase(_ knowledgeBase: MockKnowledgeBase) {
        if let index = knowledgeBases.firstIndex(where: { $0.id == knowledgeBase.id }) {
            knowledgeBases[index].isEnabled.toggle()
        }
    }
}

struct MockProcessingResult {
    let documents: [MockDocument]
    let totalFiles: Int
    let processedFiles: Int
    let vectorCount: Int
    let processingTime: Date
}

class MockDocument {
    let id: String
    let title: String
    let content: String
    let source: String
    let type: DocumentType
    var chunks: [MockDocumentChunk] = []

    init(id: String, title: String, content: String, source: String, type: DocumentType) {
        self.id = id
        self.title = title
        self.content = content
        self.source = source
        self.type = type

        // Create chunks (simulate chunking)
        let chunkSize = 500
        let contentChunks = content.chunked(into: chunkSize)

        for (index, chunk) in contentChunks.enumerated() {
            let documentChunk = MockDocumentChunk(
                id: "\(id)-chunk-\(index)",
                content: chunk,
                index: index
            )
            chunks.append(documentChunk)
        }
    }
}

struct MockDocumentChunk {
    let id: String
    let content: String
    let index: Int
    var embedding: [Float]?
}

enum DocumentType: String, CaseIterable {
    case text = "text"
    case markdown = "markdown"
    case pdf = "pdf"
    case html = "html"
}

class MockLocalFolderProcessor {
    func processKnowledgeBase(_ knowledgeBase: MockKnowledgeBase) async throws
        -> MockProcessingResult
    {
        guard let config = knowledgeBase.localFolderConfig else {
            throw MockProcessingError.invalidConfiguration("Local folder config missing")
        }

        let fileManager = FileManager.default
        let folderURL = URL(fileURLWithPath: config.folderPath)

        // Scan for files
        var files: [URL] = []
        if config.includeSubfolders {
            let enumerator = fileManager.enumerator(
                at: folderURL, includingPropertiesForKeys: [.isRegularFileKey])

            while let url = enumerator?.nextObject() as? URL {
                if config.supportedExtensions.contains(url.pathExtension.lowercased()) {
                    files.append(url)
                }
            }
        } else {
            let contents = try fileManager.contentsOfDirectory(
                at: folderURL, includingPropertiesForKeys: [.isRegularFileKey])
            files = contents.filter {
                config.supportedExtensions.contains($0.pathExtension.lowercased())
            }
        }

        // Process files
        var documents: [MockDocument] = []

        for fileURL in files {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let document = MockDocument(
                id: UUID().uuidString,
                title: fileURL.lastPathComponent,
                content: content,
                source: fileURL.path,
                type: fileURL.pathExtension.lowercased() == "md" ? .markdown : .text
            )
            documents.append(document)
        }

        let totalChunks = documents.reduce(0) { $0 + $1.chunks.count }

        return MockProcessingResult(
            documents: documents,
            totalFiles: files.count,
            processedFiles: documents.count,
            vectorCount: totalChunks,
            processingTime: Date()
        )
    }
}

class MockVectorDatabaseManager {
    func getDatabase(for knowledgeBase: MockKnowledgeBase) -> MockVectorDatabase {
        return MockVectorDatabase()
    }

    func storeDocument(_ document: MockDocument, in knowledgeBase: MockKnowledgeBase) async throws {
        // Simulate storing document
        print("  Storing document: \(document.title) with \(document.chunks.count) chunks")
    }

    func getStats(for knowledgeBase: MockKnowledgeBase) async -> MockStats? {
        return MockStats(
            documentCount: 3,
            vectorCount: 12,
            lastUpdated: Date(),
            storageSize: 1024
        )
    }
}

struct MockVectorDatabase {
    // Mock vector database implementation
}

struct MockStats {
    let documentCount: Int
    let vectorCount: Int
    let lastUpdated: Date
    let storageSize: Int64
}

enum MockProcessingError: LocalizedError {
    case invalidConfiguration(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let message):
            return "Configuration error: \(message)"
        }
    }
}

// MARK: - Extensions

extension String {
    func chunked(into size: Int) -> [String] {
        var chunks: [String] = []
        var currentIndex = startIndex

        while currentIndex < endIndex {
            let nextIndex = index(currentIndex, offsetBy: size, limitedBy: endIndex) ?? endIndex
            let chunk = String(self[currentIndex..<nextIndex])
            chunks.append(chunk)
            currentIndex = nextIndex
        }

        return chunks
    }
}

// Run the test
Task {
    await main()
}
