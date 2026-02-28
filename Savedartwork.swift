import Foundation
import PencilKit
import SwiftUI

// MARK: - SavedArtwork Model

struct SavedArtwork: Identifiable, Codable {
    let id: UUID
    var title: String
    let date: Date
    let stabilityScore: Int
    let pressureScore: Int
    let rhythmScore: Int
    let strokeCount: Int
    let drawingData: Data

    init(
        id: UUID = UUID(),
        title: String,
        date: Date = Date(),
        stabilityScore: Int,
        pressureScore: Int = 0,
        rhythmScore: Int = 0,
        strokeCount: Int = 0,
        drawing: PKDrawing,
        drillType: String? = nil
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.stabilityScore = stabilityScore
        self.pressureScore = pressureScore
        self.rhythmScore = rhythmScore
        self.strokeCount = strokeCount
        self.drawingData = drawing.dataRepresentation()
    }

    var drawing: PKDrawing {
        (try? PKDrawing(data: drawingData)) ?? PKDrawing()
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy"
        return f.string(from: date)
    }

    var shortDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    func thumbnail(size: CGSize = CGSize(width: 400, height: 300)) -> UIImage {
        let d = drawing
        guard !d.strokes.isEmpty else { return UIImage() }
        let bounds = d.bounds.isEmpty
            ? CGRect(origin: .zero, size: size)
            : d.bounds.insetBy(dx: -20, dy: -20)
        let scale = min(size.width / bounds.width, size.height / bounds.height)
        return d.image(from: bounds, scale: scale)
    }
}

// MARK: - Gallery Store

final class GalleryStore: ObservableObject {

    @Published private(set) var artworks: [SavedArtwork] = []

    private var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("gallery.json")
    }

    init() {
        load()
        DemoArtworkSeeder.seed(into: self)
    }

    func save(_ artwork: SavedArtwork) {
        artworks.insert(artwork, at: 0)
        persist()
    }

    func delete(_ artwork: SavedArtwork) {
        artworks.removeAll { $0.id == artwork.id }
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(artworks)
            try data.write(to: fileURL, options: .atomic)
        } catch { print("GalleryStore save error: \(error)") }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            artworks = try JSONDecoder().decode([SavedArtwork].self, from: data)
        } catch {
            print("GalleryStore load error: \(error)")
            artworks = []
        }
    }
}
