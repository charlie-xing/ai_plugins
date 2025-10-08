import Combine
import Foundation

// MARK: - RAG Configuration

struct RAGConfiguration {
    var enabled: Bool = true
    var maxResults: Int = 5
    var similarityThreshold: Float = 0.3
    var contextTemplate: String = """
        Based on the following relevant information from the knowledge base:

        {context}

        Please answer the following question: {query}
        """
    var includeMetadata: Bool = false
    var maxContextLength: Int = 2000
}

// MARK: - RAG Context

struct RAGContext {
    let query: String
    let knowledgeBase: KnowledgeBase
    let retrievedChunks: [SearchResult]
    let contextText: String
    let enhancedPrompt: String
    let usedConfiguration: RAGConfiguration

    var hasResults: Bool {
        !retrievedChunks.isEmpty
    }

    var averageSimilarity: Float {
        guard !retrievedChunks.isEmpty else { return 0.0 }
        let sum = retrievedChunks.reduce(0.0) { $0 + $1.similarity }
        return sum / Float(retrievedChunks.count)
    }
}

// MARK: - RAG Service

@MainActor
class RAGService: ObservableObject {
    static let shared = RAGService()

    @Published var isSearching = false
    @Published var lastError: Error?
    @Published var configuration = RAGConfiguration()

    private let knowledgeBaseService = KnowledgeBaseService.shared
    private var cancellables = Set<AnyCancellable>()
    private var reindexingInProgress: Set<UUID> = []

    private init() {
        // Load saved configuration
        loadConfiguration()
    }

    // MARK: - Main RAG Functions

    /// Enhance user prompt with knowledge base context
    func enhancePrompt(
        _ originalPrompt: String,
        using knowledgeBase: KnowledgeBase
    ) async throws -> RAGContext {
        isSearching = true
        defer { isSearching = false }

        do {
            // Search for relevant content
            let searchResults = try await knowledgeBaseService.searchInKnowledgeBase(
                knowledgeBase,
                query: originalPrompt,
                limit: configuration.maxResults
            )

            // Filter by adaptive similarity threshold
            let adaptiveThreshold = getAdaptiveSimilarityThreshold()
            let filteredResults = searchResults.filter {
                $0.similarity >= adaptiveThreshold
            }

            print(
                "RAGService: Using adaptive threshold \(adaptiveThreshold) vs configured \(configuration.similarityThreshold)"
            )
            print("RAGService: Found \(filteredResults.count) results above adaptive threshold")

            // Build context text
            let contextText = buildContextText(from: filteredResults)

            // Create enhanced prompt
            let enhancedPrompt = buildEnhancedPrompt(
                originalQuery: originalPrompt,
                context: contextText
            )

            let ragContext = RAGContext(
                query: originalPrompt,
                knowledgeBase: knowledgeBase,
                retrievedChunks: filteredResults,
                contextText: contextText,
                enhancedPrompt: enhancedPrompt,
                usedConfiguration: configuration
            )

            print(
                "RAGService: Enhanced prompt with \(filteredResults.count) relevant chunks")

            // If no results found, check for potential embedding mismatch
            if filteredResults.isEmpty && !searchResults.isEmpty {
                let mismatchResult = await detectEmbeddingMismatch(
                    for: originalPrompt, in: knowledgeBase)
                if mismatchResult.requiresAction {
                    print("RAGService: \(mismatchResult.message)")

                    // Auto re-index if mismatch detected and not already in progress
                    if case .mismatchDetected = mismatchResult,
                        !reindexingInProgress.contains(knowledgeBase.id)
                    {

                        print(
                            "RAGService: Auto-reindexing knowledge base '\(knowledgeBase.name)'...")
                        reindexingInProgress.insert(knowledgeBase.id)

                        do {
                            try await knowledgeBaseService.forceReindexKnowledgeBase(knowledgeBase)
                            print("RAGService: Re-indexing completed, retrying search...")

                            // Retry the search with re-indexed data
                            let retryResults = try await knowledgeBaseService.searchInKnowledgeBase(
                                knowledgeBase,
                                query: originalPrompt,
                                limit: configuration.maxResults
                            )

                            let retryFiltered = retryResults.filter {
                                $0.similarity >= configuration.similarityThreshold
                            }

                            if !retryFiltered.isEmpty {
                                let retryContext = buildContextText(from: retryFiltered)
                                let retryPrompt = buildEnhancedPrompt(
                                    originalQuery: originalPrompt,
                                    context: retryContext
                                )

                                print(
                                    "RAGService: Retry successful with \(retryFiltered.count) chunks"
                                )
                                reindexingInProgress.remove(knowledgeBase.id)

                                return RAGContext(
                                    query: originalPrompt,
                                    knowledgeBase: knowledgeBase,
                                    retrievedChunks: retryFiltered,
                                    contextText: retryContext,
                                    enhancedPrompt: retryPrompt,
                                    usedConfiguration: configuration
                                )
                            }

                        } catch {
                            print("RAGService: Re-indexing failed: \(error)")
                        }

                        reindexingInProgress.remove(knowledgeBase.id)
                    }
                }
            }

            return ragContext

        } catch {
            lastError = error
            print("RAGService: Error enhancing prompt: \(error)")
            throw error
        }
    }

