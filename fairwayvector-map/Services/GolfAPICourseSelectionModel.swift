import Foundation
import Observation

@MainActor
@Observable
final class GolfAPICourseSelectionModel {
    private let client: GolfAPIClient
    let savedCourses: [CourseReference]

    var selectedRegion = "Europe"
    var selectedCountry = "Sweden"
    var searchText = ""
    private(set) var clubs: [GolfAPIClub] = []
    private(set) var selectedClubID: String?
    private(set) var selectedCourseID: String?
    private(set) var courseDetail: GolfAPICourseDetail?
    var selectedSex = "male"
    var selectedTeeID: String?
    private(set) var isSearching = false
    private(set) var isLoadingCourse = false
    private(set) var errorMessage: String?
    private(set) var apiRequestsLeft: String?

    init(client: GolfAPIClient? = nil) {
        let resolved = client ?? GolfAPIClient()
        self.client = resolved
        savedCourses = resolved.mode == .mock ? resolved.savedReferences : []
    }

    var isConfigured: Bool { client.isConfigured }

    func hasSavedCourse(_ reference: CourseReference) -> Bool {
        if CourseDataStore.readCourse(reference: reference) != nil { return true }
        guard let id = reference.golfAPICourseID, let payload = client.cachedPayload(id: id) else { return false }
        return (try? GolfAPICourseBuilder.build(reference: reference, payload: payload)) != nil
    }

    var coverageRegions: [GolfAPICoverageRegion] { GolfAPICoverage.regions }

    var availableCountries: [String] {
        coverageRegions.first { $0.name == selectedRegion }?.countries ?? []
    }

    var selectedClub: GolfAPIClub? {
        clubs.first { $0.clubID == selectedClubID }
    }

    var selectedCourse: GolfAPICourseSummary? {
        selectedClub?.courses.first { $0.courseID == selectedCourseID }
    }

    var ratedTees: [GolfAPITee] {
        guard let courseDetail else { return [] }
        return courseDetail.tees.filter { $0.rating(for: selectedSex) != nil && $0.slope(for: selectedSex) != nil }
    }

    var selectedTee: GolfAPITee? {
        ratedTees.first { $0.teeID == selectedTeeID }
    }

    var selection: GolfAPICourseSelection? {
        guard let selectedClub, let selectedCourse, let courseDetail, let selectedTee else { return nil }
        return GolfAPICourseSelection(
            club: selectedClub,
            course: selectedCourse,
            details: courseDetail,
            tee: selectedTee,
            sex: selectedSex
        )
    }

    func search(forceRefresh: Bool = false) async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selectedCountry.isEmpty || !query.isEmpty else {
            errorMessage = "Select a region and country, or enter a club name to search."
            return
        }
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }
        do {
            clubs = try await client.searchClubs(named: query, country: selectedCountry, forceRefresh: forceRefresh)
            apiRequestsLeft = nil
            selectedClubID = nil
            selectedCourseID = nil
            courseDetail = nil
            selectedTeeID = nil
            if clubs.isEmpty {
                let terms = [selectedCountry, query].filter { !$0.isEmpty }.joined(separator: " · ")
                errorMessage = "No golf clubs matched \"\(terms)\"."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectClub(_ club: GolfAPIClub) {
        selectedClubID = club.clubID
        selectedCourseID = nil
        courseDetail = nil
        selectedTeeID = nil
        errorMessage = nil
    }

    func selectRegion(_ region: String) {
        selectedRegion = region
        selectedCountry = ""
        clubs = []
        selectedClubID = nil
        selectedCourseID = nil
        courseDetail = nil
        selectedTeeID = nil
        errorMessage = nil
    }

    func selectCourse(_ course: GolfAPICourseSummary) async {
        guard course.hasGPS else {
            errorMessage = "\(course.courseName) has no GPS data in Golf API."
            return
        }
        selectedCourseID = course.courseID
        courseDetail = nil
        selectedTeeID = nil
        isLoadingCourse = true
        errorMessage = nil
        defer { isLoadingCourse = false }
        do {
            let details = try await client.loadCourseDetail(id: course.courseID)
            courseDetail = details
            apiRequestsLeft = nil
            if ratedTees.isEmpty {
                errorMessage = "No rated tee sets were returned for this course."
            } else {
                selectedTeeID = ratedTees.first?.teeID
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
