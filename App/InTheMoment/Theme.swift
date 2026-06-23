import SwiftUI

extension Color {
    /// App accent. Defined in code so the project works without asset-catalog colors,
    /// and mirrored by the `AccentColor` asset for the app icon tint.
    static let appAccent = Color(red: 0.40, green: 0.22, blue: 0.92)
}

enum AppTheme: String, CaseIterable, Identifiable {
    case light
    case dark

    static let storageKey = "appTheme"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        }
    }
}

extension DateFormatter {
    static let eventDay: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}

extension Date {
    var eventDayString: String { DateFormatter.eventDay.string(from: self) }
}
