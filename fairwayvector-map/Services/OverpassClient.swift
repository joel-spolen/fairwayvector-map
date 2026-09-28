import Foundation

struct OverpassElement: Decodable {
    var type: String
    var id: Int
    var lat: Double?
    var lon: Double?
    var tags: [String: String]?
    var geometry: [GeoPoint]?
}

private struct OverpassResponse: Decodable {
    var elements: [OverpassElement]
}

enum OverpassError: LocalizedError {
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): "OpenStreetMap returned status \(code). Try again shortly."
        }
    }
}

struct OverpassClient {
    static let endpoint = URL(string: "https://overpass-api.de/api/interpreter")!

    var session: URLSession = .shared

    func fetchGolfFeatures(courseRelationID: Int) async throws -> [OverpassElement] {
        // Overpass area IDs for relations are offset by 3.6 billion.
        let areaID = 3_600_000_000 + courseRelationID
        let query = """
        [out:json][timeout:25];area(id:\(areaID))->.c;(way["golf"="hole"](area.c);way["golf"="green"](area.c);node["golf"="pin"](area.c););out geom;
        """
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 40
        request.setValue("FairwayVectorMap/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("data=\(encoded)".utf8)

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw OverpassError.badStatus(http.statusCode)
        }
        return try Self.decode(data)
    }

    static func decode(_ data: Data) throws -> [OverpassElement] {
        try JSONDecoder().decode(OverpassResponse.self, from: data).elements
    }
}
