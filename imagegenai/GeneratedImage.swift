import Foundation

struct GeneratedImage: Identifiable, Codable, Equatable {
    let id: UUID
    let prompt: String
    let date: Date
    let filename: String

    // Convenience to access file URL from filename
    var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }
}