    /// Get system prompt with knowledge base context
    func buildSystemPrompt(with context: RAGContext) -> String {
        guard context.hasResults else {
            return "You are a helpful AI assistant."
        }

        return """
            You are a helpful AI assistant with access to a knowledge base.
            Use the provided context information to answer questions accurately.

            Context from knowledge base "\(context.knowledgeBase.name)":
            \(context.contextText)

            Instructions:
            - Base your answers on the provided context when relevant
            - If the context doesn't contain relevant information, say so clearly
            - Cite specific information from the context when applicable
            - Be concise but comprehensive in your responses
            """
    }

    /// Detect potential embedding method mismatch
    private func detectEmbeddingMismatch(
        for query: String,
        in knowledgeBase: KnowledgeBase
    ) async -> EmbeddingMismatchResult {
        do {
            let results = try await knowledgeBaseService.searchInKnowledgeBase(
                knowledgeBase,
                query: query,
                limit: min(10, configuration.maxResults * 2)
            )

            if results.isEmpty {
                return .noData("Knowledge base appears to be empty or not indexed")
            }

            let similarities = results.map { $0.similarity }
            let maxSimilarity = similarities.max() ?? 0.0
            let avgSimilarity = similarities.reduce(0, +) / Float(similarities.count)
            let negativeCount = similarities.filter { $0 < 0 }.count

            // Detect potential mismatch patterns
            if negativeCount > similarities.count / 2 {
                return .mismatchDetected(
                    "High number of negative similarities (\(negativeCount)/\(similarities.count)) suggests embedding method mismatch. Consider re-indexing the knowledge base."
                )
            }

            if maxSimilarity < 0.2 && avgSimilarity < 0.1 {
                return .mismatchDetected(
                    "Consistently low similarities (max: \(String(format: "%.3f", maxSimilarity)), avg: \(String(format: "%.3f", avgSimilarity))) suggest embedding method mismatch. Consider re-indexing the knowledge base."
                )
            }

            if maxSimilarity < 0.5 && similarities.count > 0 {
                return .possibleMismatch(
                    "Low maximum similarity (\(String(format: "%.3f", maxSimilarity))) may indicate embedding method differences. If results are poor, consider re-indexing."
                )
            }

            return .noIssue

        } catch {
            return .error("Failed to analyze embeddings: \(error.localizedDescription)")
        }
    }

    /// Get adaptive similarity threshold based on embedding provider
    private func getAdaptiveSimilarityThreshold() -> Float {
        let embeddingService = EmbeddingService.shared

        switch embeddingService.currentProvider {
        case .openAI, .openAISmall:
            // OpenAI embeddings are high quality, use configured threshold
            return configuration.similarityThreshold
        case .local:
            // Local embeddings are simpler, use lower threshold
            let localThreshold = min(0.3, configuration.similarityThreshold)
            return localThreshold
        case .mock:
            // Mock embeddings are random, use very low threshold
            return 0.1
        }
    }

    /// Check if knowledge base contains relevant information
    func hasRelevantContent(
        for query: String,
        in knowledgeBase: KnowledgeBase
    ) async -> Bool {
        do {
            let results = try await knowledgeBaseService.searchInKnowledgeBase(
                knowledgeBase,
                query: query,
                limit: 1
            )
            let adaptiveThreshold = getAdaptiveSimilarityThreshold()
            return !results.isEmpty
                && results.first!.similarity >= adaptiveThreshold
        } catch {
            print("RAGService: Error checking relevance: \(error)")
            return false
        }
    }

    // MARK: - Context Building

