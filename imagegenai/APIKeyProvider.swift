import Foundation

enum APIKeyProvider {
    // Service/account identifiers for Keychain
    private static let service = Bundle.main.bundleIdentifier ?? "imagegenai"
    private static let account = "OpenAIAPIKey"

    // Returns the current key:
    // 1) Keychain value if present
    // 2) Otherwise, Info.plist value (and seeds Keychain once for convenience)
    static func openAIKey() -> String? {
        if let key = KeychainStore.get(service: service, account: account) {
            return key
        }
        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as? String, !plistKey.isEmpty {
            _ = KeychainStore.set(plistKey, service: service, account: account)
            return plistKey
        }
        return nil
    }

    // Save/replace key in Keychain
    static func setOpenAIKey(_ key: String) {
        _ = KeychainStore.set(key, service: service, account: account)
    }

    // Remove key from Keychain
    static func clearOpenAIKey() {
        KeychainStore.delete(service: service, account: account)
    }
}

