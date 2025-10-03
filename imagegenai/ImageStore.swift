import Foundation

actor ImageStore {
    static let shared = ImageStore()

    private let directory: URL
    private let metadataURL: URL
    private var items: [GeneratedImage] = []

    init() {
        self.directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.metadataURL = directory.appendingPathComponent("images.json")
        loadFromDisk()
    }

    private func loadFromDisk() {
        do {
            let data = try Data(contentsOf: metadataURL)
            let decoded = try JSONDecoder().decode([GeneratedImage].self, from: data)
            self.items = decoded
        } catch {
            self.items = []
        }
    }

    private func persist() throws {
        let data = try JSONEncoder().encode(items)
        try data.write(to: metadataURL, options: [.atomic])
    }

    func getAll() -> [GeneratedImage] {
        items.sorted(by: { $0.date > $1.date })
    }

    func saveImage(data: Data, prompt: String) throws -> GeneratedImage {
        let id = UUID()
        let filename = "\(id.uuidString).png"
        let fileURL = directory.appendingPathComponent(filename)

        try data.write(to: fileURL, options: [.atomic])

        let item = GeneratedImage(id: id, prompt: prompt, date: Date(), filename: filename)
        items.append(item)
        try persist()
        return item
    }

    func deleteImage(_ image: GeneratedImage) throws {
        let url = directory.appendingPathComponent(image.filename)
        try? FileManager.default.removeItem(at: url)
        items.removeAll { $0.id == image.id }
        try persist()
    }
}
