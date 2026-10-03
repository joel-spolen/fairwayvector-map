import Foundation
import Observation

@Observable
final class CourseStore {
    let reference: CourseReference
    private(set) var course: Course?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let client: OverpassClient
    private let golfAPIClient: GolfAPIClient
    private let maxCacheAge: TimeInterval = 24 * 60 * 60
    private var resolvedRelationID: Int?

    init(
        reference: CourseReference,
        client: OverpassClient = OverpassClient(),
        golfAPIClient: GolfAPIClient = GolfAPIClient()
    ) {
        self.reference = reference
        self.client = client
        self.golfAPIClient = golfAPIClient
    }

    func load() async {
        if course == nil {
            course = readCache()
        }
        if reference.golfAPICourseID != nil, course != nil {
            return
        }
        if let course, Date.now.timeIntervalSince(course.fetchedAt) < maxCacheAge {
            return
        }
        await refresh()
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if let courseID = reference.golfAPICourseID {
                let payload = try await (course == nil
                    ? golfAPIClient.loadCourse(id: courseID)
                    : golfAPIClient.refreshCourse(id: courseID))
                let built = try GolfAPICourseBuilder.build(reference: reference, payload: payload)
                course = built
                writeCache(built)
                return
            }

            let relationID: Int
            if let cachedID = course?.osmRelationID {
                relationID = cachedID
            } else if let knownID = reference.osmRelationID {
                relationID = knownID
            } else if let resolvedRelationID {
                relationID = resolvedRelationID
            } else {
                relationID = try await client.findCourseRelationID(for: reference)
                resolvedRelationID = relationID
            }
            let elements = try await client.fetchGolfFeatures(courseRelationID: relationID)
            let built = try CourseBuilder.build(reference: reference, elements: elements, osmRelationID: relationID)
            course = built
            writeCache(built)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var cacheURL: URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let version = reference.golfAPICourseID == nil ? "v5" : "golfapi-v1"
        return dir.appending(path: "course-\(reference.cacheKey)-\(version).json")
    }

    private func readCache() -> Course? {
        guard let url = cacheURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Course.self, from: data)
    }

    private func writeCache(_ course: Course) {
        guard let url = cacheURL, let data = try? JSONEncoder().encode(course) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
