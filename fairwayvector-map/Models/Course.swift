import CoreLocation

struct GeoPoint: Codable, Hashable, Sendable {
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
    var handicapIndex: Int?
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
        handicapIndex: Int? = nil,
        path: [GeoPoint],
        green: [GeoPoint],
        fairways: [[GeoPoint]] = [],
        roughs: [[GeoPoint]] = [],
        tees: [[GeoPoint]] = [],
        pin: GeoPoint? = nil
    ) {
        self.number = number
        self.par = par
        self.handicapIndex = handicapIndex
        self.path = path
        self.green = green
        self.fairways = fairways
        self.roughs = roughs
        self.tees = tees
        self.pin = pin
    }

    private enum CodingKeys: String, CodingKey {
        case number, par, handicapIndex, path, green, fairways, roughs, tees, pin
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        number = try values.decode(Int.self, forKey: .number)
        par = try values.decodeIfPresent(Int.self, forKey: .par)
        handicapIndex = try values.decodeIfPresent(Int.self, forKey: .handicapIndex)
        path = try values.decode([GeoPoint].self, forKey: .path)
        green = try values.decode([GeoPoint].self, forKey: .green)
        fairways = try values.decodeIfPresent([[GeoPoint]].self, forKey: .fairways) ?? []
        roughs = try values.decodeIfPresent([[GeoPoint]].self, forKey: .roughs) ?? []
        tees = try values.decodeIfPresent([[GeoPoint]].self, forKey: .tees) ?? []
        pin = try values.decodeIfPresent(GeoPoint.self, forKey: .pin)
    }

    var length: Double {
        guard path.count > 1 else { return 0 }
        return zip(path, path.dropFirst()).reduce(0) { total, segment in
            total + GolfGeometry.distance(segment.0, segment.1)
        }
    }
}

struct CourseReference: Hashable {
    var osmRelationID: Int?
    var clubName: String
    var courseName: String
    var city: String
    var region: String
    var holeCount: Int
    var totalPar: Int
    var teeName: String
    var teeSex: String
    var courseRating: Double
    var slopeRating: Int

    var name: String { courseName }

    var cacheKey: String {
        [clubName, courseName, teeName, teeSex]
            .joined(separator: "-")
            .unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? String($0) : "-" }
            .joined()
            .lowercased()
    }

    init(selection: SelectedCourse) {
        osmRelationID = nil
        clubName = selection.club.name
        courseName = selection.course.name
        city = selection.club.city ?? ""
        region = selection.club.region ?? ""
        holeCount = selection.course.holes
        totalPar = selection.course.par
        teeName = selection.tee.tee
        teeSex = selection.tee.sex
        courseRating = selection.tee.courseRating
        slopeRating = selection.tee.slopeRating
    }

    init(osmRelationID: Int, name: String) {
        self.osmRelationID = osmRelationID
        clubName = name
        courseName = name
        city = ""
        region = ""
        holeCount = 18
        totalPar = 72
        teeName = ""
        teeSex = "male"
        courseRating = 0
        slopeRating = 0
    }

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
