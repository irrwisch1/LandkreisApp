import SwiftUI
import CoreLocation

@MainActor
final class VisitStore: ObservableObject {
    typealias Status = CountyStatus

    @Published private(set) var finds: [String: Int] = [:]
    @Published private(set) var firstFinds: [String: Date] = [:]
    @Published private(set) var checked: [String: Date] = [:]
    @Published private(set) var visited: [String: Date] = [:]
    @Published private(set) var lastImport: Date?

    struct ImportResult {
        var finds: [String: Int] = [:]
        var firstFinds: [String: Date] = [:]
    }

    private struct Snapshot: Codable {
        var finds: [String: Int]
        var firstFinds: [String: Date]?
        var checked: [String: Date]?
        var visited: [String: Date]
        var lastImport: Date?
    }

    private let file = URL.documentsDirectory.appending(path: "landkreisjaeger.json")

    init() { load() }

    func status(_ ags: String) -> Status {
        if finds[ags, default: 0] > 0 { return .found }
        if checked[ags] != nil { return .checked }
        if visited[ags] != nil { return .visited }
        return .open
    }

    func isDone(_ ags: String) -> Bool {
        finds[ags, default: 0] > 0 || checked[ags] != nil
    }

    func firstVisit(_ ags: String) -> Date? {
        [visited[ags], firstFinds[ags], checked[ags]].compactMap { $0 }.min()
    }

    func setChecked(_ ags: String, _ isChecked: Bool) {
        checked[ags] = isChecked ? (checked[ags] ?? .now) : nil
        save()
    }

    @discardableResult
    func markVisited(_ ags: String) -> Bool {
        guard visited[ags] == nil else { return false }
        visited[ags] = .now
        save()
        return true
    }

    nonisolated static func assign(_ finds: [Find], to counties: [County],
                                   progress: (Double) -> Void = { _ in }) -> ImportResult {
        var result = ImportResult()
        for (i, f) in finds.enumerated() {
            if let c = counties.first(where: { $0.contains(f.coordinate) }) {
                result.finds[c.id, default: 0] += 1
                if let d = f.date {
                    result.firstFinds[c.id] = min(result.firstFinds[c.id] ?? d, d)
                }
            }
            if i % 250 == 0 { progress(Double(i) / Double(finds.count)) }
        }
        progress(1)
        return result
    }

    func setFinds(_ new: ImportResult) {
        finds = new.finds
        firstFinds = new.firstFinds
        checked = checked.filter { new.finds[$0.key, default: 0] == 0 }
        lastImport = .now
        save()
    }

    func reset() {
        finds = [:]; firstFinds = [:]; checked = [:]; visited = [:]; lastImport = nil
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: file),
              let s = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        finds = s.finds; firstFinds = s.firstFinds ?? [:]; checked = s.checked ?? [:]; visited = s.visited; lastImport = s.lastImport
    }

    private func save() {
        let s = Snapshot(finds: finds, firstFinds: firstFinds, checked: checked, visited: visited, lastImport: lastImport)
        try? JSONEncoder().encode(s).write(to: file, options: .atomic)
    }
}
