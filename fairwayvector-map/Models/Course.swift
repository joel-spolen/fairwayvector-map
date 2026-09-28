import CoreLocation

struct GeoPoint: Codable, Hashable {
    var lat: Double
    var lon: Double

    init(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(lat: coordinate.latitude, lon: coordinate.longitude)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct Hole: Codable, Hashable, Identifiable {
    var number: Int
    var par: Int?
    /// Line of play from tee to green, as mapped in OpenStreetMap.
    var path: [GeoPoint]
    var green: [GeoPoint]
    var pin: GeoPoint?

    var id: Int { number }
    var tee: GeoPoint? { path.first }

    var greenCenter: GeoPoint? {
        green.count >= 3 ? GolfGeometry.centroid(of: green) : path.last
    }

    var flag: GeoPoint? { pin ?? greenCenter }
}

struct CourseReference: Hashable {
    var osmRelationID: Int
    var name: String

    static let hills = CourseReference(osmRelationID: 10480238, name: "Hills Golf & Country Club")
}

struct Course: Codable {
    var osmRelationID: Int
    var name: String
    var holes: [Hole]
    var fetchedAt: Date
}

enum DistanceUnit: String, CaseIterable, Identifiable {
    case meters
    case yards

    var id: String { rawValue }

    var title: String {
        switch self {
        case .meters: "Meters"
        case .yards: "Yards"
        }
    }

    var symbol: String {
        switch self {
        case .meters: "m"
        case .yards: "yd"
        }
    }

    func value(_ meters: Double) -> Int {
        let converted = self == .meters ? meters : meters / 0.9144
        return Int(converted.rounded())
    }

    func format(_ meters: Double) -> String {
        "\(value(meters)) \(symbol)"
    }
}
