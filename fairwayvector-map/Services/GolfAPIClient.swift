import Foundation

struct GolfAPICoursePayload {
    let detail: GolfAPICourseDetail
    let coordinates: [GolfAPICoordinate]
}

struct GolfAPIClient {
    static let baseURL = URL(string: "https://golfapi.io/api/v2.3")!

    private let session: URLSession
    private let cache: GolfAPICache
    private let apiKey: String
    let mode: DevelopmentAPIConfiguration.Mode

    init(
        session: URLSession = .shared,
        cache: GolfAPICache = GolfAPICache(),
        apiKey: String? = nil,
        mode: DevelopmentAPIConfiguration.Mode = DevelopmentAPIConfiguration.current.golfAPI
    ) {
        self.session = session
        self.cache = cache
        self.mode = mode
        self.apiKey = mode == .mock ? "" : (apiKey ?? (Bundle.main.object(forInfoDictionaryKey: "GOLF_API_KEY") as? String ?? ""))
    }

    var isConfigured: Bool {
        mode == .mock || (!apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !apiKey.contains("$(") && !apiKey.contains("${"))
    }

    func searchClubs(
        named query: String = "",
        country: String,
        region: String = "",
        forceRefresh: Bool = false
    ) async throws -> [GolfAPIClub] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCountry = country.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRegion = region.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty || !normalizedCountry.isEmpty || !normalizedRegion.isEmpty else { return [] }
        if mode == .live, !forceRefresh, let cached = cache.readSearch(query: normalizedQuery, country: normalizedCountry, region: normalizedRegion) {
            return try Self.decodeClubs(from: cached)
        }

