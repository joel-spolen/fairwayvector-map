import SwiftData
import SwiftUI

/// Hosts the ported fairwayvector-hcp-projection app with its own SwiftData store.
struct HCPProjectionEntryView: View {
    private let courseCatalog = CourseCatalogStore()

    private var modelContainer: ModelContainer = {
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
            .modelContainer(modelContainer)
    }
}

#Preview {
    HCPProjectionEntryView()
}
