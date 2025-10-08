import Accelerate
import Foundation
import SQLite3

// MARK: - SQLite Vector Database Manager

class SQLiteVectorDB: ObservableObject {
    private var db: OpaquePointer?
    private let dbPath: String
    private let vectorDimension: Int

    // Table names
    private let knowledgeBasesTable = "knowledge_bases"
    private let documentsTable = "documents"
    private let chunksTable = "chunks"
    private let vectorsTable = "vectors"

    init(dbPath: String, vectorDimension: Int = 384) {
        self.dbPath = dbPath
        self.vectorDimension = vectorDimension

        // Initialize database synchronously
        do {
            try openDatabaseSync()
            try createTablesSync()
            try createIndexesSync()
        } catch {
            print("Failed to initialize vector database: \(error)")
        }
    }

    deinit {
        closeDatabase()
    }

    // MARK: - Database Initialization

    private func openDatabaseSync() throws {
        // Create directory if it doesn't exist
        let dbURL = URL(fileURLWithPath: dbPath)
        let dbDirectory = dbURL.deletingLastPathComponent()

        if !FileManager.default.fileExists(atPath: dbDirectory.path) {
            try FileManager.default.createDirectory(
                at: dbDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        let result = sqlite3_open(dbPath, &db)
        if result != SQLITE_OK {
            throw VectorDBError.databaseError(
                "Cannot open database: \(String(cString: sqlite3_errmsg(db)))")
        }

        // Enable WAL mode for better concurrency
        try executeSQLSync("PRAGMA journal_mode=WAL;")

        // Optimize for performance
        try executeSQLSync("PRAGMA synchronous=NORMAL;")
        try executeSQLSync("PRAGMA cache_size=10000;")
        try executeSQLSync("PRAGMA temp_store=MEMORY;")
    }

    private func createTablesSync() throws {
        // Knowledge bases table
        let kbTableSQL = """
                CREATE TABLE IF NOT EXISTS \(knowledgeBasesTable) (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    type TEXT NOT NULL,
                    description TEXT,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL,
                    total_documents INTEGER DEFAULT 0,
                    total_chunks INTEGER DEFAULT 0,
                    total_vectors INTEGER DEFAULT 0
                );
            """

        // Documents table
        let documentsTableSQL = """
                CREATE TABLE IF NOT EXISTS \(documentsTable) (
                    id TEXT PRIMARY KEY,
                    kb_id TEXT NOT NULL,
                    title TEXT NOT NULL,
                    content TEXT NOT NULL,
                    source TEXT NOT NULL,
                    type TEXT NOT NULL,
                    metadata TEXT,
                    created_at REAL NOT NULL,
                    FOREIGN KEY (kb_id) REFERENCES \(knowledgeBasesTable)(id) ON DELETE CASCADE
                );
            """

        // Chunks table
        let chunksTableSQL = """
                CREATE TABLE IF NOT EXISTS \(chunksTable) (
                    id TEXT PRIMARY KEY,
                    document_id TEXT NOT NULL,
                    kb_id TEXT NOT NULL,
                    content TEXT NOT NULL,
                    chunk_index INTEGER NOT NULL,
                    metadata TEXT,
                    created_at REAL NOT NULL,
                    FOREIGN KEY (document_id) REFERENCES \(documentsTable)(id) ON DELETE CASCADE,
                    FOREIGN KEY (kb_id) REFERENCES \(knowledgeBasesTable)(id) ON DELETE CASCADE
                );
            """

        // Vectors table - stores the actual embeddings
        let vectorsTableSQL = """
                CREATE TABLE IF NOT EXISTS \(vectorsTable) (
                    id TEXT PRIMARY KEY,
                    chunk_id TEXT NOT NULL,
                    kb_id TEXT NOT NULL,
                    embedding BLOB NOT NULL,
                    norm REAL NOT NULL,
                    created_at REAL NOT NULL,
                    FOREIGN KEY (chunk_id) REFERENCES \(chunksTable)(id) ON DELETE CASCADE,
                    FOREIGN KEY (kb_id) REFERENCES \(knowledgeBasesTable)(id) ON DELETE CASCADE
                );
            """

        try executeSQLSync(kbTableSQL)
        try executeSQLSync(documentsTableSQL)
        try executeSQLSync(chunksTableSQL)
        try executeSQLSync(vectorsTableSQL)
    }

    private func createIndexesSync() throws {
        let indexes = [
            "CREATE INDEX IF NOT EXISTS idx_documents_kb_id ON \(documentsTable)(kb_id);",
            "CREATE INDEX IF NOT EXISTS idx_chunks_document_id ON \(chunksTable)(document_id);",
            "CREATE INDEX IF NOT EXISTS idx_chunks_kb_id ON \(chunksTable)(kb_id);",
            "CREATE INDEX IF NOT EXISTS idx_vectors_chunk_id ON \(vectorsTable)(chunk_id);",
            "CREATE INDEX IF NOT EXISTS idx_vectors_kb_id ON \(vectorsTable)(kb_id);",
            "CREATE INDEX IF NOT EXISTS idx_vectors_norm ON \(vectorsTable)(norm);",
        ]

        for indexSQL in indexes {
            try executeSQLSync(indexSQL)
        }
    }

    // MARK: - Knowledge Base Operations

    @MainActor
    func createKnowledgeBase(_ kb: KnowledgeBase) async throws {
        let sql = """
                INSERT OR REPLACE INTO \(knowledgeBasesTable)
                (id, name, type, description, created_at, updated_at, total_documents, total_chunks, total_vectors)
                VALUES (?, ?, ?, ?, ?, ?, 0, 0, 0);
            """

        let now = Date().timeIntervalSince1970
        let params: [Any] = [
            kb.id.uuidString,
            kb.name,
            kb.type.rawValue,
            kb.description,
            now,
            now,
        ]

        try await executeSQL(sql, parameters: params)
    }

    @MainActor
    func deleteKnowledgeBase(id: String) async throws {
        let sql = "DELETE FROM \(knowledgeBasesTable) WHERE id = ?;"
        try await executeSQL(sql, parameters: [id])
    }

    @MainActor
    func getKnowledgeBaseStats(id: String) async throws -> VectorDBStats? {
        let sql = """
                SELECT total_documents, total_chunks, total_vectors, updated_at
                FROM \(knowledgeBasesTable) WHERE id = ?;
            """

        return try await withCheckedThrowingContinuation { continuation in
            var stmt: OpaquePointer?

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                continuation.resume(
                    throwing: VectorDBError.databaseError("Failed to prepare statement"))
                return
            }

            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, id, -1, nil)

            if sqlite3_step(stmt) == SQLITE_ROW {
                let totalDocs = sqlite3_column_int(stmt, 0)
                let totalChunks = sqlite3_column_int(stmt, 1)
                let totalVectors = sqlite3_column_int(stmt, 2)
                let updatedAt = sqlite3_column_double(stmt, 3)

                let stats = VectorDBStats(
                    documentCount: Int(totalDocs),
                    chunkCount: Int(totalChunks),
                    vectorCount: Int(totalVectors),
                    lastUpdated: Date(timeIntervalSince1970: updatedAt),
                    storageSize: 0  // Will calculate separately if needed
                )

                continuation.resume(returning: stats)
            } else {
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - Document Operations

    @MainActor
    func storeDocument(_ document: Document, kbId: String) async throws {
        try await beginTransaction()

        do {
            // Insert document
            let documentSQL = """
                    INSERT OR REPLACE INTO \(documentsTable)
                    (id, kb_id, title, content, source, type, metadata, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?);
                """

            let metadata = try JSONEncoder().encode(document.metadata)
            let metadataString = String(data: metadata, encoding: .utf8) ?? "{}"
            let now = Date().timeIntervalSince1970

            let docParams: [Any] = [
                document.id,
                kbId,
                document.title,
                document.content,
                document.source,
                document.type.rawValue,
                metadataString,
                now,
            ]

            try await executeSQL(documentSQL, parameters: docParams)

            // Insert chunks and vectors
            for chunk in document.chunks {
                try await storeChunk(chunk, documentId: document.id, kbId: kbId)
            }

            // Update knowledge base stats
            try await updateKnowledgeBaseStats(kbId: kbId)

            try await commitTransaction()
        } catch {
            try await rollbackTransaction()
            throw error
        }
    }

    @MainActor
    private func storeChunk(_ chunk: DocumentChunk, documentId: String, kbId: String) async throws {
        // Insert chunk
        let chunkSQL = """
                INSERT OR REPLACE INTO \(chunksTable)
                (id, document_id, kb_id, content, chunk_index, metadata, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?);
            """

        let metadata = try JSONEncoder().encode(chunk.metadata)
        let metadataString = String(data: metadata, encoding: .utf8) ?? "{}"
        let now = Date().timeIntervalSince1970

        let chunkParams: [Any] = [
            chunk.id,
            documentId,
            kbId,
            chunk.content,
            chunk.chunkIndex,
            metadataString,
            now,
        ]

        try await executeSQL(chunkSQL, parameters: chunkParams)

        // Store vector if available
        if let embedding = chunk.embedding {
            try await storeVector(chunkId: chunk.id, kbId: kbId, embedding: embedding)
        }
    }

    @MainActor
    private func storeVector(chunkId: String, kbId: String, embedding: [Float]) async throws {
        guard embedding.count == vectorDimension else {
            throw VectorDBError.dimensionMismatch(
                "Expected \(vectorDimension) dimensions, got \(embedding.count)")
        }

        // Calculate L2 norm for faster similarity search with safety checks
        let sumOfSquares = embedding.map { $0 * $0 }.reduce(0, +)

        // Verify the sum is valid
        guard sumOfSquares > 0 && sumOfSquares.isFinite && !sumOfSquares.isNaN else {
            print("Error: Invalid embedding sum of squares: \(sumOfSquares)")
            throw VectorDBError.invalidEmbedding(
                "Invalid embedding: sum of squares is \(sumOfSquares)")
        }

        let norm = sqrt(sumOfSquares)

        // Verify the norm is valid
        guard norm > 0 && norm.isFinite && !norm.isNaN else {
            print("Error: Invalid norm calculated: \(norm)")
            throw VectorDBError.invalidEmbedding("Invalid norm calculated: \(norm)")
        }

        // Verify all embedding values are finite
        guard embedding.allSatisfy({ $0.isFinite && !$0.isNaN }) else {
            print("Error: Embedding contains invalid values (NaN or infinite)")
            throw VectorDBError.invalidEmbedding("Embedding contains NaN or infinite values")
        }

        print("Storing vector with norm: \(norm), dimension: \(embedding.count)")

        // Convert embedding to binary data
        let embeddingData = Data(
            bytes: embedding, count: embedding.count * MemoryLayout<Float>.size)

        let vectorSQL = """
                INSERT OR REPLACE INTO \(vectorsTable)
                (id, chunk_id, kb_id, embedding, norm, created_at)
                VALUES (?, ?, ?, ?, ?, ?);
            """

        let now = Date().timeIntervalSince1970
        let params: [Any] = [
            UUID().uuidString,
            chunkId,
            kbId,
            embeddingData,
            norm,
            now,
        ]

        try await executeSQL(vectorSQL, parameters: params)
    }

    // MARK: - Vector Search

    @MainActor
    func searchSimilar(
        query: [Float],
        kbId: String,
        limit: Int = 10,
        minSimilarity: Float = 0.5
    ) async throws -> [VectorSearchResult] {
        guard query.count == vectorDimension else {
            throw VectorDBError.dimensionMismatch("Query vector dimension mismatch")
        }

        let queryNorm = sqrt(query.map { $0 * $0 }.reduce(0, +))

        let sql = """
                SELECT
                    v.chunk_id,
                    v.embedding,
                    v.norm,
                    c.content,
                    c.metadata,
                    d.title,
                    d.source
                FROM \(vectorsTable) v
                JOIN \(chunksTable) c ON v.chunk_id = c.id
                JOIN \(documentsTable) d ON c.document_id = d.id
                WHERE v.kb_id = ?
                ORDER BY v.created_at DESC;
            """

        return try await withCheckedThrowingContinuation { continuation in
            var stmt: OpaquePointer?
            var results: [VectorSearchResult] = []

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                continuation.resume(
                    throwing: VectorDBError.databaseError("Failed to prepare search statement"))
                return
            }

            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, kbId, -1, nil)

            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let embeddingBlob = sqlite3_column_blob(stmt, 1) else { continue }

                let embeddingSize = sqlite3_column_bytes(stmt, 1)
                let embeddingData = Data(bytes: embeddingBlob, count: Int(embeddingSize))

                guard embeddingSize == vectorDimension * MemoryLayout<Float>.size else { continue }

                let embedding = embeddingData.withUnsafeBytes { bytes in
                    Array(bytes.bindMemory(to: Float.self))
                }

                let norm = sqlite3_column_double(stmt, 2)

                // Calculate cosine similarity
                let dotProduct = zip(query, embedding).map(*).reduce(0, +)
                let similarity = Float(dotProduct / (queryNorm * Float(norm)))

                if similarity >= minSimilarity {
                    let chunkId = String(cString: sqlite3_column_text(stmt, 0))
                    let content = String(cString: sqlite3_column_text(stmt, 3))
                    let metadataStr = String(cString: sqlite3_column_text(stmt, 4))
                    let title = String(cString: sqlite3_column_text(stmt, 5))
                    let source = String(cString: sqlite3_column_text(stmt, 6))

                    // Parse metadata
                    var metadata: [String: String] = [:]
                    if let data = metadataStr.data(using: .utf8),
                        let parsed = try? JSONDecoder().decode([String: String].self, from: data)
                    {
                        metadata = parsed
                    }

                    let result = VectorSearchResult(
                        chunkId: chunkId,
                        content: content,
                        similarity: similarity,
                        metadata: metadata,
                        documentTitle: title,
                        documentSource: source
                    )

                    results.append(result)
                }
            }

            // Sort by similarity (descending) and limit results
            results.sort { $0.similarity > $1.similarity }
            let limitedResults = Array(results.prefix(limit))

            continuation.resume(returning: limitedResults)
        }
    }

