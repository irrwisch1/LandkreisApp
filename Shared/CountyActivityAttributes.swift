import ActivityKit

struct CountyActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// nil while outside Germany
        var countyName: String?
        var status: CountyStatus
        var nextOpenName: String?
        var nextOpenDistance: Double?
    }
}
