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

    init(service: ImageGenerating = OpenAIImageService(),
         store: ImageStore = .shared) {
        self.service = service
        self.store = store
    }

    func loadImages() {
        Task {
            self.images = await store.getAll()
        }
    }

    func generate(size: String = "1024x1024") {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let data = try await service.generateImage(for: trimmed, size: size)
                _ = try await store.saveImage(data: data, prompt: trimmed)
                self.images = await store.getAll()
                self.prompt = ""
            } catch {
                if let e = error as? LocalizedError, let msg = e.errorDescription {
                    self.errorMessage = msg
                } else {
                    self.errorMessage = error.localizedDescription
                }
            }
            self.isLoading = false
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
                    self.errorMessage = error.localizedDescription
                }
            }
            self.images = await store.getAll()
        }
    }
}
