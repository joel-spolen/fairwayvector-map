import SwiftUI

struct CourseSelectionView: View {
    let onStartCourse: (CourseReference) -> Void
    let onStartRound: ((CourseReference) -> Void)?
    let onResumeRound: ((PlayedRound) -> Void)?
    @Environment(PlayedRoundStore.self) private var roundStore
    @State private var confirmDiscardRound = false

    init(onStartRound: ((CourseReference) -> Void)? = nil,
         onResumeRound: ((PlayedRound) -> Void)? = nil,
         onStartCourse: @escaping (CourseReference) -> Void) {
        self.onStartRound = onStartRound
        self.onResumeRound = onResumeRound
        self.onStartCourse = onStartCourse
    }

    @State private var model = GolfAPICourseSelectionModel()
    @AppStorage("map.recentCourseReference") private var recentCourseData = Data()
    @AppStorage("map.development.recentCourseReference.v1") private var demoRecentCourseData = Data()
    private var isMock: Bool { DevelopmentAPIConfiguration.current.golfAPI == .mock }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Where to?")
                            .font(.largeTitle.weight(.semibold)).tracking(-1)
                        Text("Find your course. Choose your tee.")
                            .font(.subheadline).foregroundStyle(PureLineStyle.muted)
                    }
                    if let round = roundStore.active {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Round in progress", systemImage: "flag.checkered").font(.headline)
                            Text("\(round.reference.courseName) · \(round.reference.teeName) · hole \(round.holes[round.currentHole].number)")
                            Button("Resume scorecard & map") { onResumeRound?(round) }
                                .buttonStyle(PureLinePrimaryButtonStyle())
                            Button("Discard unsaved round", role: .destructive) { confirmDiscardRound = true }
                        }
                        .pureLineCard()
                    }
                    if let message = roundStore.errorMessage {
                        Text(message).font(.footnote).foregroundStyle(PureLineStyle.ink)
                        if roundStore.draftNeedsRetry {
                            Button("Retry saving draft") {
                                do { try roundStore.retryDraft() } catch { roundStore.errorMessage = error.localizedDescription }
                            }
                        } else { Button("Retry loading round storage") { roundStore.load() } }
                    }
                    if isMock {
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("APIs paused · 0 paid requests")
                                Text("Saved real Hills is bundled for offline course access on fresh devices. Demo Hills is a separate invented fallback. Terrain remains explicitly synthetic; the private real terrain backup is not used by this app.")
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .font(.footnote).foregroundStyle(PureLineStyle.muted)
                            .padding(.top, 8)
                        } label: {
                            Label("Offline preview · synthetic terrain", systemImage: "externaldrive")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(PureLineStyle.accent)
                        }
                    }
                    searchField

                    if let recentCourse {
                        recentCourseShortcut(recentCourse)
                    }

                    if isMock, !model.savedCourses.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("SAVED COURSES")
                                .font(.caption.weight(.semibold))
                                .tracking(1.2)
                                .foregroundStyle(PureLineStyle.muted)
                            ForEach(model.savedCourses, id: \.cacheKey) { reference in
                                recentCourseShortcut(reference, title: pausedLabel(for: reference.golfAPICourseID))
                            }
                        }
                    }

                    if !model.isConfigured {
                        Label("Golf API key not configured. Add GOLF_API_KEY in the app target’s build settings.", systemImage: "key.horizontal")
                            .font(.footnote)
                            .foregroundStyle(PureLineStyle.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let errorMessage = model.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(PureLineStyle.muted)
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
                        .buttonStyle(PureLinePrimaryButtonStyle())
                        .tint(PureLineStyle.accent)
                        .accessibilityIdentifier("view-course-button")
                        if let onStartRound {
                            Button("Start round", systemImage: "flag.checkered") { onStartRound(selection.reference) }
                                .buttonStyle(PureLinePrimaryButtonStyle()).disabled(roundStore.active != nil)
                        }
                    }

                    DisclosureGroup("Course data & providers") {
                        Text(isMock ? "Saved Hills offline and other complete saved courses appear before demo results. Real Hills provider detail, coordinates and 62/Men geometry are bundled read-only; other rated tees use the original provider payload. Valley is not bundled. Refresh never contacts Golf API. Weather and imagery are still live/cache-backed."
                            : "Golf API search is low-cost. Opening a course downloads its detail and coordinate data once; both are cached on this device. Use the course refresh button to check for provider updates.")
                            .font(.footnote)
                            .foregroundStyle(PureLineStyle.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 8)
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(PureLineStyle.muted)
                    .pureLineCard()
                }
                .foregroundStyle(PureLineStyle.ink)
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(PureLineStyle.canvas)
            .navigationTitle("Choose Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(PureLineStyle.canvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(PureLineStyle.accent)
        .confirmationDialog("Discard the unsaved round?", isPresented: $confirmDiscardRound, titleVisibility: .visible) {
            Button("Discard round", role: .destructive) {
                do { try roundStore.discardDraft() } catch { roundStore.errorMessage = error.localizedDescription }
            }
        } message: { Text("All unsaved player scores will be removed. Saved Statistics and Handicap history remain.") }
    }

    private var recentCourse: CourseReference? {
        if isMock {
            let live = try? JSONDecoder().decode(CourseReference.self, from: recentCourseData)
            // A usable live recent takes precedence over any previous demo shortcut.
            if let live, model.hasSavedCourse(live) { return live }
            let paused = try? JSONDecoder().decode(CourseReference.self, from: demoRecentCourseData)
            if let paused, model.hasSavedCourse(paused) { return paused }
            return live ?? paused
        }
        let saved = try? JSONDecoder().decode(CourseReference.self, from: recentCourseData)
        return saved.flatMap { DevelopmentAPIConfiguration.isDemoCourse($0.golfAPICourseID ?? "") ? nil : $0 }
    }

    private func startCourse(_ reference: CourseReference) {
        if let data = try? JSONEncoder().encode(reference) {
            if isMock { demoRecentCourseData = data } else { recentCourseData = data }
        }
        onStartCourse(reference)
    }

    private func pausedLabel(for id: String?) -> String {
        id == BundledSavedCourseStore.hillsCourseID ? "Saved Hills offline · APIs paused" : "Saved course · APIs paused"
    }

    private func recentCourseShortcut(_ reference: CourseReference, title: String = "RECENTLY SELECTED") -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(PureLineStyle.muted)

            Button {
                startCourse(reference)
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                        .foregroundStyle(PureLineStyle.accent)
                        .frame(width: 40, height: 40)
                        .background(PureLineStyle.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(reference.courseName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PureLineStyle.ink)
                        if reference.clubName != reference.courseName {
                            Text(reference.clubName)
                                .font(.caption)
                                .foregroundStyle(PureLineStyle.muted)
                        }
                        Text("\(reference.teeName) tee · \(reference.teeSex == "female" ? "Women" : "Men") · \(reference.holeCount) holes")
                            .font(.caption)
                            .foregroundStyle(PureLineStyle.muted)
                        if isMock, !DevelopmentAPIConfiguration.isDemoCourse(reference.golfAPICourseID ?? "") {
                            Text(model.hasSavedCourse(reference) ? pausedLabel(for: reference.golfAPICourseID) : "Downloaded data unavailable in this installation · selection preserved")
                                .font(.caption).foregroundStyle(PureLineStyle.accent)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PureLineStyle.accent)
                }
                .pureLineCard()
                .contentShape(RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("recent-course-button")
            .accessibilityHint("Opens this course with your previously selected tee set")
            if let onStartRound {
                Button("Start round on this tee", systemImage: "flag.checkered") { onStartRound(reference) }
                    .buttonStyle(.bordered).disabled(roundStore.active != nil)
            }
        }
    }

    private var searchField: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("FIND A COURSE")
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(PureLineStyle.muted)
            HStack(spacing: 14) {
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

                Rectangle()
                    .fill(PureLineStyle.line)
                    .frame(width: 1, height: 24)
                    .accessibilityHidden(true)

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
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(PureLineStyle.surface, in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
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
                .buttonStyle(PureLinePrimaryButtonStyle(fillsWidth: false, minimumHeight: 44))
                .disabled(model.isSearching || model.selectedCountry.isEmpty)
                .accessibilityLabel("Search golf clubs")
            }
            .padding(.leading, 16)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .background(PureLineStyle.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(PureLineStyle.line, lineWidth: 1))

            Button(isMock ? "Refresh saved / demo search (local)" : "Refresh search from Golf API") {
                Task { await model.search(forceRefresh: true) }
            }
            .font(.caption.weight(.medium))
            .padding(.vertical, 4)
            .disabled(model.isSearching || model.selectedCountry.isEmpty)
        }
    }

    private var clubResults: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CLUBS · \(model.clubs.count)")
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(PureLineStyle.muted)

            ForEach(model.clubs) { club in
                Button {
                    model.selectClub(club)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(PureLineStyle.accent)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(club.clubName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PureLineStyle.ink)
                            Text([club.city, club.state].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(PureLineStyle.muted)
                        }
                        Spacer()
                        Text("\(club.courses.count) courses")
                            .font(.caption2)
                            .foregroundStyle(PureLineStyle.muted)
                        Image(systemName: model.selectedClubID == club.id ? "checkmark.circle.fill" : "chevron.right")
                            .foregroundStyle(PureLineStyle.accent)
                    }
                        .pureLineCard()
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(model.selectedClubID == club.id ? PureLineStyle.accent : Color.clear, lineWidth: 1))
                        .contentShape(RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func courseResults(for club: GolfAPIClub) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COURSES AT \(club.clubName.uppercased())")
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(PureLineStyle.muted)

            ForEach(club.courses) { course in
                Button {
                    Task { await model.selectCourse(course) }
                } label: {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(course.courseName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PureLineStyle.ink)
                            if isMock {
                                Text(DevelopmentAPIConfiguration.isDemoCourse(course.courseID)
                                     ? "DEMO · invented course" : pausedLabel(for: course.courseID))
                                    .font(.caption).foregroundStyle(PureLineStyle.accent)
                            }
                            Text("\(course.numHoles) holes · \(course.hasGPS ? "GPS available" : "No GPS data")")
                                .font(.caption)
                                .foregroundStyle(PureLineStyle.muted)
                        }
                        Spacer()
                        if model.isLoadingCourse && model.selectedCourseID == course.id {
                            ProgressView()
                        } else {
                            Image(systemName: model.selectedCourseID == course.id ? "checkmark.circle.fill" : "chevron.right")
                                .foregroundStyle(PureLineStyle.accent)
                        }
                    }
                    .pureLineCard()
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(model.selectedCourseID == course.id ? PureLineStyle.accent : Color.clear, lineWidth: 1))
                    .contentShape(RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
                .disabled(!course.hasGPS || model.isLoadingCourse)
            }
        }
    }

    private func teeSelection(detail: GolfAPICourseDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TEE SET")
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(PureLineStyle.muted)

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
            .padding(.vertical, 6)
            .background(PureLineStyle.surface, in: RoundedRectangle(cornerRadius: 12))

            Text("\(detail.numHoles) holes · \(detail.hasGPS ? "GPS data available" : "GPS data unavailable")")
                .font(.caption)
                .foregroundStyle(PureLineStyle.muted)
        }
            .pureLineCard()
    }

    private func selectionSummary(_ selection: GolfAPICourseSelection) -> some View {
        let coursePars = selection.sex == "female" ? selection.details.parsWomen : selection.details.parsMen
        let pars = selection.tee.pars(for: selection.sex, fallback: coursePars)
        return VStack(alignment: .leading, spacing: 12) {
            Text("SELECTED COURSE")
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(PureLineStyle.muted)
            Text("\(selection.club.clubName) · \(selection.details.courseName)")
                .font(.headline)
                .foregroundStyle(PureLineStyle.ink)
            Text("\(selection.tee.teeName) · \(selection.sex == "female" ? "Women" : "Men")")
                .font(.subheadline)
                .foregroundStyle(PureLineStyle.muted)
            Rectangle()
                .fill(PureLineStyle.line)
                .frame(height: 1)
                .accessibilityHidden(true)
            HStack(spacing: 18) {
                rating("COURSE RATING", selection.tee.rating(for: selection.sex).map { String(format: "%.1f", $0) } ?? "–")
                rating("SLOPE", selection.tee.slope(for: selection.sex).map(String.init) ?? "–")
                rating("PAR", pars.isEmpty ? "–" : "\(pars.reduce(0, +))")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pureLineCard()
    }

    private func rating(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(PureLineStyle.muted)
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(PureLineStyle.ink)
        }
    }
}
