import Foundation

class AIProviderService {

    /// 测试 AI 服务提供商连接
    static func testConnection(endpoint: String, apiKey: String) async -> Result<String, Error> {
        guard let url = URL(string: "\(endpoint)/models") else {
            return .failure(ConnectionError.invalidURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(ConnectionError.invalidResponse)
            }

            switch httpResponse.statusCode {
            case 200...299:
                return .success("Connection successful! API is responding.")
            case 401:
                return .failure(ConnectionError.unauthorized)
            case 403:
                return .failure(ConnectionError.forbidden)
            case 404:
                return .failure(ConnectionError.notFound)
            case 429:
                return .failure(ConnectionError.rateLimited)
            case 500...599:
                return .failure(ConnectionError.serverError)
            default:
                return .failure(ConnectionError.unknownError(httpResponse.statusCode))
            }
        } catch {
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    return .failure(ConnectionError.noInternet)
                case .timedOut:
                    return .failure(ConnectionError.timeout)
                case .cannotFindHost, .cannotConnectToHost:
                    return .failure(ConnectionError.cannotConnect)
                default:
                    return .failure(urlError)
                }
            }
            return .failure(error)
        }
    }

    /// 获取可用模型列表
    static func fetchModels(endpoint: String, apiKey: String) async -> Result<[String], Error> {
        guard let url = URL(string: "\(endpoint)/models") else {
            return .failure(ConnectionError.invalidURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return .failure(ConnectionError.invalidResponse)
            }

            // 尝试解析 OpenAI 格式的响应
            if let json = try? JSONDecoder().decode(ModelsResponse.self, from: data) {
                let modelIds = json.data.map { $0.id }
                return .success(modelIds)
            }

            return .failure(ConnectionError.invalidData)
        } catch {
            return .failure(error)
        }
    }
}

// MARK: - Response Models

struct ModelsResponse: Codable {
    let data: [ModelData]
}

struct ModelData: Codable {
    let id: String
    let created: Int?
    let ownedBy: String?

    enum CodingKeys: String, CodingKey {
        case id
        case created
        case ownedBy = "owned_by"
    }
}

// MARK: - Connection Errors

enum ConnectionError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidData
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverError
    case noInternet
    case timeout
    case cannotConnect
    case unknownError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API endpoint URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidData:
            return "Invalid data format"
        case .unauthorized:
            return "Unauthorized - Check your API key"
        case .forbidden:
            return "Forbidden - Access denied"
        case .notFound:
            return "API endpoint not found"
        case .rateLimited:
            return "Rate limit exceeded"
        case .serverError:
            return "Server error - Try again later"
        case .noInternet:
            return "No internet connection"
        case .timeout:
            return "Connection timeout"
        case .cannotConnect:
            return "Cannot connect to server"
        case .unknownError(let code):
            return "Unknown error (HTTP \(code))"
        }
    }
}