    // MARK: - Database Maintenance

    @MainActor
    func clearKnowledgeBase(id: String) async throws {
        try await executeSQL("DELETE FROM \(documentsTable) WHERE kb_id = ?;", parameters: [id])
        try await updateKnowledgeBaseStats(kbId: id)
    }

    @MainActor
    func vacuum() async throws {
        try await executeSQL("VACUUM;")
    }

    @MainActor
    func getStorageSize() async throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: dbPath)
        return attributes[.size] as? Int64 ?? 0
    }

    // MARK: - Private Helpers

    @MainActor
    private func updateKnowledgeBaseStats(kbId: String) async throws {
        let statsSQL = """
                UPDATE \(knowledgeBasesTable) SET
                    total_documents = (SELECT COUNT(*) FROM \(documentsTable) WHERE kb_id = ?),
                    total_chunks = (SELECT COUNT(*) FROM \(chunksTable) WHERE kb_id = ?),
                    total_vectors = (SELECT COUNT(*) FROM \(vectorsTable) WHERE kb_id = ?),
                    updated_at = ?
                WHERE id = ?;
            """

        let now = Date().timeIntervalSince1970
        let params: [Any] = [kbId, kbId, kbId, now, kbId]

        try await executeSQL(statsSQL, parameters: params)
    }

    @MainActor
    private func executeSQL(_ sql: String, parameters: [Any] = []) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            var stmt: OpaquePointer?

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                continuation.resume(
                    throwing: VectorDBError.databaseError("Failed to prepare statement: \(sql)"))
                return
            }

            defer { sqlite3_finalize(stmt) }

            // Bind parameters
            for (index, param) in parameters.enumerated() {
                let bindIndex = Int32(index + 1)

                switch param {
                case let stringValue as String:
                    sqlite3_bind_text(stmt, bindIndex, stringValue, -1, nil)
                case let intValue as Int:
                    sqlite3_bind_int(stmt, bindIndex, Int32(intValue))
                case let doubleValue as Double:
                    sqlite3_bind_double(stmt, bindIndex, doubleValue)
                case let floatValue as Float:
                    sqlite3_bind_double(stmt, bindIndex, Double(floatValue))
                case let dataValue as Data:
                    _ = dataValue.withUnsafeBytes { bytes in
                        sqlite3_bind_blob(
                            stmt, bindIndex, bytes.baseAddress, Int32(bytes.count), nil)
                    }
                default:
                    sqlite3_bind_null(stmt, bindIndex)
                }
            }

            let result = sqlite3_step(stmt)
            if result == SQLITE_DONE || result == SQLITE_ROW {
                continuation.resume()
            } else {
                let error = String(cString: sqlite3_errmsg(db))
                continuation.resume(
                    throwing: VectorDBError.databaseError("SQL execution failed: \(error)"))
            }
        }
    }

    @MainActor
    private func beginTransaction() async throws {
        try await executeSQL("BEGIN TRANSACTION;")
    }

    @MainActor
    private func commitTransaction() async throws {
        try await executeSQL("COMMIT;")
    }

    @MainActor
    private func rollbackTransaction() async throws {
        try await executeSQL("ROLLBACK;")
    }

    private func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }

    private func executeSQLSync(_ sql: String, parameters: [Any] = []) throws {
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw VectorDBError.databaseError("Failed to prepare statement: \(sql)")
        }

        defer { sqlite3_finalize(stmt) }

        // Bind parameters
        for (index, param) in parameters.enumerated() {
            let bindIndex = Int32(index + 1)

            switch param {
            case let stringValue as String:
                sqlite3_bind_text(stmt, bindIndex, stringValue, -1, nil)
            case let intValue as Int:
                sqlite3_bind_int(stmt, bindIndex, Int32(intValue))
            case let doubleValue as Double:
                sqlite3_bind_double(stmt, bindIndex, doubleValue)
            case let floatValue as Float:
                sqlite3_bind_double(stmt, bindIndex, Double(floatValue))
            case let dataValue as Data:
                _ = dataValue.withUnsafeBytes { bytes in
                    sqlite3_bind_blob(
                        stmt, bindIndex, bytes.baseAddress, Int32(bytes.count), nil)
                }
            default:
                sqlite3_bind_null(stmt, bindIndex)
            }
        }

        let result = sqlite3_step(stmt)
        if result != SQLITE_DONE && result != SQLITE_ROW {
            let error = String(cString: sqlite3_errmsg(db))
            throw VectorDBError.databaseError("SQL execution failed: \(error)")
        }
    }
}

// MARK: - Supporting Types

struct VectorDBStats {
    let documentCount: Int
    let chunkCount: Int
    let vectorCount: Int
    let lastUpdated: Date
    let storageSize: Int64
}

struct VectorSearchResult {
    let chunkId: String
    let content: String
    let similarity: Float
    let metadata: [String: String]
    let documentTitle: String
    let documentSource: String
}

enum VectorDBError: LocalizedError {
    case databaseError(String)
    case dimensionMismatch(String)
    case vectorNotFound
    case invalidEmbedding(String)

    var errorDescription: String? {
        switch self {
        case .databaseError(let message):
            return "Database error: \(message)"
        case .dimensionMismatch(let message):
            return "Vector dimension error: \(message)"
        case .vectorNotFound:
            return "Vector not found"
        case .invalidEmbedding(let message):
            return "Invalid embedding data: \(message)"
        }
    }
}

// MARK: - Extensions

extension Data {
    init<T>(bytes: [T], count: Int) {
        self = bytes.withUnsafeBytes { bytes in
            Data(bytes: bytes.baseAddress!, count: count)
        }
    }
}
