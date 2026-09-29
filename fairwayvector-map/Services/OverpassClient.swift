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
    case allServersFailed([String])

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): "OpenStreetMap returned status \(code). Try again shortly."
        case .allServersFailed:
            "OpenStreetMap course data is temporarily unavailable. Please retry when the network is stable."
        }
    }
}

struct OverpassClient {
    private static let endpoints = [
        URL(string: "https://overpass-api.de/api/interpreter")!,
        URL(string: "https://overpass.private.coffee/api/interpreter")!,
        URL(string: "https://overpass.nchc.org.tw/api/interpreter")!,
    ]

    var session: URLSession = .shared

    func fetchGolfFeatures(courseRelationID: Int) async throws -> [OverpassElement] {
        // Overpass area IDs for relations are offset by 3.6 billion.
        let areaID = 3_600_000_000 + courseRelationID
        let query = """
        [out:json][timeout:50];area(id:\(areaID))->.c;(way["golf"="hole"](area.c);way["golf"="green"](area.c);way["golf"="fairway"](area.c);way["golf"="rough"](area.c);way["golf"="tee"](area.c);node["golf"="pin"](area.c););out geom;
        """
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""

        var failures: [String] = []
        for endpoint in Self.endpoints {
            if Task.isCancelled { throw CancellationError() }
            do {
                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.timeoutInterval = 65
                request.setValue("FairwayVectorMap/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                request.httpBody = Data("data=\(encoded)".utf8)

                let (data, response) = try await session.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    throw OverpassError.badStatus(http.statusCode)
                }
                return try Self.decode(data)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                failures.append("\(endpoint.host ?? "Overpass"): \(error.localizedDescription)")
            }
        }
        throw OverpassError.allServersFailed(failures)
    }

    static func decode(_ data: Data) throws -> [OverpassElement] {
        try JSONDecoder().decode(OverpassResponse.self, from: data).elements
    }
}
