// SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = APIKeyProvider.openAIKey() ?? ""

    var body: some View {
        Form {
            Section("OpenAI API Key") {
                SecureField("sk-...", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)

                HStack {
                    Button("Save") {
                        APIKeyProvider.setOpenAIKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if APIKeyProvider.openAIKey() != nil {
                        Spacer()
                        Button("Clear", role: .destructive) {
                            APIKeyProvider.clearOpenAIKey()
                            apiKey = ""
                        }
                    }
                }

                Text("Your key is stored securely in the iOS Keychain. You can also set a default in Info.plist under ‘OpenAIAPIKey’.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
