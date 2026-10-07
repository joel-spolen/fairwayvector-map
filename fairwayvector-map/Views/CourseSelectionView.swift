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
                    CourseSearchControls(model: model, refreshTitle: isMock ? "Refresh saved / demo search (local)" : "Refresh search from Golf API")

                    if let recentCourse {
                        recentCourseShortcut(recentCourse)
                    }

                    CourseSelectionStatus(model: model)

                    if !model.clubs.isEmpty {
                        CourseClubCards(clubs: model.clubs, selectedClubID: model.selectedClubID,
                                        title: "CLUBS · \(model.clubs.count)", onSelect: model.selectClub)
                    }

                    if let club = model.selectedClub {
                        CourseResultCards(model: model, club: club, isMock: isMock)
                    }

                    if model.isLoadingCourse {
                        CourseSelectionLoading()
                    }

                    if let detail = model.courseDetail {
                        CourseTeeSelectionCard(model: model, detail: detail)
                    }

                    if let selection = model.selection {
                        CourseSelectionSummaryCard(selection: selection)
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
                CourseRecentCard(reference: reference, status:
                    isMock && !DevelopmentAPIConfiguration.isDemoCourse(reference.golfAPICourseID ?? "")
                    ? (model.hasSavedCourse(reference) ? pausedLabel(for: reference.golfAPICourseID)
                       : "Downloaded data unavailable in this installation · selection preserved") : nil)
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
}
