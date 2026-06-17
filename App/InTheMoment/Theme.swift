import SwiftUI

extension Color {
    /// App accent. Defined in code so the project works without asset-catalog colors,
    /// and mirrored by the `AccentColor` asset for the app icon tint.
    static let appAccent = Color(red: 0.40, green: 0.22, blue: 0.92)
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
