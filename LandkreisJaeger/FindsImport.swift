import Foundation
import CoreLocation

@MainActor
final class FindsImport: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var progress = 0.0
    @Published private(set) var phase = ""

    func run(url: URL, counties: [County], visits: VisitStore) async -> (total: Int, matched: Int) {
        isRunning = true
        progress = 0
        phase = "Datei wird gelesen …"
        defer { isRunning = false }

        let (updates, continuation) = AsyncStream.makeStream(of: (Double, String).self,
                                                             bufferingPolicy: .bufferingNewest(1))
        let work = Task.detached(priority: .userInitiated) { () -> (total: Int, result: VisitStore.ImportResult) in
            defer { continuation.finish() }
            let finds = GPXImporter.read(url) { f in
                continuation.yield((f * 0.8, "Funde werden gelesen …"))
            }
            let result = VisitStore.assign(finds, to: counties) { f in
                continuation.yield((0.8 + f * 0.2, "Kreise werden zugeordnet …"))
            }
            return (finds.count, result)
        }

        for await (value, text) in updates {
            progress = value
            phase = text
        }
        let (total, result) = await work.value
        visits.setFinds(result)
        return (total, result.finds.values.reduce(0, +))
    }
}
