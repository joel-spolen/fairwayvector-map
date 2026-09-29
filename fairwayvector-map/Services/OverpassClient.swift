import Foundation

struct OverpassElement: Decodable, Sendable {
    var type: String
    var id: Int
    var lat: Double?
    var lon: Double?
    var tags: [String: String]?
    var geometry: [GeoPoint]?
    var center: GeoPoint?
}

private struct OverpassResponse: Decodable, Sendable {
    var elements: [OverpassElement]
}

enum OverpassError: LocalizedError {
    case badStatus(Int)
    case allServersFailed([String])
    case courseNotFound(String)

    var errorDescription: String? {
        switch self {
        case .badStatus(let code):
            return "OpenStreetMap returned status \(code). Try again shortly."
        case .allServersFailed(let failures):
            let details = failures.joined(separator: "; ")
            return details.isEmpty
                ? "OpenStreetMap is temporarily unavailable. Try again shortly."
                : "OpenStreetMap servers failed: \(details)"
        case .courseNotFound(let course):
            return "No OpenStreetMap course area was found for \(course). Try a different course or retry later."
        }
    }
}

private struct OverpassAttempt: Sendable {
    var elements: [OverpassElement]?
    var failure: String?
}

struct OverpassClient {
    private static let endpoints = [
        URL(string: "https://overpass-api.de/api/interpreter")!,
        URL(string: "https://overpass.private.coffee/api/interpreter")!,
    ]

    var session: URLSession = .shared

    func findCourseRelationID(for reference: CourseReference) async throws -> Int {
        let clubTokens = matchTokens(reference.clubName)
        let courseTokens = matchTokens(reference.courseName)
        let generic: Set<String> = ["golf", "club", "country", "sports", "course", "slinga", "the", "and"]
        let queryTokens = Array(clubTokens.union(courseTokens).subtracting(generic)).sorted()
        guard !queryTokens.isEmpty else { throw OverpassError.courseNotFound(reference.courseName) }
        let expression = queryTokens.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        let query = """
        [out:json][timeout:8];relation["leisure"="golf_course"]["name"~"\(expression)",i](55,10,70,25);out center tags;
        """
        let elements = try await perform(query: query, timeout: 12)
        let candidates = elements.compactMap { element -> (id: Int, score: Int)? in
            guard element.type == "relation",
                  let name = element.tags?["name"],
                  let center = element.center,
                  (55.0...70.0).contains(center.lat),
                  (10.0...25.0).contains(center.lon) else { return nil }
            let nameTokens = matchTokens(name)
            let courseMatches = nameTokens.intersection(courseTokens).count
            let clubMatches = nameTokens.intersection(clubTokens).count
            guard courseMatches + clubMatches > 0 else { return nil }
            return (element.id, clubMatches * 3 + courseMatches * 2)
        }
        guard let match = candidates.max(by: { $0.score < $1.score }) else {
            throw OverpassError.courseNotFound(reference.courseName)
        }
        return match.id
    }

    func fetchGolfFeatures(courseRelationID: Int) async throws -> [OverpassElement] {
        // Overpass area IDs for relations are offset by 3.6 billion.
        let areaID = 3_600_000_000 + courseRelationID
        let query = """
        [out:json][timeout:15];area(id:\(areaID))->.c;(way["golf"="hole"](area.c);way["golf"="green"](area.c);way["golf"="fairway"](area.c);way["golf"="rough"](area.c);way["golf"="tee"](area.c);node["golf"="pin"](area.c););out geom;
        """
        return try await perform(query: query, timeout: 19)
    }

    private func perform(query: String, timeout: TimeInterval) async throws -> [OverpassElement] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        return try await withThrowingTaskGroup(of: OverpassAttempt.self) { group in
            for endpoint in Self.endpoints {
                group.addTask { @MainActor in
                    do {
                        var request = URLRequest(url: endpoint)
                        request.httpMethod = "POST"
                        request.timeoutInterval = timeout
                        request.setValue("FairwayVectorMap/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
                        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                        request.httpBody = Data("data=\(encoded)".utf8)

                        let (data, response) = try await session.data(for: request)
                        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                            return OverpassAttempt(elements: nil, failure: "\(endpoint.host ?? "Overpass"): HTTP \(http.statusCode)")
                        }
                        return OverpassAttempt(elements: try Self.decode(data), failure: nil)
                    } catch {
                        return OverpassAttempt(elements: nil, failure: "\(endpoint.host ?? "Overpass"): \(error.localizedDescription)")
                    }
                }
            }

            var failures: [String] = []
            while let attempt = try await group.next() {
                if let elements = attempt.elements {
                    group.cancelAll()
                    return elements
                }
                if let failure = attempt.failure {
                    failures.append(failure)
                }
            }
            throw OverpassError.allServersFailed(failures)
        }
    }

    private func matchTokens(_ value: String) -> Set<String> {
        Set(value.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init).filter {
            $0.count >= 2 || $0.contains(where: \.isNumber)
        })
    }

    static func decode(_ data: Data) throws -> [OverpassElement] {
        try JSONDecoder().decode(OverpassResponse.self, from: data).elements
    }
}