    private func buildContextText(from results: [SearchResult]) -> String {
        guard !results.isEmpty else { return "" }

        var contextParts: [String] = []
        var totalLength = 0

        for (index, result) in results.enumerated() {
            let prefix =
                configuration.includeMetadata
                ? "Source \(index + 1) (similarity: \(String(format: "%.2f", result.similarity))):\n"
                : ""

            let content = result.content.trimmingCharacters(in: .whitespacesAndNewlines)
            let part = prefix + content

            // Check if adding this part would exceed max length
            if totalLength + part.count > configuration.maxContextLength {
                // Try to fit as much as possible
                let remainingSpace = configuration.maxContextLength - totalLength
                if remainingSpace > 100 {  // Only add if we have reasonable space
                    let truncatedContent = String(part.prefix(remainingSpace - 3)) + "..."
                    contextParts.append(truncatedContent)
                }
                break
            }

            contextParts.append(part)
            totalLength += part.count
        }

        return contextParts.joined(separator: "\n\n")
    }

    private func buildEnhancedPrompt(originalQuery: String, context: String) -> String {
        guard !context.isEmpty else { return originalQuery }

        return configuration.contextTemplate
            .replacingOccurrences(of: "{context}", with: context)
            .replacingOccurrences(of: "{query}", with: originalQuery)
    }

    // MARK: - Configuration Management

    func updateConfiguration(_ newConfig: RAGConfiguration) {
        configuration = newConfig
        saveConfiguration()
    }

    private func loadConfiguration() {
        if let data = UserDefaults.standard.data(forKey: "RAGConfiguration"),
            let config = try? JSONDecoder().decode(RAGConfiguration.self, from: data)
        {
            configuration = config
        }
    }

    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: "RAGConfiguration")
        }
    }

    // MARK: - Utility Functions

    /// Format search results for display or debugging
    func formatSearchResults(_ results: [SearchResult]) -> String {
        return results.enumerated().map { index, result in
            """
            Result \(index + 1):
            Similarity: \(String(format: "%.3f", result.similarity))
            Content: \(result.content.prefix(200))...
            """
        }.joined(separator: "\n\n")
    }

    /// Get statistics about a RAG context
    func getContextStats(_ context: RAGContext) -> [String: Any] {
        return [
            "query_length": context.query.count,
            "results_count": context.retrievedChunks.count,
            "context_length": context.contextText.count,
            "enhanced_prompt_length": context.enhancedPrompt.count,
            "average_similarity": context.averageSimilarity,
            "knowledge_base": context.knowledgeBase.name,
        ]
    }
}

// MARK: - Embedding Mismatch Detection

enum EmbeddingMismatchResult {
    case noIssue
    case noData(String)
    case possibleMismatch(String)
    case mismatchDetected(String)
    case error(String)

    var requiresAction: Bool {
        switch self {
        case .noIssue:
            return false
        case .noData, .possibleMismatch, .mismatchDetected, .error:
            return true
        }
    }

    var message: String {
        switch self {
        case .noIssue:
            return "No embedding issues detected"
        case .noData(let msg), .possibleMismatch(let msg), .mismatchDetected(let msg),
            .error(let msg):
            return msg
        }
    }

    var severity: EmbeddingMismatchSeverity {
        switch self {
        case .noIssue:
            return .none
        case .noData, .error:
            return .high
        case .mismatchDetected:
            return .high
        case .possibleMismatch:
            return .medium
        }
    }
}

enum EmbeddingMismatchSeverity {
    case none
    case medium
    case high

    var color: String {
        switch self {
        case .none:
            return "green"
        case .medium:
            return "orange"
        case .high:
            return "red"
        }
    }
}

// MARK: - RAG Errors

enum RAGError: LocalizedError {
    case knowledgeBaseNotReady
    case searchFailed(Error)
    case noRelevantContent
    case configurationError(String)

    var errorDescription: String? {
        switch self {
        case .knowledgeBaseNotReady:
            return "Knowledge base is not ready for use"
        case .searchFailed(let error):
            return "Search failed: \(error.localizedDescription)"
        case .noRelevantContent:
            return "No relevant content found in knowledge base"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        }
    }
}

// MARK: - Extensions

extension RAGConfiguration: Codable {
    // Codable conformance is automatically synthesized
}

extension SearchResult {
    var isHighQuality: Bool {
        similarity >= 0.8
    }

    var qualityDescription: String {
        switch similarity {
        case 0.9...:
            return "Excellent match"
        case 0.8..<0.9:
            return "Good match"
        case 0.7..<0.8:
            return "Fair match"
        default:
            return "Poor match"
        }
    }
}
