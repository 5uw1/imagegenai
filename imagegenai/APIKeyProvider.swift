import Foundation

enum APIKeyProvider {
    // Add your OpenAI API key to Info.plist under key "OpenAIAPIKey"
    static func openAIKey() -> String? {
        Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as? String
    }
}
