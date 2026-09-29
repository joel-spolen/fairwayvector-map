import Foundation
import Observation

@Observable
final class CourseStore {
    let reference: CourseReference
    private(set) var course: Course?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let client: OverpassClient
    private let maxCacheAge: TimeInterval = 24 * 60 * 60

    init(reference: CourseReference, client: OverpassClient = OverpassClient()) {
        self.reference = reference
        self.client = client
    }

    func load() async {
        if course == nil {
            course = readCache()
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
            let elements = try await client.fetchGolfFeatures(courseRelationID: reference.osmRelationID)
            let built = try CourseBuilder.build(reference: reference, elements: elements)
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
        return dir.appending(path: "course-\(reference.osmRelationID)-v4.json")
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
