import Foundation

protocol ImageGenerating {
    func generateImage(for prompt: String, size: String) async throws -> Data
}

final class OpenAIImageService: ImageGenerating {

    // Provide the key dynamically so changes in Keychain take effect immediately.
    private let keyProvider: () -> String?

    init(keyProvider: @escaping () -> String? = APIKeyProvider.openAIKey) {
        self.keyProvider = keyProvider
    }

    enum ServiceError: Error, LocalizedError {
        case missingAPIKey
        case invalidResponse
        case httpError(Int, String)
        case decodeFailed
        case emptyData

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Missing OpenAI API key. Enter it in Settings."
            case .invalidResponse:
                return "Invalid response from server."
            case .httpError(let code, let message):
                return "Server error (\(code)): \(message)"
            case .decodeFailed:
                return "Failed to decode image response."
            case .emptyData:
                return "No image data returned."
            }
        }
    }

    func generateImage(for prompt: String, size: String = "1024x1024") async throws -> Data {
        guard let apiKey = keyProvider(), !apiKey.isEmpty else {
            throw ServiceError.missingAPIKey
        }

        let url = URL(string: "https://api.openai.com/v1/images/generations")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        struct GenerationRequest: Encodable {
            let model: String
            let prompt: String
            let size: String
            let n: Int
        }

        let body = GenerationRequest(model: "gpt-image-1", prompt: prompt, size: size, n: 1)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw ServiceError.httpError(http.statusCode, message)
        }

        struct APIResponse: Decodable {
            struct Item: Decodable {
                let b64_json: String?
                let url: String?
            }
            let data: [Item]
        }

        let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        guard let first = decoded.data.first else {
            throw ServiceError.emptyData
        }

        if let b64 = first.b64_json, let imageData = Data(base64Encoded: b64) {
            return imageData
        } else if let urlString = first.url, let imageURL = URL(string: urlString) {
            let (imageData, imageResp) = try await URLSession.shared.data(from: imageURL)
            guard let http2 = imageResp as? HTTPURLResponse, 200..<300 ~= http2.statusCode else {
                throw ServiceError.invalidResponse
            }
            return imageData
        } else {
            throw ServiceError.emptyData
        }
    }
}

