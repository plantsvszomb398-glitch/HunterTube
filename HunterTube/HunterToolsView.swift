import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import CryptoKit

struct HunterToolsView: View {
    @EnvironmentObject var library: VideoLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var duplicateGroups: [[SavedVideo]] = []
    @State private var selectedInfo: SavedVideo?
    @State private var message: String?
    @State private var isScanning = false

    var body: some View {
        NavigationStack {
            List {
                Section("Library maintenance") {
                    Button {
                        scanDuplicates()
                    } label: {
                        Label(isScanning ? "Scanning…" : "Find duplicate videos", systemImage: "doc.on.doc")
                    }
                    .disabled(isScanning)

                    NavigationLink {
                        VideoInspectorView()
                    } label: {
                        Label("Video information inspector", systemImage: "info.circle")
                    }

                    NavigationLink {
                        BatchManagerView()
                    } label: {
                        Label("Batch file manager", systemImage: "checklist")
                    }
                }

                Section("Backup and recovery") {
                    ShareLink(item: backupFileURL()) {
                        Label("Export library backup", systemImage: "archivebox")
                    }
                    Text("The backup contains HunterTube's library index. Video files can be exported separately from each video's menu.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Smart tools") {
                    NavigationLink {
                        StorageForecastView()
                    } label: {
                        Label("Storage forecast", systemImage: "chart.bar")
                    }
                    NavigationLink {
                        ImportHelpView()
                    } label: {
                        Label("Import recovery & compatibility", systemImage: "arrow.clockwise")
                    }
                }

                if !duplicateGroups.isEmpty {
                    Section("Possible duplicates") {
                        ForEach(Array(duplicateGroups.enumerated()), id: \.offset) { _, group in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(group.first?.name ?? "Duplicate group").font(.headline)
                                ForEach(group) { item in
                                    HStack {
                                        Text(item.name).lineLimit(1)
                                        Spacer()
                                        Text(fileSize(item)).foregroundStyle(.secondary)
                                    }
                                    .font(.caption)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("HunterTube Tools")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .alert("HunterTube Tools", isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button("OK", role: .cancel) { message = nil }
            } message: { Text(message ?? "") }
        }
    }

    private func scanDuplicates() {
        isScanning = true
        Task.detached(priority: .utility) {
            var buckets: [String: [SavedVideo]] = [:]
            for item in await library.videos {
                let url = await library.url(for: item)
                let digest = Self.digest(url: url)
                if let digest { buckets[digest, default: []].append(item) }
            }
            let groups = buckets.values.filter { $0.count > 1 }
            await MainActor.run {
                duplicateGroups = groups
                isScanning = false
                if groups.isEmpty { message = "No exact duplicate files were found." }
            }
        }
    }

    private static func digest(url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let data = try? handle.read(upToCount: 1024 * 1024)
            if let data, !data.isEmpty { hasher.update(data: data); return true }
            return false
        }) {}
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func backupFileURL() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("HunterTube-Library-Backup.json")
        let data = (try? JSONEncoder().encode(library.videos)) ?? Data("[]".utf8)
        try? data.write(to: url, options: .atomic)
        return url
    }

    private func fileSize(_ video: SavedVideo) -> String {
        let values = try? library.url(for: video).resourceValues(forKeys: [.fileSizeKey])
        return ByteCountFormatter.string(fromByteCount: Int64(values?.fileSize ?? 0), countStyle: .file)
    }
}

struct VideoInspectorView: View {
    @EnvironmentObject var library: VideoLibrary
    var body: some View {
        List(library.videos) { video in
            let url = library.url(for: video)
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey, .creationDateKey])
            let asset = AVURLAsset(url: url)
            VStack(alignment: .leading, spacing: 5) {
                Text(video.name).font(.headline)
                LabeledContent("File size", value: ByteCountFormatter.string(fromByteCount: Int64(values?.fileSize ?? 0), countStyle: .file))
                LabeledContent("Format", value: url.pathExtension.uppercased())
                LabeledContent("Added", value: video.addedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Location", value: "HunterTube local library")
                Text("Duration and codec details are read from the media asset when available.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Load media details") {
                    Task {
                        _ = try? await asset.load(.duration)
                    }
                }
                .font(.caption)
            }
            .padding(.vertical, 5)
        }
        .navigationTitle("Video Inspector")
    }
}

struct BatchManagerView: View {
    @EnvironmentObject var library: VideoLibrary
    @State private var selected = Set<UUID>()
    @State private var confirmDelete = false

    var body: some View {
        List {
            Section {
                HStack {
                    Button("Select all") { selected = Set(library.videos.map(\.id)) }
                    Spacer()
                    Button("Clear") { selected.removeAll() }
                }
            }
            ForEach(library.videos) { video in
                Button {
                    if selected.contains(video.id) { selected.remove(video.id) }
                    else { selected.insert(video.id) }
                } label: {
                    HStack {
                        Image(systemName: selected.contains(video.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(.tint)
                        Text(video.name).foregroundStyle(.primary)
                        Spacer()
                    }
                }
            }
            Section {
                Button("Delete selected", role: .destructive) { confirmDelete = true }
                    .disabled(selected.isEmpty)
            }
        }
        .navigationTitle("Batch Manager")
        .confirmationDialog("Delete \(selected.count) selected videos?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete videos", role: .destructive) {
                let chosen = library.videos.filter { selected.contains($0.id) }
                chosen.forEach(library.delete)
                selected.removeAll()
            }
        }
    }
}

struct StorageForecastView: View {
    @EnvironmentObject var library: VideoLibrary
    @State private var dailyVideos = 2.0
    @State private var averageMB = 250.0
    var projectedGB: Double { dailyVideos * averageMB * 30 / 1024 }
    var body: some View {
        Form {
            Section("Estimate your next 30 days") {
                Stepper("Videos per day: \(Int(dailyVideos))", value: $dailyVideos, in: 0...30)
                VStack(alignment: .leading) {
                    Text("Average video size: \(Int(averageMB)) MB")
                    Slider(value: $averageMB, in: 10...2000, step: 10)
                }
                LabeledContent("Estimated storage", value: String(format: "%.2f GB", projectedGB))
            }
            Section("Current library") {
                LabeledContent("Saved videos", value: "\(library.videos.count)")
                LabeledContent("Currently used", value: ByteCountFormatter.string(fromByteCount: library.storageBytes(), countStyle: .file))
            }
        }
        .navigationTitle("Storage Forecast")
    }
}

struct ImportHelpView: View {
    var body: some View {
        List {
            Section("If an import stops") {
                Text("Open HunterTube again and retry the import from Files. The original source file is not changed.")
                Text("Keep HunterTube open until a large file finishes copying.")
            }
            Section("Supported media") {
                Text("The iOS document picker accepts common movie and video file types. Playback depends on the codecs supported by iOS.")
                Text("If a file will not play, convert a copy to a widely supported format such as H.264 video in an MP4 container.")
            }
        }
        .navigationTitle("Import Help")
    }
}
