import Foundation
import SwiftUI
import Combine

@MainActor
final class ImageGeneratorViewModel: ObservableObject {
    @Published var prompt: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var images: [GeneratedImage] = []

    private let service: ImageGenerating
    private let store: ImageStore

    init(service: ImageGenerating? = nil,
         store: ImageStore? = nil) {
        // Build defaults inside the @MainActor initializer to avoid
        // evaluating main-actor–isolated defaults in a nonisolated context.
        self.service = service ?? OpenAIImageService()
        self.store = store ?? .shared
    }

    func loadImages() {
        Task {
            let all = await store.getAll()
            await MainActor.run {
                self.images = all
            }
        }
    }

    func generate(size: String = "1024x1024") {
        // Require API key first
        guard APIKeyProvider.openAIKey() != nil else {
            self.errorMessage = "Add your OpenAI API key in Settings first."
            return
        }

        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let data = try await service.generateImage(for: trimmed, size: size)
                _ = try await store.saveImage(data: data, prompt: trimmed)
                let all = await store.getAll()
                await MainActor.run {
                    self.images = all
                    self.prompt = ""
                    self.isLoading = false
                }
            } catch {
                let message: String
                if let e = error as? LocalizedError, let msg = e.errorDescription {
                    message = msg
                } else {
                    message = error.localizedDescription
                }
                await MainActor.run {
                    self.errorMessage = message
                    self.isLoading = false
                }
            }
        }
    }

    func delete(at offsets: IndexSet) {
        Task {
            let current = await store.getAll()
            for index in offsets {
                let item = current[index]
                do {
                    try await store.deleteImage(item)
                } catch {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
            let all = await store.getAll()
            await MainActor.run {
                self.images = all
            }
        }
    }
}