        var queryItems = [URLQueryItem(name: "page", value: "1")]
        if !normalizedCountry.isEmpty { queryItems.append(URLQueryItem(name: "country", value: normalizedCountry)) }
        if !normalizedRegion.isEmpty { queryItems.append(URLQueryItem(name: "state", value: normalizedRegion)) }
        if !normalizedQuery.isEmpty { queryItems.append(URLQueryItem(name: "name", value: normalizedQuery)) }
        let data = try await get("/clubs", queryItems: queryItems)
        _ = try Self.decodeClubs(from: data)
        if mode == .live { cache.writeSearch(data, query: normalizedQuery, country: normalizedCountry, region: normalizedRegion) }
        return try Self.decodeClubs(from: data)
    }

    func loadCourseDetail(id: String, forceRefresh: Bool = false) async throws -> GolfAPICourseDetail {
        if mode == .live, !forceRefresh, let cached = cache.readCourseDetail(id: id) {
            return try Self.decodeDetail(from: cached)
        }
        let data = try await get("/courses/\(id)")
        let detail = try Self.decodeDetail(from: data)
        guard detail.courseID == id else {
            throw GolfAPIError.invalidResponse("The returned course ID does not match the requested course.")
        }
        if mode == .live { cache.writeCourseDetail(data, id: id) }
        return detail
    }

    func loadCoordinates(id: String, forceRefresh: Bool = false) async throws -> [GolfAPICoordinate] {
        if mode == .live, !forceRefresh, let cached = cache.readCoordinates(id: id) {
            return try Self.decodeCoordinates(from: cached, expectedCourseID: id)
        }
        let data = try await get("/coordinates/\(id)")
        let coordinates = try Self.decodeCoordinates(from: data, expectedCourseID: id)
        if mode == .live { cache.writeCoordinates(data, id: id) }
        return coordinates
    }

    func loadCourse(id: String) async throws -> GolfAPICoursePayload {
        async let detail = loadCourseDetail(id: id)
        async let coordinates = loadCoordinates(id: id)
        return try await GolfAPICoursePayload(detail: detail, coordinates: coordinates)
    }

    func refreshCourse(id: String) async throws -> GolfAPICoursePayload {
        let currentDetail = try await loadCourseDetail(id: id)
        if try await checkForUpdates(to: currentDetail) {
            async let detail = loadCourseDetail(id: id, forceRefresh: true)
            async let coordinates = loadCoordinates(id: id, forceRefresh: true)
            return try await GolfAPICoursePayload(detail: detail, coordinates: coordinates)
        }
        return try await loadCourse(id: id)
    }

    func checkForUpdates(to detail: GolfAPICourseDetail) async throws -> Bool {
        guard mode == .live else { return false }
        guard let timestamp = detail.timestampUpdated, !timestamp.isEmpty else { return false }
        let data = try await get("/courses", queryItems: [
            URLQueryItem(name: "country", value: "Sweden"),
            URLQueryItem(name: "name", value: detail.clubName),
            URLQueryItem(name: "timestampUpdated", value: timestamp),
            URLQueryItem(name: "page", value: "1")
        ])
        let object = try Self.jsonObject(data)
        let courses = object["courses"] as? [[String: Any]] ?? []
        return courses.contains { Self.string($0["courseID"]) == detail.courseID }
    }

    private func get(_ path: String, queryItems: [URLQueryItem] = []) async throws -> Data {
        // Hard gate at the only transport boundary, BEFORE keys, URLRequest or URLSession.
        if mode == .mock { return try DevelopmentGolfAPIFixtures.response(path: path, queryItems: queryItems) }
        guard !DevelopmentAPIConfiguration.isDemoCourse(path) else {
            throw GolfAPIError.invalidResponse("Demo IDs cannot be sent to the live provider. Select a real course after rebuilding in live mode.")
        }
        guard isConfigured else { throw GolfAPIError.missingAPIKey }
        var components = URLComponents(url: Self.baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        if !queryItems.isEmpty { components.queryItems = queryItems }
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.timeoutInterval = 25
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GolfAPIError.invalidResponse("The server did not return an HTTP response.")
        }
        guard http.statusCode != 401 && http.statusCode != 403 else { throw GolfAPIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else { throw GolfAPIError.httpStatus(http.statusCode) }
        return data
    }

    private static func decodeClubs(from data: Data) throws -> [GolfAPIClub] {
        let object = try jsonObject(data)
        guard let values = object["clubs"] as? [[String: Any]] else {
            throw GolfAPIError.invalidResponse("The clubs list is missing.")
        }
        return values.compactMap { value in
            guard let id = string(value["clubID"]),
                  let name = string(value["clubName"]) else { return nil }
            let courses = (value["courses"] as? [[String: Any]] ?? []).compactMap { course -> GolfAPICourseSummary? in
                guard let courseID = string(course["courseID"]),
                      let courseName = string(course["courseName"]) else { return nil }
                return GolfAPICourseSummary(
                    courseID: courseID,
                    courseName: courseName,
                    numHoles: int(course["numHoles"]) ?? 0,
                    hasGPS: bool(course["hasGPS"]) ?? false,
                    timestampUpdated: string(course["timestampUpdated"])
                )
            }
            return GolfAPIClub(
                clubID: id,
                clubName: name,
                city: string(value["city"]),
                state: string(value["state"]),
                country: string(value["country"]) ?? "",
                courses: courses
            )
        }
    }

    private static func decodeDetail(from data: Data) throws -> GolfAPICourseDetail {
        try GolfAPICourseDetail(json: jsonObject(data))
    }

    private static func decodeCoordinates(from data: Data, expectedCourseID: String) throws -> [GolfAPICoordinate] {
        let object = try jsonObject(data)
        guard string(object["courseID"]) == expectedCourseID else {
            throw GolfAPIError.invalidResponse("The returned coordinate course ID does not match the selected course.")
        }
        guard let values = object["coordinates"] as? [[String: Any]] else {
            throw GolfAPIError.invalidResponse("The course coordinates are missing.")
        }
        var coordinates: [GolfAPICoordinate] = []
        for value in values {
            if let coordinate = GolfAPICoordinate(json: value) {
                coordinates.append(coordinate)
            }
        }
        guard !coordinates.isEmpty else {
            throw GolfAPIError.noGPSData(string(object["courseID"]) ?? "Selected course")
        }
        return coordinates
    }

    private static func jsonObject(_ data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GolfAPIError.invalidResponse("Expected a JSON object.")
        }
        return object
    }

    private static func string(_ value: Any?) -> String? {
        guard let value, !(value is NSNull) else { return nil }
        if let string = value as? String { return string.isEmpty ? nil : string }
        return String(describing: value)
    }

    private static func int(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        guard let string = value as? String else { return nil }
        return Int(string)
    }

    private static func bool(_ value: Any?) -> Bool? {
        if let number = value as? NSNumber { return number.intValue != 0 }
        guard let string = value as? String else { return nil }
        return string == "1" || string.lowercased() == "true"
    }
}

struct GolfAPICache {
    private let rootURL: URL?

    init(directoryURL: URL? = nil, fileManager: FileManager = .default) {
        rootURL = directoryURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appending(path: "GolfAPI", directoryHint: .isDirectory)
    }

    func readSearch(query: String, country: String, region: String) -> Data? {
        read(named: "search-\(safeKey(country))-\(safeKey(region))-\(safeKey(query)).json")
    }
    func writeSearch(_ data: Data, query: String, country: String, region: String) {
        write(data, named: "search-\(safeKey(country))-\(safeKey(region))-\(safeKey(query)).json")
    }
    func readCourseDetail(id: String) -> Data? { read(named: "course-\(safeKey(id))-detail.json") }
    func writeCourseDetail(_ data: Data, id: String) { write(data, named: "course-\(safeKey(id))-detail.json") }
    func readCoordinates(id: String) -> Data? { read(named: "course-\(safeKey(id))-coordinates.json") }
    func writeCoordinates(_ data: Data, id: String) { write(data, named: "course-\(safeKey(id))-coordinates.json") }

    private func read(named name: String) -> Data? {
        guard let rootURL else { return nil }
        return try? Data(contentsOf: rootURL.appending(path: name))
    }

    private func write(_ data: Data, named name: String) {
        guard let rootURL else { return }
        try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try? data.write(to: rootURL.appending(path: name), options: .atomic)
    }

    private func safeKey(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return value.lowercased().unicodeScalars.map { allowed.contains($0) ? String($0) : "-" }.joined()
    }
}
