import Foundation
import CryptoKit

/// Durable shared directory, keyed by provider course identity, NEVER by tee/name.
nonisolated enum CourseDataStore {
    static var root: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CourseData", isDirectory: true)
    }
    static func directory(courseID: String, root: URL = root) -> URL {
        let digest = SHA256.hash(data: Data(courseID.utf8)).map { String(format: "%02x", $0) }.joined()
        return root.appendingPathComponent(digest, isDirectory: true)
    }
}