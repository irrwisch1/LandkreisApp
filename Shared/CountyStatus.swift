import SwiftUI

enum CountyStatus: String, Codable, Hashable {
    case found, checked, visited, open

    var isDone: Bool { self == .found || self == .checked }

    var color: Color {
        switch self {
        case .found: .green
        case .checked: .blue
        case .visited: .orange
        case .open: .red
        }
    }

    /// Darker than `color` so borders between counties of the same status stay visible
    var borderColor: Color {
        switch self {
        case .found: Color(red: 0.0, green: 0.42, blue: 0.13)
        case .checked: Color(red: 0.0, green: 0.2, blue: 0.65)
        case .visited: Color(red: 0.72, green: 0.36, blue: 0.0)
        case .open: Color(red: 0.7, green: 0.0, blue: 0.0)
        }
    }

    var text: String {
        switch self {
        case .found: "Cache gefunden"
        case .checked: "Abgehakt, noch nicht im Import"
        case .visited: "Betreten, aber noch kein Fund"
        case .open: "Noch offen"
        }
    }

    var shortText: String {
        switch self {
        case .found: "Gefunden"
        case .checked: "Abgehakt"
        case .visited, .open: "Noch kein Fund"
        }
    }
}

enum Format {
    static func km(_ meters: Double) -> String {
        if meters < 1000 { return "\(Int(meters.rounded())) m" }
        let s = String(format: meters < 10_000 ? "%.1f km" : "%.0f km", meters / 1000)
        return s.replacingOccurrences(of: ".", with: ",")
    }
}
