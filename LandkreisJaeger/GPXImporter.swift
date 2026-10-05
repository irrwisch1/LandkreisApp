import Foundation
import CoreLocation

struct Find {
    let coordinate: CLLocationCoordinate2D
    let date: Date?
}

final class GPXImporter: NSObject, XMLParserDelegate {
    private static let findLogTypes: Set<String> = ["found it", "attended", "webcam photo taken"]

    private var finds: [Find] = []
    private var lineCount = 1
    private var progress: ((Double) -> Void)?

    private var coordinate: CLLocationCoordinate2D?
    private var firstFindDate: Date?
    private var inLog = false
    private var logDate: Date?
    private var logType = ""
    private var text: String?

    static func read(_ url: URL, progress: @escaping (Double) -> Void = { _ in }) -> [Find] {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard var data = try? Data(contentsOf: url) else { return [] }
        if ZIPArchive.isZIP(data) { return readZIP(data, progress: progress) }
        blankInvalidCharacterReferences(&data)
        return parse(data, progress: progress)
    }

    private static func readZIP(_ data: Data, progress: @escaping (Double) -> Void) -> [Find] {
        guard let zip = try? ZIPArchive(data: data) else { return [] }
        let entries = zip.entries.filter { isCacheGPX($0.name) }
        let total = Double(max(entries.reduce(0) { $0 + $1.uncompressedSize }, 1))
        var done = 0
        var finds: [Find] = []
        for entry in entries {
            guard var gpx = try? zip.extract(entry) else { continue }
            blankInvalidCharacterReferences(&gpx)
            let base = Double(done), size = Double(entry.uncompressedSize)
            finds += parse(gpx) { f in progress((base + f * size) / total) }
            done += entry.uncompressedSize
        }
        return finds
    }

    private static func isCacheGPX(_ path: String) -> Bool {
        let name = (path as NSString).lastPathComponent.lowercased()
        return name.hasSuffix(".gpx") && !name.hasSuffix("-wpts.gpx")
            && !name.hasPrefix("._") && !path.hasPrefix("__MACOSX/")
    }

    private static func parse(_ data: Data, progress: @escaping (Double) -> Void) -> [Find] {
        let parser = XMLParser(data: data)
        let importer = GPXImporter()
        importer.lineCount = countLines(data)
        importer.progress = progress
        parser.delegate = importer
        parser.parse()
        progress(1)
        return importer.finds
    }

    private static func countLines(_ data: Data) -> Int {
        data.withUnsafeBytes { buffer in
            guard var p = buffer.baseAddress, !buffer.isEmpty else { return 1 }
            let end = p + buffer.count
            var lines = 1
            while let hit = memchr(p, 0x0A, p.distance(to: end)) {
                lines += 1
                p = UnsafeRawPointer(hit) + 1
            }
            return lines
        }
    }

    private static func blankInvalidCharacterReferences(_ data: inout Data) {
        let needle: [UInt8] = [0x26, 0x23]
        data.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress, buffer.count > 3 else { return }
            let n = buffer.count
            var i = 0
            while i < n - 2, let hit = memmem(base + i, n - i, needle, 2) {
                let start = base.distance(to: hit)
                var j = start + 2
                let hex = j < n && (buffer[j] | 0x20) == 0x78
                if hex { j += 1 }
                var value: UInt32 = 0
                var digits = 0
                while j < n, digits < 8, let d = digitValue(buffer[j], hex: hex) {
                    value = value * (hex ? 16 : 10) + d
                    j += 1
                    digits += 1
                }
                if digits > 0, j < n, buffer[j] == 0x3B, !isValidXMLChar(value) {
                    for k in start...j { buffer[k] = 0x20 }
                }
                i = start + 2
            }
        }
    }

    private static func digitValue(_ b: UInt8, hex: Bool) -> UInt32? {
        switch b {
        case 0x30...0x39: UInt32(b - 0x30)
        case 0x61...0x66 where hex: UInt32(b - 0x61 + 10)
        case 0x41...0x46 where hex: UInt32(b - 0x41 + 10)
        default: nil
        }
    }

    private static func isValidXMLChar(_ v: UInt32) -> Bool {
        v == 0x9 || v == 0xA || v == 0xD || (0x20...0xD7FF).contains(v)
            || (0xE000...0xFFFD).contains(v) || (0x10000...0x10FFFF).contains(v)
    }

    private static func day(_ s: String) -> Date? {
        let parts = s.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }

    private func localName(_ name: String) -> Substring {
        name.split(separator: ":").last ?? Substring(name)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes: [String: String] = [:]) {
        switch localName(elementName) {
        case "wpt":
            coordinate = nil
            firstFindDate = nil
            if let lat = attributes["lat"].flatMap(Double.init), let lon = attributes["lon"].flatMap(Double.init) {
                coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        case "log":
            inLog = true
            logDate = nil
            logType = ""
        case "date" where inLog, "type" where inLog:
            text = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text?.append(string)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        switch localName(elementName) {
        case "date" where inLog:
            logDate = text.flatMap(Self.day)
            text = nil
        case "type" where inLog:
            logType = text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            text = nil
        case "log":
            inLog = false
            if Self.findLogTypes.contains(logType), let d = logDate {
                firstFindDate = min(firstFindDate ?? d, d)
            }
        case "wpt":
            guard let c = coordinate else { return }
            finds.append(Find(coordinate: c, date: firstFindDate))
            coordinate = nil
            if finds.count % 250 == 0 {
                progress?(min(Double(parser.lineNumber) / Double(lineCount), 1))
            }
        default:
            break
        }
    }
}
