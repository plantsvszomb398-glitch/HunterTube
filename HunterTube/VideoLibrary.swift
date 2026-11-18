import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct SavedVideo: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var fileName: String
    var addedAt = Date()
    var isPrivate = false
}

@MainActor
final class VideoLibrary: ObservableObject {
    @Published var videos: [SavedVideo] = []
    @Published var selectedURL: URL?
    @Published var status = "Import videos from Files to get started."

    private let folderName = "HunterTubeVideos"

    init() {
        loadLibrary()
    }

    var folderURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = docs.appendingPathComponent(folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    func importVideo(from source: URL) {
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }

        let ext = source.pathExtension.isEmpty ? "mp4" : source.pathExtension
        let fileName = UUID().uuidString + "." + ext
        let destination = folderURL.appendingPathComponent(fileName)
        do {
            try FileManager.default.copyItem(at: source, to: destination)
            let item = SavedVideo(name: source.deletingPathExtension().lastPathComponent,
                                  fileName: fileName)
            videos.insert(item, at: 0)
            saveLibrary()
            status = "Imported \(item.name)"
        } catch {
            status = "Import failed: \(error.localizedDescription)"
        }
    }

    func url(for video: SavedVideo) -> URL {
        folderURL.appendingPathComponent(video.fileName)
    }

    func delete(_ video: SavedVideo) {
        try? FileManager.default.removeItem(at: url(for: video))
        videos.removeAll { $0.id == video.id }
        saveLibrary()
        status = "Video moved out of your library."
    }

    func rename(_ video: SavedVideo, to name: String) {
        guard let index = videos.firstIndex(where: { $0.id == video.id }) else { return }
        videos[index].name = name
        saveLibrary()
    }

    func togglePrivate(_ video: SavedVideo) {
        guard let index = videos.firstIndex(where: { $0.id == video.id }) else { return }
        videos[index].isPrivate.toggle()
        saveLibrary()
    }

    func saveLibrary() {
        let url = folderURL.appendingPathComponent("library.json")
        if let data = try? JSONEncoder().encode(videos) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func loadLibrary() {
        let url = folderURL.appendingPathComponent("library.json")
        guard let data = try? Data(contentsOf: url),
              let saved = try? JSONDecoder().decode([SavedVideo].self, from: data) else { return }
        videos = saved.filter { FileManager.default.fileExists(atPath: self.url(for: $0).path) }
    }

    func storageBytes() -> Int64 {
        videos.reduce(Int64(0)) { total, item in
            let values = try? url(for: item).resourceValues(forKeys: [.fileSizeKey])
            return total + Int64(values?.fileSize ?? 0)
        }
    }

    func exportURL(for video: SavedVideo) -> URL { url(for: video) }
}
