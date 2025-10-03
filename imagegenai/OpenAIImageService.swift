import Foundation

protocol ImageGenerating {
    func generateImage(for prompt: String, size: String) async throws -> Data
}

final class OpenAIImageService: ImageGenerating {

    private let apiKey: String

    init(apiKey: String? = APIKeyProvider.openAIKey()) {
        self.apiKey = apiKey ?? ""
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
                return "Missing OpenAI API key. Add it to Info.plist with key 'OpenAIAPIKey'."
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

    func generateImage(for prompt: String, size: String = "512x512") async throws -> Data {
        guard !apiKey.isEmpty else { throw ServiceError.missingAPIKey }

        let url = URL(string: "https://api.openai.com/v1/images/generations")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": "gpt-image-1",
            "prompt": prompt,
            "size": size,
            "response_format": "b64_json"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

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
        guard let first = decoded.data.first,
              let b64 = first.b64_json,
              let imageData = Data(base64Encoded: b64) else {
            throw ServiceError.emptyData
        }

        return imageData
    }
}
