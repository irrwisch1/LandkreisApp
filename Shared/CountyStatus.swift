import SwiftUI

enum CountyStatus: String, Codable, Hashable {
    case found, checked, visited, open

    var isDone: Bool { self == .found || self == .checked }

    var color: Color {
        switch self {
        case .found: .green
        case .checked: .teal
        case .visited: .orange
        case .open: .red
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
