import Accelerate
import Foundation

// MARK: - Embedding Service

@MainActor
class EmbeddingService: ObservableObject {
    static let shared = EmbeddingService()

    @Published var isProcessing = false
    @Published var currentProvider: EmbeddingProvider = .openAI

    private let session: URLSession
    private var apiKey: String = ""

    // Vector dimensions for different providers
    private let providerDimensions: [EmbeddingProvider: Int] = [
        .openAI: 1536,
        .openAISmall: 384,
        .local: 384,
        .mock: 384,
    ]

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)

        loadConfiguration()
    }

    // MARK: - Configuration

    func setProvider(_ provider: EmbeddingProvider) {
        currentProvider = provider
        saveConfiguration()
    }

    func setAPIKey(_ key: String) {
        apiKey = key
        saveConfiguration()
    }

    func getVectorDimension() -> Int {
        return providerDimensions[currentProvider] ?? 384
    }

    // MARK: - Embedding Generation

    func generateEmbedding(for text: String) async throws -> [Float] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EmbeddingError.emptyText
        }

        isProcessing = true
        defer { isProcessing = false }

        switch currentProvider {
        case .openAI, .openAISmall:
            return try await generateOpenAIEmbedding(text: text)
        case .local:
            return try await generateLocalEmbedding(text: text)
        case .mock:
            return generateMockEmbedding(text: text)
        }
    }

    func generateEmbeddings(for texts: [String], batchSize: Int = 10) async throws -> [[Float]] {
        guard !texts.isEmpty else { return [] }

        var results: [[Float]] = []

        // Process in batches to avoid rate limits and memory issues
        for i in stride(from: 0, to: texts.count, by: batchSize) {
            let batch = Array(texts[i..<min(i + batchSize, texts.count)])

            switch currentProvider {
            case .openAI, .openAISmall:
                let batchResults = try await generateOpenAIBatchEmbeddings(texts: batch)
                results.append(contentsOf: batchResults)
            case .local:
                var batchResults: [[Float]] = []
                for text in batch {
                    let embedding = try await generateLocalEmbedding(text: text)
                    batchResults.append(embedding)
                }
                results.append(contentsOf: batchResults)
            case .mock:
                let batchResults = batch.map { generateMockEmbedding(text: $0) }
                results.append(contentsOf: batchResults)
            }

            // Add delay between batches for rate limiting
            if i + batchSize < texts.count {
                try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second
            }
        }

        return results
    }

    // MARK: - Provider Implementations

    private func generateOpenAIEmbedding(text: String) async throws -> [Float] {
        guard !apiKey.isEmpty else {
            throw EmbeddingError.missingAPIKey
        }

        let model =
            currentProvider == .openAISmall ? "text-embedding-3-small" : "text-embedding-3-large"
        let endpoint = URL(string: "https://api.openai.com/v1/embeddings")!

        let requestBody = OpenAIEmbeddingRequest(
            input: [text],
            model: model,
            dimensions: providerDimensions[currentProvider]
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("ai-plugins/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let requestData = try JSONEncoder().encode(requestBody)
            request.httpBody = requestData

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw EmbeddingError.networkError("Invalid response")
            }

            guard 200...299 ~= httpResponse.statusCode else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw EmbeddingError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
            }

            let embeddingResponse = try JSONDecoder().decode(
                OpenAIEmbeddingResponse.self, from: data)

            guard let firstEmbedding = embeddingResponse.data.first?.embedding else {
                throw EmbeddingError.invalidResponse("No embedding data received")
            }

            return firstEmbedding

        } catch let error as EmbeddingError {
            throw error
        } catch {
            throw EmbeddingError.networkError(error.localizedDescription)
        }
    }

    private func generateOpenAIBatchEmbeddings(texts: [String]) async throws -> [[Float]] {
        guard !apiKey.isEmpty else {
            throw EmbeddingError.missingAPIKey
        }

        let model =
            currentProvider == .openAISmall ? "text-embedding-3-small" : "text-embedding-3-large"
        let endpoint = URL(string: "https://api.openai.com/v1/embeddings")!

        let requestBody = OpenAIEmbeddingRequest(
            input: texts,
            model: model,
            dimensions: providerDimensions[currentProvider]
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("ai-plugins/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let requestData = try JSONEncoder().encode(requestBody)
            request.httpBody = requestData

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw EmbeddingError.networkError("Invalid response")
            }

            guard 200...299 ~= httpResponse.statusCode else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw EmbeddingError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
            }

            let embeddingResponse = try JSONDecoder().decode(
                OpenAIEmbeddingResponse.self, from: data)

            return embeddingResponse.data.map { $0.embedding }

        } catch let error as EmbeddingError {
            throw error
        } catch {
            throw EmbeddingError.networkError(error.localizedDescription)
        }
    }

    private func generateLocalEmbedding(text: String) async throws -> [Float] {
        // Placeholder for local embedding model
        // In a real implementation, this would use a local ML model like sentence-transformers
        // For now, we'll return a mock embedding
        print("Local embedding not yet implemented, using mock embedding")
        return generateMockEmbedding(text: text)
    }

    private func generateMockEmbedding(text: String) -> [Float] {
        // Generate deterministic mock embedding based on text hash
        let hash = text.hash
        let dimension = getVectorDimension()

        // Use seeded random number generator for consistency
        var generator = SeededRandomNumberGenerator(seed: UInt64(abs(hash)))

        var embedding: [Float] = []
        for _ in 0..<dimension {
            embedding.append(Float.random(in: -1...1, using: &generator))
        }

        // Normalize the vector
        let norm = sqrt(embedding.map { $0 * $0 }.reduce(0, +))
        return embedding.map { $0 / norm }
    }

    // MARK: - Utility Functions

    func calculateSimilarity(_ vector1: [Float], _ vector2: [Float]) -> Float {
        guard vector1.count == vector2.count else { return 0.0 }

        // Cosine similarity using Accelerate framework for performance
        var dotProduct: Float = 0.0
        vDSP_dotpr(vector1, 1, vector2, 1, &dotProduct, vDSP_Length(vector1.count))

        var norm1: Float = 0.0
        var norm2: Float = 0.0

        vDSP_svesq(vector1, 1, &norm1, vDSP_Length(vector1.count))
        vDSP_svesq(vector2, 1, &norm2, vDSP_Length(vector2.count))

        norm1 = sqrt(norm1)
        norm2 = sqrt(norm2)

        guard norm1 > 0 && norm2 > 0 else { return 0.0 }

        return dotProduct / (norm1 * norm2)
    }

    func testConnection() async throws -> Bool {
        let testText = "This is a test message to verify the embedding service connection."

        do {
            let _ = try await generateEmbedding(for: testText)
            return true
        } catch {
            print("Embedding service test failed: \(error)")
            throw error
        }
    }

    // MARK: - Configuration Persistence

    private func loadConfiguration() {
        let userDefaults = UserDefaults.standard

        if let providerRaw = userDefaults.string(forKey: "EmbeddingProvider"),
            let provider = EmbeddingProvider(rawValue: providerRaw)
        {
            currentProvider = provider
        }

        apiKey = userDefaults.string(forKey: "EmbeddingAPIKey") ?? ""
    }

    private func saveConfiguration() {
        let userDefaults = UserDefaults.standard
        userDefaults.set(currentProvider.rawValue, forKey: "EmbeddingProvider")
        userDefaults.set(apiKey, forKey: "EmbeddingAPIKey")
    }
}

