import SwiftUI
import UniformTypeIdentifiers
import AVKit
import LocalAuthentication

struct ContentView: View {
    @EnvironmentObject var library: VideoLibrary
    @EnvironmentObject var theme: ThemeStore
    @State private var showImporter = false
    @State private var showTheme = false
    @State private var showStorage = false
    @State private var showSettings = false
    @State private var showTools = false
    @State private var search = ""
    @State private var selectedVideo: SavedVideo?
    @State private var showPrivate = false
    @State private var unlocked = false
    @State private var alertMessage: String?

    private var visibleVideos: [SavedVideo] {
        library.videos.filter { video in
            (showPrivate ? video.isPrivate : !video.isPrivate) &&
            (search.isEmpty || video.name.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                if visibleVideos.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "play.rectangle.on.rectangle")
                            .font(.system(size: 56))
                            .foregroundStyle(.secondary)
                        Text(showPrivate ? "Private folder is empty" : "Your library is empty")
                            .font(.title2.bold())
                        Text("Import personal video files to build your offline library.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(visibleVideos) { video in
                            VideoRow(video: video, fileURL: library.url(for: video)) {
                                selectedVideo = video
                            } menu: {
                                videoMenu(video)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
                if !library.status.isEmpty {
                    Text(library.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.horizontal)
                        .padding(.vertical, 7)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showImporter) {
                DocumentPicker { url in library.importVideo(from: url) }
            }
            .sheet(isPresented: $showTheme) { ThemeStudioView() }
            .sheet(isPresented: $showStorage) { StorageView() }
            .sheet(isPresented: $showTools) { HunterToolsView() }
            .sheet(item: $selectedVideo) { video in
                VideoPlayerScreen(video: video, url: library.url(for: video))
            }
            .alert("HunterTube", isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) { alertMessage = nil }
            } message: { Text(alertMessage ?? "") }
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("HunterTube")
                        .font(.largeTitle.bold())
                    Text("Your personal video library")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { showTheme = true } label: {
                    Image(systemName: "paintpalette").font(.title2)
                }
                .accessibilityLabel("Theme Studio")
                Button { showStorage = true } label: {
                    Image(systemName: "externaldrive").font(.title2)
                }
                .accessibilityLabel("Storage Guardian")
                Button { showTools = true } label: {
                    Image(systemName: "wrench.and.screwdriver").font(.title2)
                }
                .accessibilityLabel("HunterTube Tools")
            }
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search your saved videos", text: $search)
                    .textInputAutocapitalization(.never)
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                }
            }
            .padding(11)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 13))
            HStack(spacing: 10) {
                Button { showImporter = true } label: {
                    Label("Import videos", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button {
                    if showPrivate {
                        showPrivate = false
                    } else {
                        authenticateForPrivate()
                    }
                } label: {
                    Label(showPrivate ? "Library" : "Private", systemImage: showPrivate ? "video" : "lock")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }

    @ViewBuilder private func videoMenu(_ video: SavedVideo) -> some View {
        Button("Rename", systemImage: "pencil") {
            alertMessage = "Rename is available through the video details in this starter build."
        }
        Button(video.isPrivate ? "Remove from Private" : "Move to Private", systemImage: "lock") {
            library.togglePrivate(video)
        }
        ShareLink(item: library.exportURL(for: video)) {
            Label("Export video", systemImage: "square.and.arrow.up")
        }
        Button("Delete", systemImage: "trash", role: .destructive) {
            library.delete(video)
        }
    }

    private func authenticateForPrivate() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            alertMessage = "Device authentication is not available. Set a device passcode to use this feature."
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your HunterTube private folder") { success, _ in
            DispatchQueue.main.async {
                if success { showPrivate = true }
                else { alertMessage = "Authentication was not successful." }
            }
        }
    }
}

struct VideoRow: View {
    let video: SavedVideo
    let fileURL: URL
    let play: () -> Void
    let menu: () -> AnyView

    init(video: SavedVideo, fileURL: URL, play: @escaping () -> Void, @ViewBuilder menu: @escaping () -> some View) {
        self.video = video
        self.fileURL = fileURL
        self.play = play
        self.menu = { AnyView(menu()) }
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: play) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.16))
                    Image(systemName: "play.fill").font(.title2).foregroundStyle(.tint)
                }
                .frame(width: 76, height: 58)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 4) {
                Text(video.name).font(.headline).lineLimit(2)
                Text(fileURL.lastPathComponent)
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                Text(video.addedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Menu { menu() } label: { Image(systemName: "ellipsis").padding(8) }
        }
        .padding(.vertical, 5)
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.movie, .video, .mpeg4Movie], asCopy: false)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            urls.forEach(onPick)
        }
    }
}

struct VideoPlayerScreen: View {
    let video: SavedVideo
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var speed = 1.0

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                if let player {
                    VideoPlayer(player: player)
                        .aspectRatio(16/9, contentMode: .fit)
                        .background(.black)
                } else {
                    ProgressView()
                }
                Text(video.name).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Text("Playback speed")
                    Spacer()
                    Picker("Speed", selection: $speed) {
                        Text("0.5×").tag(0.5)
                        Text("0.75×").tag(0.75)
                        Text("1×").tag(1.0)
                        Text("1.25×").tag(1.25)
                        Text("1.5×").tag(1.5)
                        Text("2×").tag(2.0)
                    }
                    .pickerStyle(.menu)
                    .onChange(of: speed) { newValue in
                        player?.rate = Float(newValue)
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Video Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .onAppear {
                let p = AVPlayer(url: url)
                player = p
                p.play()
            }
            .onDisappear { player?.pause() }
        }
    }
}

struct ThemeStudioView: View {
    @EnvironmentObject var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Color wheel") {
                    ColorPicker("Choose accent color", selection: Binding(
                        get: { theme.accent },
                        set: { color in
                            let ui = UIColor(color)
                            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                            ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
                            theme.hue = Double(h); theme.saturation = Double(s); theme.brightness = Double(b)
                        }
                    ), supportsOpacity: false)
                    HStack {
                        Circle().fill(theme.accent).frame(width: 54, height: 54)
                        VStack(alignment: .leading) {
                            Text("Live preview").font(.headline)
                            Text("Your selected accent color").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Slider(value: $theme.hue, in: 0...1)
                    Slider(value: $theme.saturation, in: 0...1)
                    Slider(value: $theme.brightness, in: 0.2...1)
                }
                Section("Appearance") {
                    Toggle("Dark appearance", isOn: $theme.darkMode)
                }
                Section {
                    Button("Reset theme") {
                        theme.hue = 0.58; theme.saturation = 0.82; theme.brightness = 0.88; theme.darkMode = true
                    }
                }
            }
            .navigationTitle("Theme Studio")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

struct StorageView: View {
    @EnvironmentObject var library: VideoLibrary
    @Environment(\.dismiss) private var dismiss
    private var bytes: Int64 { library.storageBytes() }
    private var formatted: String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
    var body: some View {
        NavigationStack {
            List {
                Section("HunterTube storage") {
                    Label(formatted, systemImage: "externaldrive")
                        .font(.title2.bold())
                    Text("\(library.videos.count) saved videos")
                        .foregroundStyle(.secondary)
                }
                Section("Library") {
                    ForEach(library.videos.sorted { size(of: $0) > size(of: $1) }) { video in
                        HStack {
                            Text(video.name).lineLimit(1)
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: size(of: video), countStyle: .file))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Storage Guardian")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
    private func size(of video: SavedVideo) -> Int64 {
        let values = try? library.url(for: video).resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }
}
