import SwiftUI

enum AccentPreset: String, CaseIterable, Identifiable {
    case purple, blue, teal, rose, orange, emerald

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var primary: Color {
        switch self {
        case .purple:  return Color(hex: 0x9C6AFF)
        case .blue:    return Color(hex: 0x60A5FA)
        case .teal:    return Color(hex: 0x2DD4BF)
        case .rose:    return Color(hex: 0xFB7185)
        case .orange:  return Color(hex: 0xFB923C)
        case .emerald: return Color(hex: 0x34D399)
        }
    }

    var primaryLight: Color {
        switch self {
        case .purple:  return Color(hex: 0xB794FF)
        case .blue:    return Color(hex: 0x93C5FD)
        case .teal:    return Color(hex: 0x5EEAD4)
        case .rose:    return Color(hex: 0xFDA4AF)
        case .orange:  return Color(hex: 0xFDBA74)
        case .emerald: return Color(hex: 0x6EE7B7)
        }
    }

    var primaryDark: Color {
        switch self {
        case .purple:  return Color(hex: 0x7C3AED)
        case .blue:    return Color(hex: 0x3B82F6)
        case .teal:    return Color(hex: 0x14B8A6)
        case .rose:    return Color(hex: 0xF43F5E)
        case .orange:  return Color(hex: 0xF97316)
        case .emerald: return Color(hex: 0x10B981)
        }
    }
}

class ThemeManager: ObservableObject {
    @AppStorage("accentColor") var accentColorKey: String = AccentPreset.purple.rawValue
    @AppStorage("appTheme") var appThemeKey: String = AppTheme.dark.rawValue

    var current: AccentPreset {
        AccentPreset(rawValue: accentColorKey) ?? .purple
    }

    var primary: Color { current.primary }
    var primaryLight: Color { current.primaryLight }
    var primaryDark: Color { current.primaryDark }

    var appTheme: AppTheme {
        AppTheme(rawValue: appThemeKey) ?? .dark
    }

    var colorScheme: ColorScheme? {
        switch appTheme {
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    func select(_ preset: AccentPreset) {
        accentColorKey = preset.rawValue
        objectWillChange.send()
    }

    func selectTheme(_ theme: AppTheme) {
        appThemeKey = theme.rawValue
        objectWillChange.send()
    }
}

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}
