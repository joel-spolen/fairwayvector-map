import SwiftUI

struct CourseSelectionView: View {
    let onStartCourse: (SelectedCourse) -> Void

    @State private var catalogStore = SwedenCourseCatalogStore()
    @State private var selectedClubID = ""
    @State private var selectedCourseID = ""
    @State private var selectedTeeID = ""

    private var selectedClub: CatalogClub? {
        catalogStore.clubs.first { $0.id == selectedClubID }
    }

    private var availableCourses: [CatalogCourse] {
        selectedClub?.courses ?? []
    }

    private var selectedCourse: CatalogCourse? {
        availableCourses.first { $0.id == selectedCourseID }
    }

    private var availableTees: [CatalogTeeRating] {
        selectedCourse?.ratings ?? []
    }

    private var selectedTee: CatalogTeeRating? {
        availableTees.first { $0.id == selectedTeeID }
    }

    private var canStart: Bool {
        selectedClub != nil && selectedCourse != nil && selectedTee != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    selectors

                    if let selectedClub, let selectedCourse, let selectedTee {
                        selectionSummary(club: selectedClub, course: selectedCourse, tee: selectedTee)
                    }

                    Button {
                        guard let selectedClub, let selectedCourse, let selectedTee else { return }
                        onStartCourse(SelectedCourse(club: selectedClub, course: selectedCourse, tee: selectedTee))
                    } label: {
                        Label("View Course", systemImage: "map.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FairwayVectorColors.navy)
                    .disabled(!canStart)

                    Text("Course details and tee ratings come from the bundled Sweden catalog. Hole geometry is downloaded from OpenStreetMap when available.")
                        .font(.footnote)
                        .foregroundStyle(FairwayVectorColors.slate)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
            }
            .background(FairwayVectorColors.background)
            .navigationTitle("Choose Course")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            FairwayVectorMark()
                .frame(width: 62, height: 62)
            Text("Where are you playing?")
                .font(.title2.bold())
                .foregroundStyle(FairwayVectorColors.navy)
            Text("Choose a club, course, and tee to open its map and distances.")
                .font(.subheadline)
                .foregroundStyle(FairwayVectorColors.slate)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectors: some View {
        VStack(spacing: 0) {
            Picker("Club", selection: $selectedClubID) {
                Text("Select a club").tag("")
                ForEach(catalogStore.clubs) { club in
                    Text(clubLocationLabel(club)).tag(club.id)
                }
            }
            .onChange(of: selectedClubID) {
                selectedCourseID = ""
                selectedTeeID = ""
            }

            Divider().padding(.leading)

            Picker("Course", selection: $selectedCourseID) {
                Text("Select a course").tag("")
                ForEach(availableCourses) { course in
                    Text("\(course.name) · \(course.holes) holes").tag(course.id)
                }
            }
            .disabled(selectedClub == nil)
            .onChange(of: selectedCourseID) {
                selectedTeeID = ""
            }

            Divider().padding(.leading)

            Picker("Tee", selection: $selectedTeeID) {
                Text("Select a tee").tag("")
                ForEach(availableTees) { tee in
                    Text("\(tee.tee) · \(tee.playerCategory) · Slope \(tee.slopeRating)").tag(tee.id)
                }
            }
            .disabled(selectedCourse == nil)
        }
        .pickerStyle(.navigationLink)
        .padding(.horizontal, 12)
        .background(.white, in: RoundedRectangle(cornerRadius: 12))
    }

    private func selectionSummary(club: CatalogClub, course: CatalogCourse, tee: CatalogTeeRating) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SELECTED TEE")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(FairwayVectorColors.slate)
            Text("\(tee.tee) · \(tee.playerCategory)")
                .font(.headline)
                .foregroundStyle(FairwayVectorColors.navy)
            Text("\(club.name) · \(club.city ?? club.region ?? "Sweden") · \(course.name)")
                .font(.subheadline)
                .foregroundStyle(FairwayVectorColors.charcoal)
            HStack(spacing: 18) {
                rating("COURSE RATING", String(format: "%.1f", tee.courseRating))
                rating("SLOPE", "\(tee.slopeRating)")
                rating("PAR", "\(course.par)")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FairwayVectorColors.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func rating(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(FairwayVectorColors.slate)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(FairwayVectorColors.charcoal)
        }
    }

    private func clubLocationLabel(_ club: CatalogClub) -> String {
        let location = club.city ?? club.region
        guard let location, !location.isEmpty else { return club.name }
        return "\(club.name) · \(location)"
    }
}
