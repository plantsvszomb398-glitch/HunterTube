import SwiftUI

@main
struct HunterTubeApp: App {
    @StateObject private var library = VideoLibrary()
    @StateObject private var theme = ThemeStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
                .environmentObject(theme)
                .preferredColorScheme(theme.darkMode ? .dark : .light)
                .tint(theme.accent)
        }
    }
}
