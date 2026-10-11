import Foundation
import CoreLocation

/// Unsimplified VG25 county borders for assigning finds. Written by Data/generate_borders.py.
struct CountyBorders: Sendable {
    private struct Box: Sendable {
        var minX = Int32.max, minY = Int32.max, maxX = Int32.min, maxY = Int32.min

        mutating func add(_ x: Int32, _ y: Int32) {
            minX = min(minX, x); maxX = max(maxX, x)
            minY = min(minY, y); maxY = max(maxY, y)
        }

        func contains(_ x: Int32, _ y: Int32) -> Bool {
            x >= minX && x <= maxX && y >= minY && y <= maxY
        }
    }

    private struct Polygon: Sendable {
        var box = Box()
        /// Outer ring and holes, as interleaved lon/lat in 1e-6 degrees
        var rings: [[Int32]] = []
    }

    private struct Entry: Sendable {
        let id: String
        var box = Box()
        var polygons: [Polygon] = []
    }

    enum LoadError: Error { case fileMissing, invalidData }

    private static let scale = 1_000_000.0
    private let entries: [Entry]
    private let index: [String: Int]

    static func load() throws -> CountyBorders {
        guard let url = Bundle.main.url(forResource: "county-borders", withExtension: "lzfse") else {
            throw LoadError.fileMissing
        }
        let data = try (Data(contentsOf: url) as NSData).decompressed(using: .lzfse) as Data
        return try CountyBorders(data)
    }

    private init(_ data: Data) throws {
        var entries: [Entry] = []
        try data.withUnsafeBytes { (buf: UnsafeRawBufferPointer) in
            var offset = 0
            func u32() throws -> Int {
                guard offset + 4 <= buf.count else { throw LoadError.invalidData }
                defer { offset += 4 }
                return Int(UInt32(littleEndian: buf.loadUnaligned(fromByteOffset: offset, as: UInt32.self)))
            }
            func i32() -> Int32 {
                defer { offset += 4 }
                return Int32(littleEndian: buf.loadUnaligned(fromByteOffset: offset, as: Int32.self))
            }

            guard buf.count >= 8, String(decoding: buf[0..<4], as: UTF8.self) == "LKB1" else {
                throw LoadError.invalidData
            }
            offset = 4
            let countyCount = try u32()
            entries.reserveCapacity(countyCount)
            for _ in 0..<countyCount {
                guard offset + 5 <= buf.count else { throw LoadError.invalidData }
                var entry = Entry(id: String(decoding: buf[offset..<offset + 5], as: UTF8.self))
                offset += 5
                for _ in 0..<(try u32()) {
                    var polygon = Polygon()
                    for _ in 0..<(try u32()) {
                        let n = try u32()
                        guard offset + n * 8 <= buf.count else { throw LoadError.invalidData }
                        var ring = [Int32](repeating: 0, count: n * 2)
                        var x: Int32 = 0, y: Int32 = 0
                        for i in 0..<n {
                            x &+= i32(); y &+= i32()
                            ring[2 * i] = x; ring[2 * i + 1] = y
                            polygon.box.add(x, y)
                        }
                        polygon.rings.append(ring)
                    }
                    entry.box.add(polygon.box.minX, polygon.box.minY)
                    entry.box.add(polygon.box.maxX, polygon.box.maxY)
                    entry.polygons.append(polygon)
                }
                entries.append(entry)
            }
        }
        self.entries = entries
        index = Dictionary(uniqueKeysWithValues: entries.enumerated().map { ($1.id, $0) })
    }

    private static func point(_ c: CLLocationCoordinate2D) -> (x: Int32, y: Int32) {
        (Int32((c.longitude * scale).rounded()), Int32((c.latitude * scale).rounded()))
    }

    /// AGS of the county containing the coordinate, nil outside Germany
    func county(at c: CLLocationCoordinate2D) -> String? {
        let (x, y) = Self.point(c)
        return entries.first { Self.contains($0, x, y) }?.id
    }

    func contains(_ id: String, _ c: CLLocationCoordinate2D) -> Bool {
        guard let i = index[id] else { return false }
        let (x, y) = Self.point(c)
        return Self.contains(entries[i], x, y)
    }

    /// Approximate distance in meters to the nearest border of the county
    func distanceToBorder(of id: String, from c: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let i = index[id] else { return nil }
        let (x, y) = Self.point(c)
        let kx = cos(c.latitude * .pi / 180) * 111_320 / Self.scale, ky = 110_540 / Self.scale
        var best = Double.infinity
        for polygon in entries[i].polygons {
            for ring in polygon.rings {
                let n = ring.count / 2
                for k in 0..<(n - 1) {
                    let ax = Double(ring[2 * k] - x) * kx, ay = Double(ring[2 * k + 1] - y) * ky
                    let bx = Double(ring[2 * k + 2] - x) * kx, by = Double(ring[2 * k + 3] - y) * ky
                    let dx = bx - ax, dy = by - ay, l2 = dx * dx + dy * dy
                    let t = l2 > 0 ? max(0, min(1, -(ax * dx + ay * dy) / l2)) : 0
                    let px = ax + t * dx, py = ay + t * dy
                    best = min(best, px * px + py * py)
                }
            }
        }
        return best.squareRoot()
    }

    private static func contains(_ entry: Entry, _ x: Int32, _ y: Int32) -> Bool {
        entry.box.contains(x, y) && entry.polygons.contains { $0.box.contains(x, y) && contains($0, x, y) }
    }

    /// Even-odd rule over all rings, so holes are excluded
    private static func contains(_ polygon: Polygon, _ x: Int32, _ y: Int32) -> Bool {
        let px = Double(x), py = Double(y)
        var inside = false
        for ring in polygon.rings {
            let n = ring.count / 2
            var j = n - 1
            for i in 0..<n {
                let xi = Double(ring[2 * i]), yi = Double(ring[2 * i + 1])
                let xj = Double(ring[2 * j]), yj = Double(ring[2 * j + 1])
                if (yi > py) != (yj > py), px < (xj - xi) * (py - yi) / (yj - yi) + xi {
                    inside.toggle()
                }
                j = i
            }
        }
        return inside
    }
}
