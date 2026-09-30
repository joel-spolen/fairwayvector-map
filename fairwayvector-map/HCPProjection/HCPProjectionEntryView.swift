import SwiftData
import SwiftUI

struct HCPProjectionEntryView: View {
    private let courseCatalog = CourseCatalogStore()

    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PlayerProfile.self,
            GolfClub.self,
            GolfCourse.self,
            TeeSet.self,
            GolfRound.self,
        ])
        let configuration = ModelConfiguration("hcpProjection", schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            if let url = configuration.url as URL? {
                try? FileManager.default.removeItem(at: url)
                try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("sqlite-shm"))
                try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("sqlite-wal"))
            }
            guard let recovered = try? ModelContainer(for: schema, configurations: [configuration]) else {
                fatalError("Could not create HCP Projection ModelContainer: \(error)")
            }
            return recovered
        }
    }()

    var body: some View {
        HCPProjectionRootView(courseCatalog: courseCatalog)
    }
}

#Preview {
    HCPProjectionEntryView()
        .modelContainer(HCPProjectionEntryView.sharedModelContainer)
}
