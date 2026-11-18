import SwiftUI

@MainActor
final class ThemeStore: ObservableObject {
    @Published var hue: Double = 0.58
    @Published var saturation: Double = 0.82
    @Published var brightness: Double = 0.88
    @Published var darkMode = true

    var accent: Color {
        Color(hue: hue, saturation: saturation, brightness: brightness)
    }
}
