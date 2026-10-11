import Foundation
import MapKit

enum Geo {
    static func ring(_ pts: UnsafeMutablePointer<MKMapPoint>, count n: Int, contains p: MKMapPoint) -> Bool {
        var inside = false
        var j = n - 1
        for i in 0..<n {
            let a = pts[i], b = pts[j]
            if (a.y > p.y) != (b.y > p.y) {
                let x = (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x
                if p.x < x { inside.toggle() }
            }
            j = i
        }
        return inside
    }

    static func polygon(_ poly: MKPolygon, contains p: MKMapPoint) -> Bool {
        guard poly.boundingMapRect.contains(p),
              ring(poly.points(), count: poly.pointCount, contains: p) else { return false }
        for hole in poly.interiorPolygons ?? [] where ring(hole.points(), count: hole.pointCount, contains: p) {
            return false
        }
        return true
    }

    static func nearestPoint(onSegment a: MKMapPoint, _ b: MKMapPoint, to p: MKMapPoint) -> MKMapPoint {
        let dx = b.x - a.x, dy = b.y - a.y
        let length2 = dx * dx + dy * dy
        guard length2 > 0 else { return a }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / length2))
        return MKMapPoint(x: a.x + t * dx, y: a.y + t * dy)
    }

    static func bearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let φ1 = a.latitude * .pi / 180, φ2 = b.latitude * .pi / 180
        let Δλ = (b.longitude - a.longitude) * .pi / 180
        let y = sin(Δλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    static func compassDirection(_ degrees: Double) -> String {
        ["N", "NO", "O", "SO", "S", "SW", "W", "NW"][Int((degrees + 22.5) / 45) % 8]
    }
}

enum FederalState {
    static let names: [String: String] = [
        "01": "Schleswig-Holstein", "02": "Hamburg", "03": "Niedersachsen", "04": "Bremen",
        "05": "Nordrhein-Westfalen", "06": "Hessen", "07": "Rheinland-Pfalz", "08": "Baden-Württemberg",
        "09": "Bayern", "10": "Saarland", "11": "Berlin", "12": "Brandenburg",
        "13": "Mecklenburg-Vorpommern", "14": "Sachsen", "15": "Sachsen-Anhalt", "16": "Thüringen"
    ]
    static func name(forKey key: String) -> String { names[key] ?? "Unbekannt" }
}

extension MKCoordinateRegion {
    static let germany = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.16, longitude: 10.45),
        span: MKCoordinateSpan(latitudeDelta: 9.5, longitudeDelta: 9.5))
}