// MARK: - Supporting Types

enum EmbeddingProvider: String, CaseIterable, Identifiable {
    case openAI = "openai"
    case openAISmall = "openai_small"
    case local = "local"
    case mock = "mock"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI:
            return "OpenAI (text-embedding-3-large)"
        case .openAISmall:
            return "OpenAI (text-embedding-3-small)"
        case .local:
            return "Local Model"
        case .mock:
            return "Mock (Testing)"
        }
    }

    var description: String {
        switch self {
        case .openAI:
            return "High-quality embeddings, 1536 dimensions"
        case .openAISmall:
            return "Faster embeddings, 384 dimensions"
        case .local:
            return "Local model, private processing"
        case .mock:
            return "For testing and development"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .openAI, .openAISmall:
            return true
        case .local, .mock:
            return false
        }
    }
}

enum EmbeddingError: LocalizedError {
    case emptyText
    case missingAPIKey
    case networkError(String)
    case apiError(String)
    case invalidResponse(String)
    case modelError(String)

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "Text cannot be empty"
        case .missingAPIKey:
            return "API key is required for this embedding provider"
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let message):
            return "API error: \(message)"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .modelError(let message):
            return "Model error: \(message)"
        }
    }
}

// MARK: - OpenAI API Types

struct OpenAIEmbeddingRequest: Codable {
    let input: [String]
    let model: String
    let dimensions: Int?

    enum CodingKeys: String, CodingKey {
        case input, model, dimensions
    }
}

struct OpenAIEmbeddingResponse: Codable {
    let data: [OpenAIEmbeddingData]
    let model: String
    let usage: OpenAIUsage

    struct OpenAIEmbeddingData: Codable {
        let embedding: [Float]
        let index: Int
    }

    struct OpenAIUsage: Codable {
        let promptTokens: Int
        let totalTokens: Int

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

// MARK: - Utilities

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 1_103_515_245 &+ 12345
        return state
    }
}
