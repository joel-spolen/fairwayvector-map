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
    var fairways: [[GeoPoint]] = []
    var roughs: [[GeoPoint]] = []
    var tees: [[GeoPoint]] = []
    var pin: GeoPoint?

    var id: Int { number }
    var tee: GeoPoint? { path.first }

    var greenCenter: GeoPoint? {
        green.count >= 3 ? GolfGeometry.centroid(of: green) : path.last
    }

    var flag: GeoPoint? { pin ?? greenCenter }

    init(
        number: Int,
        par: Int?,
        path: [GeoPoint],
        green: [GeoPoint],
        fairways: [[GeoPoint]] = [],
        roughs: [[GeoPoint]] = [],
        tees: [[GeoPoint]] = [],
        pin: GeoPoint? = nil
    ) {
        self.number = number
        self.par = par
        self.path = path
        self.green = green
        self.fairways = fairways
        self.roughs = roughs
        self.tees = tees
        self.pin = pin
    }

    private enum CodingKeys: String, CodingKey {
        case number, par, path, green, fairways, roughs, tees, pin
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        number = try values.decode(Int.self, forKey: .number)
        par = try values.decodeIfPresent(Int.self, forKey: .par)
        path = try values.decode([GeoPoint].self, forKey: .path)
        green = try values.decode([GeoPoint].self, forKey: .green)
        fairways = try values.decodeIfPresent([[GeoPoint]].self, forKey: .fairways) ?? []
        roughs = try values.decodeIfPresent([[GeoPoint]].self, forKey: .roughs) ?? []
        tees = try values.decodeIfPresent([[GeoPoint]].self, forKey: .tees) ?? []
        pin = try values.decodeIfPresent(GeoPoint.self, forKey: .pin)
    }
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
