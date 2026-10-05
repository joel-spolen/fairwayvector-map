import SwiftUI

struct CourseSelectionView: View {
    let onStartCourse: (CourseReference) -> Void

    @State private var model = GolfAPICourseSelectionModel()
    @AppStorage("map.recentCourseReference") private var recentCourseData = Data()
    @AppStorage("map.development.recentCourseReference.v1") private var demoRecentCourseData = Data()
    private var isMock: Bool { DevelopmentAPIConfiguration.current.golfAPI == .mock }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if isMock {
                        Label("DEMO DATA · Golf API paused · 0 paid requests. Search Sweden / Hills. Only one invented 18-hole course is included; ratings and GPS layout are not real Hills data. A saved live course reopens as Demo Hills without changing its live reference or cache.", systemImage: "testtube.2")
                            .font(.footnote).foregroundStyle(FairwayVectorColors.orange)
                    }
                    searchField

                    if let recentCourse {
                        recentCourseShortcut(recentCourse)
                    }

                    if !model.isConfigured {
                        Label("Golf API key not configured. Add GOLF_API_KEY in the app target’s build settings.", systemImage: "key.horizontal")
                            .font(.footnote)
                            .foregroundStyle(FairwayVectorColors.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let errorMessage = model.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(FairwayVectorColors.orange)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("course-search-message")
                    }

                    if !model.clubs.isEmpty {
                        clubResults
                    }

                    if let club = model.selectedClub {
                        courseResults(for: club)
                    }

                    if model.isLoadingCourse {
                        ProgressView("Loading course and tee information…")
                            .frame(maxWidth: .infinity)
                    }

                    if let detail = model.courseDetail {
                        teeSelection(detail: detail)
                    }

                    if let selection = model.selection {
                        selectionSummary(selection)
                        Button {
                            startCourse(selection.reference)
                        } label: {
                            Label("View Course", systemImage: "map.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(FairwayVectorColors.navy)
                        .accessibilityIdentifier("view-course-button")
                    }

                    Text(isMock ? "Development fixtures run locally. Other country/club filters return no demo matches; this is not a worldwide dataset. Refresh never contacts Golf API."
                        : "Golf API search is low-cost. Opening a course downloads its detail and coordinate data once; both are cached on this device. Use the course refresh button to check for provider updates.")
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
        .tint(FairwayVectorColors.navy)
    }

    private var recentCourse: CourseReference? {
        if isMock {
            let saved = try? JSONDecoder().decode(CourseReference.self,
                from: demoRecentCourseData.isEmpty ? recentCourseData : demoRecentCourseData)
            return saved.map { DevelopmentGolfAPIFixtures.reference(teeID: $0.golfAPITeeID, sex: $0.teeSex) }
        }
        let saved = try? JSONDecoder().decode(CourseReference.self, from: recentCourseData)
        return saved.flatMap { DevelopmentAPIConfiguration.isDemoCourse($0.golfAPICourseID ?? "") ? nil : $0 }
    }

    private func startCourse(_ reference: CourseReference) {
        let effective = isMock ? DevelopmentGolfAPIFixtures.reference(teeID: reference.golfAPITeeID, sex: reference.teeSex) : reference
        if let data = try? JSONEncoder().encode(effective) {
            if isMock { demoRecentCourseData = data } else { recentCourseData = data }
        }
        onStartCourse(effective)
    }

    private func recentCourseShortcut(_ reference: CourseReference) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECENTLY SELECTED")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(FairwayVectorColors.slate)

            Button {
                startCourse(reference)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                        .foregroundStyle(FairwayVectorColors.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reference.courseName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(FairwayVectorColors.navy)
                        if reference.clubName != reference.courseName {
                            Text(reference.clubName)
                                .font(.caption)
                                .foregroundStyle(FairwayVectorColors.slate)
                        }
                        Text("\(reference.teeName) tee · \(reference.teeSex == "female" ? "Women" : "Men") · \(reference.holeCount) holes")
                            .font(.caption)
                            .foregroundStyle(FairwayVectorColors.slate)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FairwayVectorColors.navy)
                }
                .padding(14)
                .background(FairwayVectorColors.conditionsSurface, in: RoundedRectangle(cornerRadius: 12))
                .contentShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("recent-course-button")
            .accessibilityHint("Opens this course with your previously selected tee set")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            FairwayVectorMark()
                .frame(width: 62, height: 62)
            Text("Where are you playing?")
                .font(.title2.bold())
                .foregroundStyle(FairwayVectorColors.navy)
                    Text("Choose a coverage region and country, then optionally narrow results by club name.")
                .font(.subheadline)
                .foregroundStyle(FairwayVectorColors.slate)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var searchField: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Menu {
                    ForEach(model.coverageRegions) { region in
                        Button(region.name) { model.selectRegion(region.name) }
                    }
                } label: {
                    Label(model.selectedRegion.isEmpty ? "Region" : model.selectedRegion, systemImage: "globe")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                        .accessibilityLabel(model.selectedRegion.isEmpty ? "Region" : model.selectedRegion)
                        .accessibilityAddTraits(.isButton)
                }
                .accessibilityIdentifier("golf-coverage-region-picker")

                Menu {
                    ForEach(model.availableCountries, id: \.self) { country in
                        Button(country) { model.selectedCountry = country }
                    }
                } label: {
                    Label(model.selectedCountry.isEmpty ? "Country" : model.selectedCountry, systemImage: "mappin.and.ellipse")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                        .accessibilityLabel(model.selectedCountry.isEmpty ? "Country" : model.selectedCountry)
                        .accessibilityAddTraits(.isButton)
                }
                .disabled(model.selectedRegion.isEmpty)
                .accessibilityIdentifier("golf-country-picker")
            }
            .padding(.horizontal, 10)
            .background(.white, in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 8) {
                TextField("Search club name", text: $model.searchText)
                    .textContentType(.organizationName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { Task { await model.search() } }
                    .accessibilityIdentifier("golf-club-search-field")

                Button {
                    Task { await model.search() }
                } label: {
                    if model.isSearching {
                        ProgressView()
                            .frame(width: 48, height: 44)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .frame(width: 48, height: 44)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isSearching || model.selectedCountry.isEmpty)
                .accessibilityLabel("Search golf clubs")
            }
            .padding(.horizontal, 12)
            .background(.white, in: RoundedRectangle(cornerRadius: 12))

            Button(isMock ? "Refresh demo search (local)" : "Refresh search from Golf API") {
                Task { await model.search(forceRefresh: true) }
            }
            .font(.caption.weight(.medium))
            .disabled(model.isSearching || model.selectedCountry.isEmpty)
        }
    }

    private var clubResults: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CLUBS · \(model.clubs.count)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(FairwayVectorColors.slate)

            ForEach(model.clubs) { club in
                Button {
                    model.selectClub(club)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(FairwayVectorColors.orange)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(club.clubName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(FairwayVectorColors.navy)
                            Text([club.city, club.state].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(FairwayVectorColors.slate)
                        }
                        Spacer()
                        Text("\(club.courses.count) courses")
                            .font(.caption2)
                            .foregroundStyle(FairwayVectorColors.slate)
                        Image(systemName: model.selectedClubID == club.id ? "checkmark.circle.fill" : "chevron.right")
                            .foregroundStyle(FairwayVectorColors.navy)
                    }
                    .padding(12)
                    .background(model.selectedClubID == club.id ? FairwayVectorColors.conditionsSurface : FairwayVectorColors.surface, in: RoundedRectangle(cornerRadius: 12))
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func courseResults(for club: GolfAPIClub) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COURSES AT \(club.clubName.uppercased())")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(FairwayVectorColors.slate)

            ForEach(club.courses) { course in
                Button {
                    Task { await model.selectCourse(course) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(course.courseName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(FairwayVectorColors.navy)
                            Text("\(course.numHoles) holes · \(course.hasGPS ? "GPS available" : "No GPS data")")
                                .font(.caption)
                                .foregroundStyle(FairwayVectorColors.slate)
                        }
                        Spacer()
                        if model.isLoadingCourse && model.selectedCourseID == course.id {
                            ProgressView()
                        } else {
                            Image(systemName: model.selectedCourseID == course.id ? "checkmark.circle.fill" : "chevron.right")
                                .foregroundStyle(FairwayVectorColors.navy)
                        }
                    }
                    .padding(12)
                    .background(FairwayVectorColors.surface, in: RoundedRectangle(cornerRadius: 12))
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(!course.hasGPS || model.isLoadingCourse)
            }
        }
    }

    private func teeSelection(detail: GolfAPICourseDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TEE SET")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(FairwayVectorColors.slate)

            Picker("Rating category", selection: $model.selectedSex) {
                Text("Men").tag("male")
                Text("Women").tag("female")
            }
            .pickerStyle(.segmented)
            .onChange(of: model.selectedSex) { model.selectedTeeID = model.ratedTees.first?.teeID }

            Picker("Tee", selection: Binding(
                get: { model.selectedTeeID ?? "" },
                set: { model.selectedTeeID = $0.isEmpty ? nil : $0 }
            )) {
                Text("Select tee").tag("")
                ForEach(model.ratedTees) { tee in
                    Text("\(tee.teeName) · Slope \(tee.slope(for: model.selectedSex) ?? 0)").tag(tee.teeID)
                }
            }
            .pickerStyle(.navigationLink)
            .padding(.horizontal, 12)
            .background(.white, in: RoundedRectangle(cornerRadius: 12))

            Text("\(detail.numHoles) holes · \(detail.hasGPS ? "GPS data available" : "GPS data unavailable")")
                .font(.caption)
                .foregroundStyle(FairwayVectorColors.slate)
        }
        .padding()
        .background(FairwayVectorColors.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func selectionSummary(_ selection: GolfAPICourseSelection) -> some View {
        let coursePars = selection.sex == "female" ? selection.details.parsWomen : selection.details.parsMen
        let pars = selection.tee.pars(for: selection.sex, fallback: coursePars)
        return VStack(alignment: .leading, spacing: 8) {
            Text("SELECTED COURSE")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(FairwayVectorColors.slate)
            Text("\(selection.club.clubName) · \(selection.details.courseName)")
                .font(.headline)
                .foregroundStyle(FairwayVectorColors.navy)
            Text("\(selection.tee.teeName) · \(selection.sex == "female" ? "Women" : "Men")")
                .font(.subheadline)
                .foregroundStyle(FairwayVectorColors.slate)
            HStack(spacing: 18) {
                rating("COURSE RATING", selection.tee.rating(for: selection.sex).map { String(format: "%.1f", $0) } ?? "–")
                rating("SLOPE", selection.tee.slope(for: selection.sex).map(String.init) ?? "–")
                rating("PAR", pars.isEmpty ? "–" : "\(pars.reduce(0, +))")
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
}
