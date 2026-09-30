//
//  ContentView.swift
//  fairwayvector-hcp-projection
//

import Charts
import SwiftData
import SwiftUI

struct HCPProjectionRootView: View {
    private enum Tab {
        case home
        case predict
        case round
    }

    let courseCatalog: CourseCatalogStore

    @Environment(\.modelContext) private var modelContext
    @AppStorage("hcp.hasSeenSplash") private var hasSeenSplash = false
    @Query(filter: #Predicate<GolfClub> { $0.isCustom == true }, sort: \GolfClub.name) private var clubs: [GolfClub]
    @Query(filter: #Predicate<GolfCourse> { $0.isCustom == true }, sort: \GolfCourse.name) private var courses: [GolfCourse]
    @Query(filter: #Predicate<TeeSet> { $0.isCustom == true }, sort: \TeeSet.name) private var tees: [TeeSet]
    @Query(sort: \GolfRound.date, order: .reverse) private var rounds: [GolfRound]
    @Query private var profiles: [PlayerProfile]
    @State private var showingSplash = true
    @State private var selectedTab = Tab.home

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                HomeView(
                    courseCatalog: courseCatalog,
                    rounds: rounds,
                    profile: profiles.first,
                    clubs: clubs,
                    courses: courses,
                    tees: tees,
                    onAddRound: { selectedTab = .round }
                )
                    .tabItem { Label("Home", systemImage: "house") }
                    .tag(Tab.home)

                TargetCalculatorView(courseCatalog: courseCatalog, clubs: clubs, courses: courses, tees: tees, rounds: rounds, profile: profiles.first)
                    .tabItem { Label("Predict HCP", systemImage: "flag.checkered") }
                    .tag(Tab.predict)

                NewRoundView(courseCatalog: courseCatalog, clubs: clubs, courses: courses, tees: tees, rounds: rounds, profile: profiles.first)
                    .tabItem { Label("Add Round", systemImage: "plus.circle") }
                    .tag(Tab.round)
            }
            .tint(FairwayVectorColors.navy)

            if showingSplash {
                SplashView(isReturningUser: hasSeenSplash) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingSplash = false
                        hasSeenSplash = true
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .onAppear {
            SeedData.loadIfNeeded(modelContext: modelContext)
        }
    }
}

#Preview {
    HCPProjectionRootView(courseCatalog: CourseCatalogStore())
        .modelContainer(for: [PlayerProfile.self, GolfClub.self, GolfCourse.self, TeeSet.self, GolfRound.self], inMemory: true)
}

private struct HomeView: View {
    let courseCatalog: CourseCatalogStore
    var rounds: [GolfRound]
    var profile: PlayerProfile?
    var clubs: [GolfClub]
    var courses: [GolfCourse]
    var tees: [TeeSet]
    let onAddRound: () -> Void

    @State private var showSettings = false

    private var entries: [ScoringRecordEntry] {
        WHSCalculator.scoringEntries(from: rounds, lowHandicapIndex: profile?.lowHandicapIndex)
    }

    private var handicapIndex: Double? {
        WHSCalculator.handicapIndex(from: entries, lowHandicapIndex: profile?.lowHandicapIndex)
    }

    private var handicapRounds: [GolfRound] {
        Array(rounds.sorted { $0.date > $1.date }.prefix(20))
    }

    private var trendPoints: [HCPTrendPoint] {
        WHSCalculator.handicapProgression(from: rounds, lowHandicapIndex: profile?.lowHandicapIndex)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Plan the score or stableford points that move your handicap.")
                        .font(.title3)
                        .foregroundStyle(FairwayVectorColors.slate)

                    HCPTrendGraphCard(
                        trendPoints: trendPoints,
                        currentHandicap: handicapIndex
                    )

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            metricLinks
                        }
                        VStack(spacing: 12) {
                            metricLinks
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recent rounds")
                            .font(.headline)
                        if rounds.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                Text("No Rounds Yet")
                                    .font(.headline)
                                Text("Add a round to start tracking your Handicap Index.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                Button(action: onAddRound) {
                                    Label("Add Round", systemImage: "plus.circle")
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 52)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(FairwayVectorColors.navy)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        } else {
                            ForEach(rounds.prefix(5)) { round in
                                NavigationLink(destination: RoundDetailView(round: round, handicapIndex: handicapIndex)) {
                                    RoundRow(round: round)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                    .background(FairwayVectorColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .background(FairwayVectorColors.background)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings) {
                HCPSettingsView(courseCatalog: courseCatalog, profile: profile, clubs: clubs, courses: courses, tees: tees)
            }
        }
    }

    private var handicapIndexText: String {
        handicapIndex.map { WHSCalculator.formatHCPScore($0) } ?? "N/A"
    }

    @ViewBuilder
    private var metricLinks: some View {
        NavigationLink(destination: HandicapRoundsView(rounds: handicapRounds, handicapIndex: handicapIndex)) {
            MetricCard(title: "Handicap Index", value: handicapIndexText, systemImage: "number")
        }
        .buttonStyle(.plain)

        NavigationLink(destination: AllRoundsView(rounds: rounds, profile: profile)) {
            MetricCard(title: "Rounds", value: "\(entries.count)", systemImage: "calendar.badge.clock")
        }
        .buttonStyle(.plain)
    }
}

private struct HCPTrendGraphCard: View {
    var trendPoints: [HCPTrendPoint]
    var currentHandicap: Double?

    private var trendDifference: Double? {
        guard trendPoints.count >= 2,
              let first = trendPoints.first?.handicapIndex,
              let last = trendPoints.last?.handicapIndex else { return nil }
        return WHSCalculator.roundToTenth(last - first)
    }

    private var yDomain: ClosedRange<Double> {
        let values = trendPoints.map(\.handicapIndex)
        guard let minVal = values.min(), let maxVal = values.max() else { return 0...20 }
        if minVal == maxVal {
            return max(0, minVal - 2)...(maxVal + 2)
        }
        let padding = max(0.5, (maxVal - minVal) * 0.15)
        return max(0, minVal - padding)...(maxVal + padding)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Handicap Trend")
                        .font(.headline)
                    if let currentHandicap {
                        Text("Current: \(WHSCalculator.formatHCPScore(currentHandicap))")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let diff = trendDifference {
                    HStack(spacing: 4) {
                        Image(systemName: diff < 0 ? "arrow.down.right.circle.fill" : (diff > 0 ? "arrow.up.right.circle.fill" : "equal.circle.fill"))
                        Text(trendText(diff: diff))
                            .font(.caption.bold().monospacedDigit())
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(diff < 0 ? FairwayVectorColors.navy.opacity(0.12) : (diff > 0 ? FairwayVectorColors.orange.opacity(0.18) : FairwayVectorColors.slate.opacity(0.15)))
                    .foregroundStyle(diff < 0 ? FairwayVectorColors.navy : (diff > 0 ? FairwayVectorColors.orange : FairwayVectorColors.slate))
                    .clipShape(Capsule())
                }
            }

            if trendPoints.count >= 2 {
                Chart {
                    ForEach(trendPoints) { point in
                        AreaMark(
                            x: .value("Round", point.roundIndex),
                            y: .value("HCP", point.handicapIndex)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [FairwayVectorColors.orange.opacity(0.28), FairwayVectorColors.orange.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("Round", point.roundIndex),
                            y: .value("HCP", point.handicapIndex)
                        )
                        .foregroundStyle(FairwayVectorColors.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)

                        if point.id == trendPoints.last?.id {
                            PointMark(
                                x: .value("Round", point.roundIndex),
                                y: .value("HCP", point.handicapIndex)
                            )
                            .foregroundStyle(FairwayVectorColors.orange)
                            .symbolSize(45)
                        }
                    }
                }
                .chartYScale(domain: yDomain)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: min(trendPoints.count, 5))) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                            .foregroundStyle(FairwayVectorColors.slate.opacity(0.2))
                        AxisTick()
                            .foregroundStyle(FairwayVectorColors.slate.opacity(0.4))
                        AxisValueLabel {
                            if let rIndex = value.as(Int.self) {
                                Text("R\(rIndex)")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                            .foregroundStyle(FairwayVectorColors.slate.opacity(0.2))
                        AxisValueLabel {
                            if let hcp = value.as(Double.self) {
                                Text(WHSCalculator.formatHCPScore(hcp))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(height: 140)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Handicap trend chart")
                .accessibilityValue(trendAccessibilityValue)

                HStack {
                    if let first = trendPoints.first {
                        Text("Start: \(WHSCalculator.formatHCPScore(first.handicapIndex))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let lowest = trendPoints.map(\.handicapIndex).min() {
                        Text("Low: \(WHSCalculator.formatHCPScore(lowest))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let last = trendPoints.last {
                        Text("Latest: \(WHSCalculator.formatHCPScore(last.handicapIndex))")
                            .font(.caption2.bold().monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.top, 2)
            } else {
                Text("Add at least four rounds to view your Handicap Index trend.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .padding()
        .background(FairwayVectorColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func trendText(diff: Double) -> String {
        if diff < 0 {
            return "Improved by \(abs(diff).formatted(.number.precision(.fractionLength(1))))"
        } else if diff > 0 {
            return "Increased by \(diff.formatted(.number.precision(.fractionLength(1))))"
        } else {
            return "No change"
        }
    }

    private var trendAccessibilityValue: String {
        let latest = trendPoints.last.map { WHSCalculator.formatHCPScore($0.handicapIndex) } ?? "unavailable"
        let lowest = trendPoints.map(\.handicapIndex).min().map { WHSCalculator.formatHCPScore($0) } ?? "unavailable"
        let change = trendDifference.map { trendText(diff: $0) } ?? "no trend yet"
        return "Latest handicap \(latest), lowest \(lowest), \(change), across \(trendPoints.count) rounds"
    }
}

private struct HandicapRoundsView: View {
    var rounds: [GolfRound]
    var handicapIndex: Double?

    private var roundResults: [(round: GolfRound, differential: Double)] {
        let sortedRounds = rounds.sorted { $0.date > $1.date }
        var eligible: [(round: GolfRound, differential: Double)] = []
        for round in sortedRounds {
            guard let entry = WHSCalculator.scoringEntry(
                for: round,
                currentHandicapIndex: handicapIndex
            ) else { continue }
            eligible.append((round: round, differential: entry.scoreDifferential))
        }

        guard eligible.count >= 3 else { return [] }
        let rule = WHSCalculator.bestDifferentialRule(for: min(eligible.count, 20))
        let byDifferential = eligible.sorted { left, right in
            left.differential < right.differential
        }
        let counting: [(round: GolfRound, differential: Double)] = Array(byDifferential.prefix(rule.count))
        return counting.sorted { left, right in
            left.round.date > right.round.date
        }
    }

    private var scoreCount: Int {
        rounds.compactMap { WHSCalculator.scoringEntry(for: $0, currentHandicapIndex: handicapIndex) }.count
    }

    private var countingRuleSummary: String {
        guard scoreCount >= 3 else {
            return "At least three scores are required to calculate a Handicap Index."
        }
        let rule = WHSCalculator.bestDifferentialRule(for: min(scoreCount, 20))
        let adjustment = rule.adjustment == 0 ? "" : " with a \(Int(rule.adjustment)) adjustment"
        return "With \(scoreCount) scores, your lowest \(rule.count) \(rule.count == 1 ? "score counts" : "scores count")\(adjustment)."
    }

    var body: some View {
        List {
            if let handicapIndex {
                Section("Handicap Index") {
                    Text(WHSCalculator.formatHCPScore(handicapIndex))
                        .monospacedDigit()
                }
                .listRowBackground(FairwayVectorColors.surface)
            }

            if roundResults.isEmpty {
                Section("Counting Rounds") {
                    Text("No rounds count yet.")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(FairwayVectorColors.surface)
            } else {
                Section("Counting Rounds") {
                    ForEach(roundResults, id: \.round.id) { item in
                        NavigationLink(destination: RoundDetailView(round: item.round, handicapIndex: handicapIndex)) {
                            HandicapRoundRow(round: item.round, differential: item.differential)
                        }
                    }
                }
                .listRowBackground(FairwayVectorColors.surface)
            }

            Section("How Counting Rounds Work") {
                Text(countingRuleSummary)
                    .font(.subheadline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("3 scores: lowest 1, minus 2.0")
                    Text("4 scores: lowest 1, minus 1.0")
                    Text("5 scores: lowest 1")
                    Text("6 scores: lowest 2, minus 1.0")
                    Text("7–8 scores: lowest 2")
                    Text("9–11 scores: lowest 3")
                    Text("12–14 scores: lowest 4")
                    Text("15–16 scores: lowest 5")
                    Text("17–18 scores: lowest 6")
                    Text("19 scores: lowest 7")
                    Text("20 scores: lowest 8")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .listRowBackground(FairwayVectorColors.surface)
        }
        .scrollContentBackground(.hidden)
        .background(FairwayVectorColors.background)
        .navigationTitle("Handicap rounds")
    }
}

private struct HandicapRoundRow: View {
    var round: GolfRound
    var differential: Double

    private var scoreText: String {
        round.scoreSummaryText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(round.courseName.isEmpty ? "No Course" : round.courseName)
                        .font(.headline)
                    if !round.clubName.isEmpty || !round.teeName.isEmpty {
                        Text([round.clubName, round.teeName].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(WHSCalculator.formatHCPScore(differential))
                        .font(.headline.monospacedDigit())
                    Text(round.date, format: .dateTime.year().month().day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if round.handicapDifferential == nil {
                Text("HCP score: \(WHSCalculator.formatHCPScore(differential)) · \(scoreText)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AllRoundsView: View {
    @Environment(\.modelContext) private var modelContext
    var rounds: [GolfRound]
    var profile: PlayerProfile?

    private var sortedRounds: [GolfRound] {
        rounds.sorted { $0.date > $1.date }
    }

    private var recent20Rounds: [GolfRound] {
        Array(sortedRounds.prefix(20))
    }

    private var olderRounds: [GolfRound] {
        Array(sortedRounds.dropFirst(20))
    }

    private var countingRoundIDs: Set<PersistentIdentifier> {
        let entriesWithRound: [(round: GolfRound, entry: ScoringRecordEntry)] = recent20Rounds.compactMap { round in
            guard let entry = WHSCalculator.scoringEntry(for: round) else { return nil }
            return (round, entry)
        }

        guard entriesWithRound.count >= 3 else { return [] }

        let rule = WHSCalculator.bestDifferentialRule(for: entriesWithRound.count)
        let sortedByDiff = entriesWithRound.sorted { $0.entry.scoreDifferential < $1.entry.scoreDifferential }
        let counting = sortedByDiff.prefix(rule.count)
        return Set(counting.map(\.round.persistentModelID))
    }

    private var currentHandicapIndex: Double? {
        let entries = WHSCalculator.scoringEntries(from: rounds, lowHandicapIndex: profile?.lowHandicapIndex)
        return WHSCalculator.handicapIndex(from: entries, lowHandicapIndex: profile?.lowHandicapIndex)
    }

    var body: some View {
        List {
            if !recent20Rounds.isEmpty {
                Section {
                    ForEach(recent20Rounds) { round in
                        NavigationLink(destination: RoundDetailView(round: round, handicapIndex: currentHandicapIndex)) {
                            RoundRow(round: round, isCountingRound: countingRoundIDs.contains(round.persistentModelID))
                        }
                    }
                    .onDelete(perform: deleteRecentRounds)
                } header: {
                    Text("Last 20 rounds (WHS window)")
                }
                .listRowBackground(FairwayVectorColors.surface)
            }

            if !olderRounds.isEmpty {
                Section {
                    ForEach(olderRounds) { round in
                        NavigationLink(destination: RoundDetailView(round: round, handicapIndex: currentHandicapIndex)) {
                            RoundRow(round: round, isCountingRound: false)
                        }
                    }
                    .onDelete(perform: deleteOlderRounds)
                } header: {
                    Text("Older rounds (past 20-round window)")
                }
                .listRowBackground(FairwayVectorColors.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(FairwayVectorColors.background)
        .navigationTitle("All rounds")
    }

    private func deleteRecentRounds(at offsets: IndexSet) {
        for index in offsets {
            let round = recent20Rounds[index]
            modelContext.delete(round)
        }
    }

    private func deleteOlderRounds(at offsets: IndexSet) {
        for index in offsets {
            let round = olderRounds[index]
            modelContext.delete(round)
        }
    }
}

// SplashView and FairwayVectorMark are shared app-level types (see SplashView.swift, FairwayVectorMark.swift).

private struct TargetModePicker: View {
    @Binding var inputMode: RoundInputMode
    let hasHoleByHoleData: Bool
    var allowsStableford: Bool = true
    var allowsHoleByHole: Bool = true

    private var selection: Binding<RoundInputMode> {
        Binding(
            get: { inputMode },
            set: { newMode in
                guard newMode != .holeByHole || hasHoleByHoleData else { return }
                inputMode = newMode
            }
        )
    }

    var body: some View {
        Picker("Target", selection: selection) {
            ForEach(RoundInputMode.allCases.filter {
                (allowsStableford || $0 != .stablefordPoints) &&
                (allowsHoleByHole || $0 != .holeByHole)
            }) { mode in
                TargetModeRow(mode: mode, isDisabled: mode == .holeByHole && !hasHoleByHoleData)
            }
        }
        .pickerStyle(.segmented)
    }
}

private struct TargetModeRow: View {
    let mode: RoundInputMode
    let isDisabled: Bool

    var body: some View {
        Text(mode.title)
            .tag(mode)
            .opacity(isDisabled ? 0.45 : 1)
            .disabled(isDisabled)
    }
}

private struct HoleScoreRowView: View {
    let holeNumber: Int
    let par: Int
    let handicapIndex: Int
    let points: Int?
    @Binding var score: Int

    var body: some View {
        ViewThatFits(in: .horizontal) {
            rowContent
            VStack(alignment: .leading, spacing: 8) {
                rowContent
            }
        }
    }

    @ViewBuilder
    private var rowContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hole \(holeNumber)")
                    .font(.headline)
                Text("Par \(par) · Index \(handicapIndex)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let points {
                Text("\(points) pts")
                    .font(.caption.bold().monospacedDigit())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(FairwayVectorColors.orange.opacity(0.15))
                    .foregroundStyle(FairwayVectorColors.orange)
                    .clipShape(Capsule())
            }
            Stepper("\(score)", value: $score, in: 1...15)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}

@MainActor
private struct TargetCalculatorView: View {
    let courseCatalog: CourseCatalogStore
    var clubs: [GolfClub]
    var courses: [GolfCourse]
    var tees: [TeeSet]
    var rounds: [GolfRound]
    var profile: PlayerProfile?

    @State private var searchText = ""
    @State private var selectedClubName = ""
    @State private var selectedCourseName = ""
    @State private var selectedTeeName = ""
    @State private var inputMode = RoundInputMode.adjustedGrossScore
    @State private var improvingLimit = 6
    @State private var showMoreWorsening = false
    @State private var showingAddCourse = false
    @State private var showSettings = false
    @State private var projectionResults: [TargetResult] = []
    @State private var projectionHandicap: Double?

    private var activeCountry: String {
        profile?.countryOrDefault ?? "Sweden"
    }

    private var clubsInCountry: [CourseClubInfo] {
        let bundled = courseCatalog.clubs(in: activeCountry)
        let custom = clubs
            .filter { $0.country.localizedCaseInsensitiveCompare(activeCountry) == .orderedSame }
            .map(CourseClubInfo.init(custom:))
        return bundled + custom
    }

    private var validClubNames: Set<String> {
        Set(clubsInCountry.map(\.name))
    }

    private var eligibleTeesInCountry: [CourseTeeInfo] {
        let sex = profile?.sexOrDefault ?? .male
        let bundled = courseCatalog.tees(in: activeCountry, for: sex)
        let custom = tees
            .filter { validClubNames.contains($0.clubName) && $0.isAvailable(for: sex) }
            .map(CourseTeeInfo.init(custom:))
        return bundled + custom
    }

    private struct ClubMatch: Identifiable {
        var id: String { club.name }
        var club: CourseClubInfo
        var courseNames: [String]
    }

    private var matchedClubs: [ClubMatch] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let coursesByClub = Dictionary(grouping: eligibleTeesInCountry, by: \.clubName)
            .mapValues { tees in
                Array(Set(tees.map(\.courseName))).sorted()
            }

        let matches = clubsInCountry.compactMap { club in
            let allCourses = coursesByClub[club.name] ?? []

            if query.isEmpty {
                return ClubMatch(club: club, courseNames: allCourses)
            }

            let clubMatches = club.name.localizedCaseInsensitiveContains(query) || club.city.localizedCaseInsensitiveContains(query)
            let matchingCourses = allCourses.filter { $0.localizedCaseInsensitiveContains(query) }

            if clubMatches || !matchingCourses.isEmpty {
                return ClubMatch(club: club, courseNames: allCourses)
            }
            return nil
        }.sorted { $0.club.name < $1.club.name }
        return Array(matches.prefix(query.isEmpty ? 24 : 60))
    }

    private var availableCourses: [String] {
        guard !selectedClubName.isEmpty else { return [] }
        return Array(Set(eligibleTeesInCountry.filter { $0.clubName == selectedClubName }.map(\.courseName))).sorted()
    }

    private var availableTees: [CourseTeeInfo] {
        guard !selectedClubName.isEmpty, !selectedCourseName.isEmpty else { return [] }
        return eligibleTeesInCountry.filter { $0.clubName == selectedClubName && $0.courseName == selectedCourseName }
    }

    private var selectedTee: CourseTeeInfo? {
        guard !selectedClubName.isEmpty, !selectedCourseName.isEmpty, !selectedTeeName.isEmpty else { return nil }
        return availableTees.first { $0.name == selectedTeeName }
    }

    private var selectedTeeSummary: String {
        guard let selectedTee else { return "" }
        let rating = selectedTee.courseRating.formatted(.number.precision(.fractionLength(1)))
        return "Par \(selectedTee.par) • CR \(rating) • Slope \(selectedTee.slopeRating)"
    }

    private var hasHoleByHoleData: Bool {
        guard let selectedTee else { return false }
        let parData = selectedTee.holeParsData ?? []
        let hcpData = selectedTee.holeHandicapIndicesData ?? []
        return parData.count == selectedTee.holes && hcpData.count == selectedTee.holes && !parData.isEmpty && !hcpData.isEmpty
    }

    private var entries: [ScoringRecordEntry] {
        WHSCalculator.scoringEntries(from: rounds, lowHandicapIndex: profile?.lowHandicapIndex)
    }

    private var currentHandicap: Double? {
        WHSCalculator.handicapIndex(from: entries, lowHandicapIndex: profile?.lowHandicapIndex)
    }

    private var results: [TargetResult] {
        guard let selectedTee else { return [] }
        return WHSCalculator.targetResults(
            currentEntries: entries,
            tee: selectedTee.snapshot,
            inputMode: inputMode,
            lowHandicapIndex: profile?.lowHandicapIndex
        )
    }

    private func improvingResults(from results: [TargetResult]) -> [TargetResult] {
        let list = results.filter { $0.change < 0 }
        switch inputMode {
        case .adjustedGrossScore, .holeByHole:
            return list.sorted { $0.value > $1.value }
        case .stablefordPoints:
            return list.sorted { $0.value < $1.value }
        }
    }

    private func worseningResults(from results: [TargetResult], currentHandicap: Double?) -> [TargetResult] {
        guard let currentHandicap else { return [] }
        let list = results.filter { $0.projectedHandicapIndex > currentHandicap }
        let sorted: [TargetResult]
        switch inputMode {
        case .adjustedGrossScore, .holeByHole:
            sorted = list.sorted { $0.value < $1.value }
        case .stablefordPoints:
            sorted = list.sorted { $0.value > $1.value }
        }

        var shownIndexes = Set<Double>()
        return sorted.filter { shownIndexes.insert($0.projectedHandicapIndex).inserted }
    }

    var body: some View {
        let displayedClubs = selectedClubName.isEmpty ? matchedClubs : []
        let selectionTees = selectedClubName.isEmpty
            ? []
            : eligibleTeesInCountry.filter { $0.clubName == selectedClubName }
        let courseOptions = Array(Set(selectionTees.map(\.courseName))).sorted()
        let teeOptions = selectionTees.filter { $0.courseName == selectedCourseName }
        let activeTee = teeOptions.first { $0.name == selectedTeeName }
        let activeHasHoleDetails = activeTee.map {
            let pars = $0.holeParsData ?? []
            let indices = $0.holeHandicapIndicesData ?? []
            return pars.count == $0.holes && indices.count == $0.holes && !pars.isEmpty && !indices.isEmpty
        } ?? false
        let calculatedHandicap = projectionHandicap
        let calculatedResults = projectionResults
        let improvingResults = improvingResults(from: calculatedResults)
        let worseningResults = worseningResults(from: calculatedResults, currentHandicap: calculatedHandicap)
        let projectionKey = "\(activeCountry)|\(profile?.sexOrDefault.rawValue ?? PlayerSex.male.rawValue)|\(selectedClubName)|\(selectedCourseName)|\(selectedTeeName)|\(inputMode.rawValue)|\(rounds.count)|\(profile?.lowHandicapIndex ?? 0)"

        NavigationStack {
            List {
                if selectedClubName.isEmpty {
                    Section {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Search club or course name...", text: $searchText)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        Text("Search in \(activeCountry)")
                    }
                    .listRowBackground(FairwayVectorColors.surface)
                }

                if !selectedClubName.isEmpty {
                    Section("Selected Club") {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedClubName)
                                    .font(.headline)
                                if let city = clubsInCountry.first(where: { $0.name == selectedClubName })?.city, !city.isEmpty {
                                    Text("\(city) · \(activeCountry)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if !courseOptions.isEmpty {
                            Picker("Course", selection: $selectedCourseName) {
                                Text("Select Course").tag("")
                                ForEach(courseOptions, id: \.self) { course in
                                    Text(course).tag(course)
                                }
                            }
                            .onChange(of: selectedCourseName) {
                                selectedTeeName = ""
                                improvingLimit = 6
                            }
                        }

                        if !selectedCourseName.isEmpty {
                            Picker("Tee", selection: $selectedTeeName) {
                                Text("Select Tee").tag("")
                                ForEach(teeOptions) { tee in
                                    Text(tee.name).tag(tee.name)
                                }
                            }
                            .onChange(of: selectedTeeName) {
                                projectionResults = []
                                projectionHandicap = nil
                                improvingLimit = 6
                            }
                        }

                        if let activeTee {
                            let rating = activeTee.courseRating.formatted(.number.precision(.fractionLength(1)))
                            Text("Par \(activeTee.par) • CR \(rating) • Slope \(activeTee.slopeRating)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if activeTee != nil {
                            TargetModePicker(
                                inputMode: $inputMode,
                                hasHoleByHoleData: activeHasHoleDetails,
                                allowsHoleByHole: false
                            )
                                .onChange(of: inputMode) {
                                    if !activeHasHoleDetails && inputMode == .holeByHole {
                                        inputMode = .adjustedGrossScore
                                    }
                                    improvingLimit = 6
                                }
                                .onChange(of: selectedTeeName) {
                                    if !activeHasHoleDetails && inputMode == .holeByHole {
                                        inputMode = .adjustedGrossScore
                                    }
                                }
                        }
                    }
                    .listRowBackground(FairwayVectorColors.surface)
                } else {
                    Section(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Suggested Clubs" : "Matching Clubs (\(displayedClubs.count))") {
                        if displayedClubs.isEmpty {
                            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                ContentUnavailableView("No clubs found", systemImage: "flag", description: Text("No courses available for \(activeCountry). Add one or switch country in Settings."))
                            } else {
                                ContentUnavailableView("No clubs found", systemImage: "magnifyingglass", description: Text("No matches for \"\(searchText)\" in \(activeCountry)"))
                            }
                        } else {
                            ForEach(displayedClubs) { match in
                                Button {
                                    selectedClubName = match.club.name
                                    if match.courseNames.count == 1, let singleCourse = match.courseNames.first {
                                        selectedCourseName = singleCourse
                                    } else {
                                        selectedCourseName = ""
                                    }
                                    selectedTeeName = ""
                                    improvingLimit = 6
                                    searchText = ""
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(match.club.name)
                                                .font(.headline)
                                                .foregroundStyle(Color.primary)
                                            HStack(spacing: 4) {
                                                if !match.club.city.isEmpty {
                                                    Text("\(match.club.city) ·")
                                                }
                                                Text("\(match.courseNames.count) \(match.courseNames.count == 1 ? "course" : "courses")")
                                            }
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            Text(match.courseNames.prefix(2).joined(separator: " · "))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }

                        Button {
                            showingAddCourse = true
                        } label: {
                            Label("Can't find your club? Add custom course", systemImage: "plus.circle")
                                .font(.subheadline)
                                .foregroundStyle(FairwayVectorColors.orange)
                        }
                    }
                    .listRowBackground(FairwayVectorColors.surface)
                }

                if let calculatedHandicap, let activeTee {
                    Section("Current") {
                        LabeledContent("Handicap Index", value: WHSCalculator.formatHCPScore(calculatedHandicap))
                        LabeledContent("Course Handicap", value: "\(WHSCalculator.courseHandicap(handicapIndex: calculatedHandicap, tee: activeTee.snapshot))")
                    }
                    .listRowBackground(FairwayVectorColors.surface)
                }

                if activeTee != nil {
                    if calculatedResults.isEmpty {
                        Section("Outcomes") {
                            ContentUnavailableView("No outcomes calculated", systemImage: "equal.circle", description: Text("Add at least three rounds or select another tee."))
                        }
                        .listRowBackground(FairwayVectorColors.surface)
                    } else {
                        if !improvingResults.isEmpty {
                            Section {
                                ForEach(improvingResults.prefix(improvingLimit)) { result in
                                    TargetResultRow(result: result)
                                }
                                if improvingLimit > 6 || improvingResults.count > improvingLimit {
                                    HStack {
                                        if improvingResults.count > improvingLimit {
                                            Button("Show more") {
                                                withAnimation {
                                                    improvingLimit = min(improvingLimit + 6, improvingResults.count)
                                                }
                                            }
                                            .buttonStyle(.bordered)
                                            .tint(FairwayVectorColors.navy)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        Spacer()
                                        if improvingLimit > 6 {
                                            Button("Show less") {
                                                withAnimation {
                                                    improvingLimit = max(6, improvingLimit - 6)
                                                }
                                            }
                                            .buttonStyle(.bordered)
                                            .tint(FairwayVectorColors.navy)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                        }
                                    }
                                }
                            } header: {
                                Text("Lower Handicap Index")
                            }
                            .listRowBackground(FairwayVectorColors.surface)
                        }

                        if !worseningResults.isEmpty {
                            Section {
                                ForEach(showMoreWorsening ? worseningResults : Array(worseningResults.prefix(6))) { result in
                                    TargetResultRow(result: result)
                                }
                                if worseningResults.count > 6 {
                                    Button(showMoreWorsening ? "Show fewer" : "Show all \(worseningResults.count) worsening outcomes") {
                                        showMoreWorsening.toggle()
                                    }
                                }
                            } header: {
                                Text("Higher Handicap Index")
                            }
                            .listRowBackground(FairwayVectorColors.surface)
                        } else {
                            Section {
                                Text("No score would raise your Handicap Index.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } header: {
                                Text("Higher Handicap Index")
                            }
                            .listRowBackground(FairwayVectorColors.surface)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(FairwayVectorColors.background)
            .toolbar {
                if !selectedClubName.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            selectedClubName = ""
                            selectedCourseName = ""
                            selectedTeeName = ""
                            projectionResults = []
                            projectionHandicap = nil
                            improvingLimit = 6
                            showMoreWorsening = false
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings) {
                HCPSettingsView(courseCatalog: courseCatalog, profile: profile, clubs: clubs, courses: courses, tees: tees)
            }
            .sheet(isPresented: $showingAddCourse) {
                AddCourseView(courseCatalog: courseCatalog, profile: profile, clubs: clubs, courses: courses, tees: tees, initialClubName: searchText, initialCountry: activeCountry)
            }
            .onAppear {
                if let defaultMode = profile?.defaultInputMode {
                    inputMode = defaultMode
                }
                if rounds.count < 3 && inputMode == .stablefordPoints {
                    inputMode = .adjustedGrossScore
                }
                if !hasHoleByHoleData && inputMode == .holeByHole {
                    inputMode = .adjustedGrossScore
                }
            }
            .task(id: projectionKey) {
                await refreshProjection()
            }
        }
    }

    @MainActor
    private func refreshProjection() async {
        guard let selectedTee else {
            projectionResults = []
            projectionHandicap = nil
            return
        }

        await Task.yield()
        guard !Task.isCancelled else { return }

        let currentEntries = entries
        let handicap = WHSCalculator.handicapIndex(
            from: currentEntries,
            lowHandicapIndex: profile?.lowHandicapIndex
        )
        let results = WHSCalculator.targetResults(
            currentEntries: currentEntries,
            tee: selectedTee.snapshot,
            inputMode: inputMode,
            lowHandicapIndex: profile?.lowHandicapIndex
        )

        guard !Task.isCancelled else { return }
        projectionHandicap = handicap
        projectionResults = results
    }
}

@MainActor
private struct NewRoundView: View {
    @Environment(\.modelContext) private var modelContext

    let courseCatalog: CourseCatalogStore
    var clubs: [GolfClub]
    var courses: [GolfCourse]
    var tees: [TeeSet]
    var rounds: [GolfRound]
    var profile: PlayerProfile?

    @State private var searchText = ""
    @State private var selectedClubName = ""
    @State private var selectedCourseName = ""
    @State private var selectedTeeName = ""
    @State private var inputMode = RoundInputMode.adjustedGrossScore
    @State private var isManualDifferential = false
    @State private var manualDifferentialText = ""
    @State private var roundDate = Date()
    @State private var strokes = 88
    @State private var points = 36
    @State private var pcc = 0.0
    @State private var notes = ""
    @State private var showingAddCourse = false
    @State private var showSettings = false
    @State private var holeScores: [Int] = Array(repeating: 4, count: 18)

    private var activeCountry: String {
        profile?.countryOrDefault ?? "Sweden"
    }

    private var clubsInCountry: [CourseClubInfo] {
        let bundled = courseCatalog.clubs(in: activeCountry)
        let custom = clubs
            .filter { $0.country.localizedCaseInsensitiveCompare(activeCountry) == .orderedSame }
            .map(CourseClubInfo.init(custom:))
        return bundled + custom
    }

    private var validClubNames: Set<String> {
        Set(clubsInCountry.map(\.name))
    }

    private var eligibleTeesInCountry: [CourseTeeInfo] {
        let sex = profile?.sexOrDefault ?? .male
        let bundled = courseCatalog.tees(in: activeCountry, for: sex)
        let custom = tees
            .filter { validClubNames.contains($0.clubName) && $0.isAvailable(for: sex) }
            .map(CourseTeeInfo.init(custom:))
        return bundled + custom
    }

    private struct ClubMatch: Identifiable {
        var id: String { club.name }
        var club: CourseClubInfo
        var courseNames: [String]
    }

    private var matchedClubs: [ClubMatch] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let coursesByClub = Dictionary(grouping: eligibleTeesInCountry, by: \.clubName)
            .mapValues { tees in
                Array(Set(tees.map(\.courseName))).sorted()
            }

        let matches = clubsInCountry.compactMap { club in
            let allCourses = coursesByClub[club.name] ?? []

            if query.isEmpty {
                return ClubMatch(club: club, courseNames: allCourses)
            }

            let clubMatches = club.name.localizedCaseInsensitiveContains(query) || club.city.localizedCaseInsensitiveContains(query)
            let matchingCourses = allCourses.filter { $0.localizedCaseInsensitiveContains(query) }

            if clubMatches || !matchingCourses.isEmpty {
                return ClubMatch(club: club, courseNames: allCourses)
            }
            return nil
        }.sorted { $0.club.name < $1.club.name }
        return Array(matches.prefix(query.isEmpty ? 24 : 60))
    }

    private var availableCourses: [String] {
        guard !selectedClubName.isEmpty else { return [] }
        return Array(Set(eligibleTeesInCountry.filter { $0.clubName == selectedClubName }.map(\.courseName))).sorted()
    }

    private var availableTees: [CourseTeeInfo] {
        guard !selectedClubName.isEmpty, !selectedCourseName.isEmpty else { return [] }
        return eligibleTeesInCountry.filter { $0.clubName == selectedClubName && $0.courseName == selectedCourseName }
    }

    private var selectedTee: CourseTeeInfo? {
        guard !selectedClubName.isEmpty, !selectedCourseName.isEmpty, !selectedTeeName.isEmpty else { return nil }
        return availableTees.first { $0.name == selectedTeeName }
    }

    private var selectedTeeSummary: String {
        guard let selectedTee else { return "" }
        let rating = selectedTee.courseRating.formatted(.number.precision(.fractionLength(1)))
        return "Par \(selectedTee.par) • CR \(rating) • Slope \(selectedTee.slopeRating)"
    }

    private var hasHoleByHoleData: Bool {
        guard let selectedTee else { return false }
        let parData = selectedTee.holeParsData ?? []
        let hcpData = selectedTee.holeHandicapIndicesData ?? []
        return parData.count == selectedTee.holes && hcpData.count == selectedTee.holes && !parData.isEmpty && !hcpData.isEmpty
    }

    private var currentHandicap: Double? {
        let entries = WHSCalculator.scoringEntries(from: rounds, lowHandicapIndex: profile?.lowHandicapIndex)
        return WHSCalculator.handicapIndex(from: entries, lowHandicapIndex: profile?.lowHandicapIndex)
    }

    var body: some View {
        let displayedClubs = !isManualDifferential && selectedClubName.isEmpty ? matchedClubs : []
        let selectionTees = selectedClubName.isEmpty
            ? []
            : eligibleTeesInCountry.filter { $0.clubName == selectedClubName }
        let courseOptions = Array(Set(selectionTees.map(\.courseName))).sorted()
        let teeOptions = selectionTees.filter { $0.courseName == selectedCourseName }
        let activeTee = teeOptions.first { $0.name == selectedTeeName }
        let activeHasHoleDetails = activeTee.map {
            let pars = $0.holeParsData ?? []
            let indices = $0.holeHandicapIndicesData ?? []
            return pars.count == $0.holes && indices.count == $0.holes && !pars.isEmpty && !indices.isEmpty
        } ?? false
        let calculatedHandicap = activeTee == nil ? nil : currentHandicap

        NavigationStack {
            Form {
                if !isManualDifferential && selectedClubName.isEmpty {
                    Section {
                        Button {
                            isManualDifferential = true
                            searchText = ""
                        } label: {
                            HStack {
                                Label("No course", systemImage: "minus.circle")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                            Text("Use this when the course is not available and you already know the official HCP score.")
                                .font(.caption)
                                .foregroundStyle(FairwayVectorColors.slate)
                                .fixedSize(horizontal: false, vertical: true)
                    }
                    .listRowBackground(FairwayVectorColors.surface)

                    Section {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Search club or course name...", text: $searchText)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        Text("Search in \(activeCountry)")
                    }
                    .listRowBackground(FairwayVectorColors.surface)
                }

                if isManualDifferential || !selectedCourseName.isEmpty {
                    Section("Round Details") {
                        DatePicker("Date", selection: $roundDate, displayedComponents: .date)
                    }
                    .listRowBackground(FairwayVectorColors.surface)
                }

                if isManualDifferential {
                    Section("No Course") {
                        TextField("HCP score", text: $manualDifferentialText)
                            .keyboardType(.decimalPad)
                        Text("Enter the official HCP score for this round.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(FairwayVectorColors.surface)
                }

                if !isManualDifferential && !selectedClubName.isEmpty {
                    Section("Selected Club") {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedClubName)
                                    .font(.headline)
                                if let city = clubsInCountry.first(where: { $0.name == selectedClubName })?.city, !city.isEmpty {
                                    Text("\(city) · \(activeCountry)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if !courseOptions.isEmpty {
                            Picker("Course", selection: $selectedCourseName) {
                                Text("Select Course").tag("")
                                ForEach(courseOptions, id: \.self) { course in
                                    Text(course).tag(course)
                                }
                            }
                            .onChange(of: selectedCourseName) {
                                selectedTeeName = ""
                            }
                        }

                        if !selectedCourseName.isEmpty {
                            Picker("Tee", selection: $selectedTeeName) {
                                Text("Select Tee").tag("")
                                ForEach(teeOptions) { tee in
                                    Text(tee.name).tag(tee.name)
                                }
                            }
                            .onChange(of: selectedTeeName) {
                                resetHoleScores()
                            }
                        }

                        if let activeTee {
                            let rating = activeTee.courseRating.formatted(.number.precision(.fractionLength(1)))
                            Text("Par \(activeTee.par) • CR \(rating) • Slope \(activeTee.slopeRating)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        TargetModePicker(
                            inputMode: $inputMode,
                            hasHoleByHoleData: activeHasHoleDetails,
                            allowsStableford: rounds.count >= 3
                        )
                            .onChange(of: inputMode) {
                                if !activeHasHoleDetails && inputMode == .holeByHole {
                                    inputMode = .adjustedGrossScore
                                }
                            }
                            .onChange(of: selectedTeeName) {
                                if !activeHasHoleDetails && inputMode == .holeByHole {
                                    inputMode = .adjustedGrossScore
                                }
                            }

                        if !activeHasHoleDetails {
                            Text("Hole-by-hole scoring requires hole details for this tee.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if rounds.count < 3 {
                            Text("Stableford scoring becomes available after three rounds have been entered.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(FairwayVectorColors.surface)
                } else if !isManualDifferential {
                    Section(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Suggested Clubs" : "Matching Clubs (\(displayedClubs.count))") {
                        if displayedClubs.isEmpty {
                            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                ContentUnavailableView("No clubs found", systemImage: "flag", description: Text("No courses available for \(activeCountry). Add one or switch country in Settings."))
                            } else {
                                ContentUnavailableView("No clubs found", systemImage: "magnifyingglass", description: Text("No matches for \"\(searchText)\" in \(activeCountry)"))
                            }
                        } else {
                            ForEach(displayedClubs) { match in
                                Button {
                                    selectedClubName = match.club.name
                                    if match.courseNames.count == 1, let singleCourse = match.courseNames.first {
                                        selectedCourseName = singleCourse
                                    } else {
                                        selectedCourseName = ""
                                    }
                                    selectedTeeName = ""
                                    searchText = ""
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(match.club.name)
                                                .font(.headline)
                                                .foregroundStyle(Color.primary)
                                            HStack(spacing: 4) {
                                                if !match.club.city.isEmpty {
                                                    Text("\(match.club.city) ·")
                                                }
                                                Text("\(match.courseNames.count) \(match.courseNames.count == 1 ? "course" : "courses")")
                                            }
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            Text(match.courseNames.prefix(2).joined(separator: " · "))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }

                        Button {
                            showingAddCourse = true
                        } label: {
                            Label("Can't find your club? Add custom course", systemImage: "plus.circle")
                                .font(.subheadline)
                                .foregroundStyle(FairwayVectorColors.orange)
                        }
                    }
                    .listRowBackground(FairwayVectorColors.surface)
                }

                if !isManualDifferential, let activeTee {
                    if inputMode == .holeByHole && activeHasHoleDetails {
                        let holeCount = activeTee.holes
                        let pars = activeTee.holePars
                        let hcpIndices = activeTee.holeHandicapIndices
                        let safeHoleCount = min(holeCount, min(holeScores.count, min(pars.count, hcpIndices.count)))
                        let ch = WHSCalculator.courseHandicap(handicapIndex: calculatedHandicap ?? 0, tee: activeTee.snapshot)
                        let holeCalc = WHSCalculator.calculateHoleByHole(
                            holeScores: Array(holeScores.prefix(safeHoleCount)),
                            holePars: pars,
                            holeHandicapIndices: hcpIndices,
                            courseHandicap: ch
                        )

                        Section("Round Summary") {
                            HStack {
                                Text("Total Gross")
                                Spacer()
                                Text("\(holeCalc.totalGrossScore)")
                                    .monospacedDigit()
                                    .bold()
                            }
                            HStack {
                                Text("WHS Adjusted Score")
                                Spacer()
                                Text("\(holeCalc.netDoubleBogeyAdjustedScore)")
                                    .monospacedDigit()
                                    .bold()
                            }
                            HStack {
                                Text("Stableford Points")
                                Spacer()
                                Text("\(holeCalc.totalStablefordPoints) pts")
                                    .monospacedDigit()
                                    .bold()
                                    .foregroundStyle(FairwayVectorColors.orange)
                            }
                        }
                        .listRowBackground(FairwayVectorColors.surface)

                        Section("Hole by Hole Scores") {
                            ForEach(0..<safeHoleCount, id: \.self) { i in
                                let scoreBinding = Binding<Int>(
                                    get: { i < holeScores.count ? holeScores[i] : pars[i] },
                                    set: { newVal in
                                        if i < holeScores.count {
                                            holeScores[i] = newVal
                                        }
                                    }
                                )
                                HoleScoreRowView(
                                    holeNumber: i + 1,
                                    par: pars[i],
                                    handicapIndex: hcpIndices[i],
                                    points: i < holeCalc.holePoints.count ? holeCalc.holePoints[i] : nil,
                                    score: scoreBinding
                                )
                            }
                        }
                        .listRowBackground(FairwayVectorColors.surface)
                    } else {
                        Section("Score") {
                            if inputMode == .adjustedGrossScore {
                                HStack {
                                    InfoLabel(
                                        title: "Adjusted Gross Score",
                                        explanation: "Adjusted Gross Score is the total strokes you took after WHS maximums are applied on any hole. It is used to calculate your handicap differential and removes the effect of a few unusually bad holes."
                                    )
                                    Spacer()
                                    Text("\(strokes)")
                                        .font(.body.bold())
                                    Stepper("", value: $strokes, in: 45...160)
                                        .labelsHidden()
                                }
                            } else if inputMode == .stablefordPoints {
                                Stepper("Stableford points: \(points)", value: $points, in: 0...54)
                            }
                        }
                        .listRowBackground(FairwayVectorColors.surface)
                    }

                    Section("Conditions & Notes") {
                        HStack {
                            InfoLabel(
                                title: "PCC",
                                explanation: "Playing Conditions Calculation. It adjusts your handicap differential for unusually easy or difficult course conditions, such as wind, rain, green speed, or setup. A positive value means conditions were harder than normal; a negative value means easier than normal."
                            )
                            Spacer()
                            Text(pcc.formatted(.number.precision(.fractionLength(1))))
                                .font(.body.bold())
                            Stepper("", value: $pcc, in: -1...3, step: 1)
                                .labelsHidden()
                        }
                        TextField("Notes", text: $notes)
                    }
                    .listRowBackground(FairwayVectorColors.surface)

                }

                if isManualDifferential {
                    Section("Notes") {
                        TextField("Notes", text: $notes)
                    }
                    .listRowBackground(FairwayVectorColors.surface)

                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(FairwayVectorColors.background)
            .toolbar {
                if isManualDifferential || !selectedClubName.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            isManualDifferential = false
                            selectedClubName = ""
                            selectedCourseName = ""
                            selectedTeeName = ""
                            manualDifferentialText = ""
                            searchText = ""
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                    }
                }
                if isManualDifferential || !selectedClubName.isEmpty {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button("Save") { saveRound() }
                            .disabled(!canSaveRound)

                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                    }
                }
            }
            .toolbarBackground(FairwayVectorColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showSettings) {
                HCPSettingsView(courseCatalog: courseCatalog, profile: profile, clubs: clubs, courses: courses, tees: tees)
            }
            .sheet(isPresented: $showingAddCourse) {
                AddCourseView(courseCatalog: courseCatalog, profile: profile, clubs: clubs, courses: courses, tees: tees, initialClubName: searchText, initialCountry: activeCountry)
            }
            .onAppear {
                if let defaultMode = profile?.defaultInputMode {
                    inputMode = defaultMode
                }
                if !hasHoleByHoleData && inputMode == .holeByHole {
                    inputMode = .adjustedGrossScore
                }
                resetHoleScores()
            }
            .onChange(of: isManualDifferential) {
                if isManualDifferential {
                    selectedClubName = ""
                    selectedCourseName = ""
                    selectedTeeName = ""
                }
            }
        }
    }

    private func resetHoleScores() {
        let count = selectedTee?.holes ?? 18
        let pars = selectedTee?.holePars ?? TeeSet.defaultPars(for: count, totalPar: selectedTee?.par ?? 72)
        holeScores = pars
    }

    private func saveRound() {
        if isManualDifferential {
            guard let handicapDifferential = parsedManualDifferential else { return }
            modelContext.insert(
                GolfRound(
                    date: roundDate,
                    clubName: "",
                    courseName: "",
                    teeName: "",
                    holes: 18,
                    inputMode: .adjustedGrossScore,
                    handicapDifferential: handicapDifferential,
                    par: 72,
                    courseRating: 0,
                    slopeRating: 113,
                    pcc: 0,
                    notes: notes
                )
            )
            notes = ""
            manualDifferentialText = ""
            roundDate = Date()
            isManualDifferential = false
            return
        }

        guard let selectedTee else { return }
        if !hasHoleByHoleData && inputMode == .holeByHole {
            inputMode = .adjustedGrossScore
            return
        }
        let courseHandicap = WHSCalculator.courseHandicap(handicapIndex: currentHandicap ?? 0, tee: selectedTee.snapshot)

        let finalAdjustedScore: Int
        let finalPoints: Int?
        let recordedHoleScores: [Int]?
        let recordedHolePars: [Int]?
        let recordedHoleIndices: [Int]?

        switch inputMode {
        case .adjustedGrossScore:
            finalAdjustedScore = strokes
            finalPoints = nil
            recordedHoleScores = nil
            recordedHolePars = nil
            recordedHoleIndices = nil

        case .stablefordPoints:
            finalAdjustedScore = WHSCalculator.stablefordAdjustedGrossScore(
                points: points,
                par: selectedTee.par,
                courseHandicap: courseHandicap,
                holes: selectedTee.holes
            )
            finalPoints = points
            recordedHoleScores = nil
            recordedHolePars = nil
            recordedHoleIndices = nil

        case .holeByHole:
            let pars = selectedTee.holePars
            let indices = selectedTee.holeHandicapIndices
            let holeCount = selectedTee.holes
            let currentScores = Array(holeScores.prefix(holeCount))
            let calc = WHSCalculator.calculateHoleByHole(
                holeScores: currentScores,
                holePars: pars,
                holeHandicapIndices: indices,
                courseHandicap: courseHandicap
            )
            finalAdjustedScore = calc.netDoubleBogeyAdjustedScore
            finalPoints = calc.totalStablefordPoints
            recordedHoleScores = currentScores
            recordedHolePars = pars
            recordedHoleIndices = indices
        }

        modelContext.insert(
            GolfRound(
                date: roundDate,
                clubName: selectedTee.clubName,
                courseName: selectedTee.courseName,
                teeName: selectedTee.name,
                holes: selectedTee.holes,
                inputMode: inputMode,
                adjustedGrossScore: finalAdjustedScore,
                stablefordPoints: finalPoints,
                par: selectedTee.par,
                courseRating: selectedTee.courseRating,
                slopeRating: selectedTee.slopeRating,
                pcc: pcc,
                notes: notes,
                holeScoresData: recordedHoleScores,
                holeParsData: recordedHolePars,
                holeHandicapIndicesData: recordedHoleIndices
            )
        )
        notes = ""
        roundDate = Date()
        selectedClubName = ""
        selectedCourseName = ""
        selectedTeeName = ""
    }

    private var canSaveRound: Bool {
        if isManualDifferential {
            return parsedManualDifferential != nil
        }

        guard !selectedClubName.isEmpty,
              !selectedCourseName.isEmpty,
              !selectedTeeName.isEmpty,
              let selectedTee else { return false }

        if inputMode == .holeByHole {
            return holeScores.count == selectedTee.holes && holeScores.allSatisfy { $0 > 0 }
        }

        switch inputMode {
        case .adjustedGrossScore:
            return (45...160).contains(strokes)
        case .stablefordPoints:
            return (0...54).contains(points)
        case .holeByHole:
            return true
        }
    }

    private var parsedManualDifferential: Double? {
        let normalized = manualDifferentialText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value >= -20, value <= 54 else { return nil }
        return WHSCalculator.roundToTenth(value)
    }
}

private struct DrillRowView: View {
    var title: String
    var subtitle: String?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

private struct CustomTeeListRow: View {
    var tee: TeeSet
    var club: GolfClub?

    private var summary: String {
        let rating = tee.courseRating.formatted(.number.precision(.fractionLength(1)))
        let category = tee.ratingSex?.label ?? "Universal"
        return "Tee: \(tee.name) · \(category) · Par \(tee.par) · CR \(rating) · Slope \(tee.slopeRating)"
    }

    var body: some View {
        NavigationLink {
            CustomTeeDetailView(tee: tee, club: club)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(tee.clubName) · \(tee.courseName)")
                    .font(.headline)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct CustomCoursesView: View {
    @Environment(\.modelContext) private var modelContext
    let courseCatalog: CourseCatalogStore
    var profile: PlayerProfile?
    var clubs: [GolfClub]
    var courses: [GolfCourse]
    var tees: [TeeSet]

    @State private var showingAddCourse = false
    @State private var showGrouped = false
    @State private var searchText = ""
    @State private var selectedCountry: String?
    @State private var selectedCity: String?
    @State private var selectedClub: String?
    @State private var selectedCourse: String?

    private var customTees: [TeeSet] {
        tees.filter { $0.isCustom ?? false }
    }

    private var customClubs: [GolfClub] {
        clubs.filter { $0.isCustom ?? false }
    }

    private var filteredTees: [TeeSet] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return customTees }
        return customTees.filter { tee in
            if tee.clubName.localizedCaseInsensitiveContains(query)
                || tee.courseName.localizedCaseInsensitiveContains(query)
                || tee.name.localizedCaseInsensitiveContains(query) {
                return true
            }
            guard let club = clubs.first(where: { $0.name == tee.clubName }) else { return false }
            return club.city.localizedCaseInsensitiveContains(query) || club.country.localizedCaseInsensitiveContains(query)
        }
    }

    private var groupedCountries: [String] {
        Array(Set(customClubs.map(\.country).filter { !$0.isEmpty })).sorted()
    }

    private func cityTitle(for club: GolfClub) -> String {
        club.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown City" : club.city
    }

    private func cities(in country: String) -> [String] {
        Array(Set(customClubs.filter { $0.country == country }.map { cityTitle(for: $0) })).sorted()
    }

    private func clubsIn(country: String, city: String) -> [GolfClub] {
        customClubs.filter { $0.country == country && cityTitle(for: $0) == city }.sorted { $0.name < $1.name }
    }

    private func coursesIn(club: String) -> [GolfCourse] {
        courses.filter { ($0.isCustom ?? false) && $0.clubName == club }.sorted { $0.name < $1.name }
    }

    private func teesIn(club: String, course: String) -> [TeeSet] {
        customTees.filter { $0.clubName == club && $0.courseName == course }.sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            Section {
                Picker("View", selection: $showGrouped) {
                    Text("All").tag(false)
                    Text("Grouped").tag(true)
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Color.white)

            if showGrouped {
                groupedRootSections
            } else {
                allSections
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.white)
        .navigationTitle("Custom Courses")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddCourse = true
                } label: {
                    Label("Add Course", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddCourse) {
            AddCourseView(courseCatalog: courseCatalog, profile: profile, clubs: clubs, courses: courses, tees: tees)
        }
        .navigationDestination(for: CustomCourseGroupLevel.self) { level in
            CustomCourseGroupedLevelView(
                level: level,
                courseCatalog: courseCatalog,
                profile: profile,
                clubs: clubs,
                courses: courses,
                tees: tees
            )
        }
    }

    @ViewBuilder
    private var groupedRootSections: some View {
        if groupedCountries.isEmpty {
            Section {
                ContentUnavailableView(
                    "No Custom Courses",
                    systemImage: "flag.badge.ellipsis",
                    description: Text("Add a custom course to browse by region.")
                )
            }
            .listRowBackground(Color.white)
        } else {
            if let preferred = profile?.countryOrDefault, groupedCountries.contains(preferred) {
                Section("Your Region") {
                    NavigationLink(value: CustomCourseGroupLevel.country(preferred)) {
                        DrillRowView(title: preferred, subtitle: nil)
                    }
                }
                .listRowBackground(Color.white)
            }

            Section("All Countries / Regions") {
                ForEach(groupedCountries, id: \.self) { country in
                    NavigationLink(value: CustomCourseGroupLevel.country(country)) {
                        DrillRowView(title: country, subtitle: nil)
                    }
                }
            }
            .listRowBackground(Color.white)
        }
    }

    private func applyDefaultCountry() {
        guard selectedCountry == nil else { return }
        if let defaultCountry = profile?.countryOrDefault, groupedCountries.contains(defaultCountry) {
            selectedCountry = defaultCountry
        }
    }

    private func goBackOneLevel() {
        if selectedCourse != nil {
            selectedCourse = nil
        } else if selectedClub != nil {
            selectedClub = nil
        } else if selectedCity != nil {
            selectedCity = nil
        } else if selectedCountry != nil {
            selectedCountry = nil
        }
    }

    private var sourceTeeForPrefill: TeeSet? {
        guard let club = selectedClub, let course = selectedCourse else { return nil }
        return teesIn(club: club, course: course).first
    }

    @ViewBuilder
    private var allSections: some View {
        if customTees.isEmpty {
            Section {
                ContentUnavailableView(
                    "No Custom Courses",
                    systemImage: "flag.badge.ellipsis",
                    description: Text("Add courses that are missing from the built-in database.")
                )
            }
            .listRowBackground(Color.white)
        } else {
            Section {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search club, course or tee...", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listRowBackground(Color.white)

            if filteredTees.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Matches",
                        systemImage: "magnifyingglass",
                        description: Text("No custom courses match \"\(searchText)\".")
                    )
                }
                .listRowBackground(Color.white)
            } else {
                Section("Your Custom Tees") {
                    ForEach(filteredTees) { tee in
                        CustomTeeListRow(tee: tee, club: clubs.first { $0.name == tee.clubName })
                    }
                    .onDelete(perform: deleteTees)
                }
                .listRowBackground(Color.white)
            }
        }
    }

    @ViewBuilder
    private var groupedSections: some View {
        if let club = selectedClub, let course = selectedCourse {
            teeSections(club: club, course: course)
        } else if let club = selectedClub {
            courseSections(club: club)
        } else if let country = selectedCountry, let city = selectedCity {
            clubSections(country: country, city: city)
        } else if let country = selectedCountry {
            citySections(country: country)
        } else {
            countrySections
        }
    }

    private var countrySections: some View {
        Section("Countries") {
            if groupedCountries.isEmpty {
                Text("No custom courses yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(groupedCountries, id: \.self) { country in
                    Button {
                        selectedCountry = country
                    } label: {
                        DrillRowView(title: country, subtitle: nil)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listRowBackground(Color.white)
    }

    private func citySections(country: String) -> some View {
        let list = cities(in: country)
        return Section("Cities in \(country)") {
            if list.isEmpty {
                Text("No cities with custom courses")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(list, id: \.self) { city in
                    Button {
                        selectedCity = city
                    } label: {
                        DrillRowView(title: city, subtitle: nil)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listRowBackground(Color.white)
    }

    private func clubSections(country: String, city: String) -> some View {
        let list = clubsIn(country: country, city: city)
        return Section("Clubs in \(city)") {
            if list.isEmpty {
                Text("No clubs with custom courses")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(list, id: \.name) { club in
                    Button {
                        selectedClub = club.name
                    } label: {
                        DrillRowView(title: club.name, subtitle: nil)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listRowBackground(Color.white)
    }

    private func courseSections(club: String) -> some View {
        let list = coursesIn(club: club)
        return Section("Courses at \(club)") {
            if list.isEmpty {
                Text("No custom courses")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(list, id: \.name) { course in
                    Button {
                        selectedCourse = course.name
                    } label: {
                        DrillRowView(title: course.name, subtitle: nil)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listRowBackground(Color.white)
    }

    private func teeSections(club: String, course: String) -> some View {
        let list = teesIn(club: club, course: course)
        return Section("Tees at \(course)") {
            if list.isEmpty {
                Text("No custom tees")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(list) { tee in
                    CustomTeeListRow(tee: tee, club: clubs.first { $0.name == tee.clubName })
                }
            }
        }
        .listRowBackground(Color.white)
    }

    private func deleteTees(at offsets: IndexSet) {
        let deletedTees = offsets.map { filteredTees[$0] }
        let deletedIDs = Set(deletedTees.map(\.persistentModelID))
        let remainingTees = customTees.filter { !deletedIDs.contains($0.persistentModelID) }

        for tee in deletedTees {
            modelContext.delete(tee)

            let courseStillUsed = remainingTees.contains {
                $0.clubName == tee.clubName && $0.courseName == tee.courseName
            }
            if !courseStillUsed, let relatedCourse = courses.first(where: {
                $0.isCustom == true && $0.clubName == tee.clubName && $0.name == tee.courseName
            }) {
                modelContext.delete(relatedCourse)
            }

            let clubStillUsed = remainingTees.contains { $0.clubName == tee.clubName }
            if !clubStillUsed, let relatedClub = clubs.first(where: {
                $0.isCustom == true && $0.name == tee.clubName
            }) {
                modelContext.delete(relatedClub)
            }
        }
    }
}

private enum CustomCourseGroupLevel: Hashable {
    case country(String)
    case city(country: String, city: String)
    case club(country: String, city: String, club: String)
    case course(country: String, city: String, club: String, course: String)
}

private struct CustomCourseGroupedLevelView: View {
    let level: CustomCourseGroupLevel
    let courseCatalog: CourseCatalogStore
    var profile: PlayerProfile?
    var clubs: [GolfClub]
    var courses: [GolfCourse]
    var tees: [TeeSet]

    @State private var showingAddCourse = false

    private var customClubs: [GolfClub] {
        clubs.filter { $0.isCustom ?? false }
    }

    private var customTees: [TeeSet] {
        tees.filter { $0.isCustom ?? false }
    }

    private var navigationTitle: String {
        switch level {
        case .country(let country): country
        case .city(_, let city): city
        case .club(_, _, let club): club
        case .course(_, _, _, let course): course
        }
    }

    private var prefill: (country: String, city: String, club: String, course: String) {
        switch level {
        case .country(let country): (country, "", "", "")
        case .city(let country, let city): (country, city == "Unknown City" ? "" : city, "", "")
        case .club(let country, let city, let club): (country, city == "Unknown City" ? "" : city, club, "")
        case .course(let country, let city, let club, let course): (country, city == "Unknown City" ? "" : city, club, course)
        }
    }

    private var sourceTee: TeeSet? {
        guard case .course(_, _, let club, let course) = level else { return nil }
        return customTees.first { $0.clubName == club && $0.courseName == course }
    }

    var body: some View {
        List {
            switch level {
            case .country(let country):
                let cities = Array(Set(customClubs.filter { $0.country == country }.map { cityName($0) })).sorted()
                Section("Cities") {
                    ForEach(cities, id: \.self) { city in
                        NavigationLink(value: CustomCourseGroupLevel.city(country: country, city: city)) {
                            DrillRowView(title: city, subtitle: nil)
                        }
                    }
                }
                .listRowBackground(Color.white)

            case .city(let country, let city):
                let matchingClubs = customClubs.filter { $0.country == country && cityName($0) == city }.sorted { $0.name < $1.name }
                Section("Clubs") {
                    ForEach(matchingClubs, id: \.name) { club in
                        NavigationLink(value: CustomCourseGroupLevel.club(country: country, city: city, club: club.name)) {
                            DrillRowView(title: club.name, subtitle: nil)
                        }
                    }
                }
                .listRowBackground(Color.white)

            case .club(let country, let city, let club):
                let matchingCourses = courses.filter { ($0.isCustom ?? false) && $0.clubName == club }.sorted { $0.name < $1.name }
                Section("Courses") {
                    ForEach(matchingCourses, id: \.name) { course in
                        NavigationLink(value: CustomCourseGroupLevel.course(country: country, city: city, club: club, course: course.name)) {
                            DrillRowView(title: course.name, subtitle: nil)
                        }
                    }
                }
                .listRowBackground(Color.white)

            case .course(_, _, let club, let course):
                let matchingTees = customTees.filter { $0.clubName == club && $0.courseName == course }.sorted { $0.name < $1.name }
                Section("Tees") {
                    ForEach(matchingTees) { tee in
                        CustomTeeListRow(tee: tee, club: customClubs.first { $0.name == tee.clubName })
                    }
                }
                .listRowBackground(Color.white)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.white)
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddCourse = true
                } label: {
                    Label("Add Course", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddCourse) {
            AddCourseView(
                courseCatalog: courseCatalog,
                profile: profile,
                clubs: clubs,
                courses: courses,
                tees: tees,
                initialClubName: prefill.club,
                initialCountry: prefill.country,
                initialCity: prefill.city,
                initialCourseName: prefill.course,
                sourceTee: sourceTee
            )
        }
    }

    private func cityName(_ club: GolfClub) -> String {
        club.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown City" : club.city
    }
}

private struct CustomTeeDetailView: View {
    var tee: TeeSet
    var club: GolfClub?

    private var holeParsData: [Int] {
        tee.holeParsData ?? []
    }

    private var holeHandicapData: [Int] {
        tee.holeHandicapIndicesData ?? []
    }

    private var hasHoleDetails: Bool {
        holeParsData.count == tee.holes && holeHandicapData.count == tee.holes && !holeParsData.isEmpty
    }

    var body: some View {
        List {
            Section("Club") {
                LabeledContent("Club", value: tee.clubName)
                if let club, !club.city.isEmpty {
                    LabeledContent("City", value: club.city)
                }
                if let club, !club.country.isEmpty {
                    LabeledContent("Country", value: club.country)
                }
            }
            .listRowBackground(Color.white)

            Section("Course") {
                LabeledContent("Course", value: tee.courseName)
                LabeledContent("Tee", value: tee.name)
                LabeledContent("Holes", value: "\(tee.holes)")
            }
            .listRowBackground(Color.white)

            Section("WHS Ratings") {
                LabeledContent("Rating for", value: tee.ratingSex?.label ?? "Universal")
                LabeledContent("Par", value: "\(tee.par)")
                LabeledContent("Course Rating", value: tee.courseRating.formatted(.number.precision(.fractionLength(1))))
                LabeledContent("Slope", value: "\(tee.slopeRating)")
            }
            .listRowBackground(Color.white)

            if hasHoleDetails {
                Section("Hole Details") {
                    ForEach(0..<tee.holes, id: \.self) { index in
                        HStack {
                            Text("Hole \(index + 1)")
                            Spacer()
                            Text("Par \(holeParsData[index]) · HCP \(holeHandicapData[index])")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listRowBackground(Color.white)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.white)
        .navigationTitle(tee.courseName)
    }
}

@MainActor
private struct AddCourseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let courseCatalog: CourseCatalogStore
    var profile: PlayerProfile?
    var clubs: [GolfClub]
    var courses: [GolfCourse]
    var tees: [TeeSet] = []

    var initialClubName: String = ""
    var initialCountry: String = ""
    var initialCity: String = ""
    var initialCourseName: String = ""
    var sourceTee: TeeSet? = nil

    @State private var addHoleDetails = false
    @State private var clubName = ""
    @State private var city = ""
    @State private var country = ""
    @State private var isEnteringNewCountry = false
    @State private var courseName = ""
    @State private var teeName = ""
    @State private var holes = 18
    @State private var par = 72
    @State private var courseRating = 72.0
    @State private var slopeRating = 113
    @State private var selectedRatingSex = PlayerSex.male
    @State private var holePars: [Int] = Array(repeating: 0, count: 18)
    @State private var holeHandicapIndices: [Int] = Array(1...18)
    @State private var showHoleHcpWarning = false
    @State private var showDuplicateWarning = false
    @State private var isApplyingPrefill = false

    private var availableCountries: [String] {
        let customCountries = clubs.map(\.country).filter { !$0.isEmpty }
        return Array(Set(courseCatalog.countries + customCountries)).sorted()
    }

    private var countrySelection: Binding<String> {
        Binding(
            get: { isEnteringNewCountry ? "__new_country__" : country },
            set: { selection in
                if selection == "__new_country__" {
                    isEnteringNewCountry = true
                    country = ""
                } else {
                    isEnteringNewCountry = false
                    country = selection
                }
            }
        )
    }

    private var matchingClubs: [CourseClubInfo] {
        guard !clubName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let query = clubName.trimmingCharacters(in: .whitespacesAndNewlines)
        let available = courseCatalog.clubs(in: country) + clubs
            .filter { $0.country == country }
            .map(CourseClubInfo.init(custom:))
        return available.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }.prefix(4).map { $0 }
    }

    private var matchingCourses: [CourseInfo] {
        guard !courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let query = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let clubFilter = clubName.trimmingCharacters(in: .whitespacesAndNewlines)
        let customClubNames = Set(clubs.filter { $0.country == country }.map(\.name))
        let available = courseCatalog.courses(in: country) + courses
            .filter { customClubNames.contains($0.clubName) }
            .map(CourseInfo.init(custom:))
        return available.filter {
            let matchesClub = clubFilter.isEmpty || $0.clubName.localizedCaseInsensitiveContains(clubFilter)
            return matchesClub && $0.name.localizedCaseInsensitiveContains(query)
        }.prefix(4).map { $0 }
    }

    private var totalHolePar: Int {
        holePars.reduce(0, +)
    }

    @ViewBuilder
    private func suggestionList(for items: [CourseClubInfo], onSelect: @escaping (CourseClubInfo) -> Void) -> some View {
        suggestionCard(titles: items.map(\.name)) { index in
            guard items.indices.contains(index) else { return }
            onSelect(items[index])
        }
    }

    @ViewBuilder
    private func suggestionList(for items: [CourseInfo], onSelect: @escaping (CourseInfo) -> Void) -> some View {
        suggestionCard(titles: items.map(\.name)) { index in
            guard items.indices.contains(index) else { return }
            onSelect(items[index])
        }
    }

    @ViewBuilder
    private func suggestionCard(titles: [String], onSelect: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                Button {
                    onSelect(index)
                } label: {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                if index < titles.count - 1 {
                    Divider()
                        .padding(.leading, 12)
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
        .padding(.trailing, 8)
    }

    private func resetHoleDetails() {
        holePars = Array(repeating: 4, count: holes)
        holeHandicapIndices = Array(1...max(holes, 1))
        if addHoleDetails {
            par = totalHolePar
        } else {
            par = 72
        }
    }

    private func updateHolePar(at index: Int, to value: Int) {
        guard holePars.indices.contains(index) else { return }
        holePars[index] = min(max(value, 3), 8)
        par = totalHolePar
    }

    private func applySourceTeePrefillIfNeeded() {
        guard let sourceTee else { return }
        isApplyingPrefill = true
        holes = sourceTee.holes
        par = sourceTee.par
        courseRating = sourceTee.courseRating
        slopeRating = sourceTee.slopeRating
        selectedRatingSex = sourceTee.ratingSex ?? profile?.sexOrDefault ?? .male

        guard let sourcePars = sourceTee.holeParsData,
              let sourceIndices = sourceTee.holeHandicapIndicesData,
              sourcePars.count == sourceTee.holes,
              sourceIndices.count == sourceTee.holes else {
            isApplyingPrefill = false
            return
        }

        addHoleDetails = true
        holePars = sourcePars
        holeHandicapIndices = sourceIndices
        isApplyingPrefill = false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Location · Required") {
                    Picker("Country / Region", selection: countrySelection) {
                        ForEach(availableCountries, id: \.self) { countryOption in
                            Text(countryOption).tag(countryOption)
                        }
                        Text("New country / region…").tag("__new_country__")
                    }
                    if isEnteringNewCountry {
                        TextField("New country / region", text: $country)
                            .textInputAutocapitalization(.words)
                    }
                    TextField("City", text: $city)
                    TextField("Club name", text: $clubName)
                        .overlay(alignment: .topLeading) {
                            if !matchingClubs.isEmpty {
                                suggestionList(for: matchingClubs) { club in
                                    clubName = club.name
                                }
                                .offset(y: 44)
                            }
                        }
                        .zIndex(1)
                }
                .listRowBackground(Color.white)

                Section("Course & Tee · Required") {
                    TextField("Course name", text: $courseName)
                        .overlay(alignment: .topLeading) {
                            if !matchingCourses.isEmpty {
                                suggestionList(for: matchingCourses) { course in
                                    courseName = course.name
                                    if clubName.isEmpty {
                                        clubName = course.clubName
                                    }
                                }
                                .offset(y: 44)
                            }
                        }
                        .zIndex(1)
                    TextField("Tee", text: $teeName)
                    Picker("Holes", selection: $holes) {
                        Text("9").tag(9)
                        Text("18").tag(18)
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.white)

                Section("WHS Ratings · Required") {
                    Picker("Tee Rating Category", selection: $selectedRatingSex) {
                        ForEach(PlayerSex.allCases) { sex in
                            Text(sex == .male ? "Men" : "Women").tag(sex)
                        }
                    }
                    .pickerStyle(.segmented)

                    LabeledContent("Par") {
                        TextField("Par", value: $par, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 64)
                    }
                    .disabled(addHoleDetails)
                    .opacity(addHoleDetails ? 0.45 : 1)
                    LabeledContent("Course Rating") {
                        TextField("Course Rating", value: $courseRating, format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 72)
                    }
                    LabeledContent("Slope Rating") {
                        TextField("Slope Rating", value: $slopeRating, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 64)
                    }
                }
                .listRowBackground(Color.white)

                Section("Hole Details · Optional") {
                    Toggle("Add hole details", isOn: $addHoleDetails)
                }
                .listRowBackground(Color.white)

                if addHoleDetails {
                    Section("Hole Details") {
                        ForEach(0..<holes, id: \ .self) { index in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Hole \(index + 1)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ViewThatFits(in: .horizontal) {
                                    HStack {
                                        holeParStepper(at: index)
                                        Spacer()
                                        holeHandicapStepper(at: index)
                                    }
                                    VStack(alignment: .leading, spacing: 8) {
                                        holeParStepper(at: index)
                                        holeHandicapStepper(at: index)
                                    }
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.white)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.white)
            .navigationTitle("Add Custom Course")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveCourse() }
                        .disabled(!canSave)
                }
            }
            .onAppear {
                if !initialClubName.isEmpty {
                    clubName = initialClubName
                }
                if !initialCity.isEmpty {
                    city = initialCity
                }
                if !initialCourseName.isEmpty {
                    courseName = initialCourseName
                }
                country = initialCountry.isEmpty ? (profile?.countryOrDefault ?? "Sweden") : initialCountry
                if country.isEmpty || !availableCountries.contains(country) {
                    country = availableCountries.first ?? "Sweden"
                }
                selectedRatingSex = profile?.sexOrDefault ?? .male
                if sourceTee == nil {
                    resetHoleDetails()
                } else {
                    applySourceTeePrefillIfNeeded()
                }
            }
            .onChange(of: addHoleDetails) {
                if !isApplyingPrefill {
                    resetHoleDetails()
                }
            }
            .onChange(of: holes) {
                if !isApplyingPrefill {
                    resetHoleDetails()
                }
            }
            .onChange(of: holePars) {
                if addHoleDetails {
                    par = totalHolePar
                }
            }
            .alert("Invalid hole handicaps", isPresented: $showHoleHcpWarning) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Each hole must have a unique HCP from 1 to \(holes), and no value may be duplicated or outside that range.")
            }
            .alert("Course already exists", isPresented: $showDuplicateWarning) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("A \(selectedRatingSex.label.lowercased()) rating for this club, course, and tee already exists in this country.")
            }
        }
    }

    private func isDuplicate() -> Bool {
        let cleanClub = clubName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCourse = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTee = teeName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanClub.isEmpty, !cleanCourse.isEmpty, !cleanTee.isEmpty else { return false }

        let duplicatesCustomTee = tees.contains { tee in
            tee.clubName.localizedCaseInsensitiveCompare(cleanClub) == .orderedSame &&
            tee.courseName.localizedCaseInsensitiveCompare(cleanCourse) == .orderedSame &&
            tee.name.localizedCaseInsensitiveCompare(cleanTee) == .orderedSame &&
            (tee.ratingSex == nil || tee.ratingSex == selectedRatingSex) &&
            (clubs.first { $0.name.localizedCaseInsensitiveCompare(tee.clubName) == .orderedSame }?.country.localizedCaseInsensitiveCompare(country) == .orderedSame)
        }
        return duplicatesCustomTee || courseCatalog.containsRating(
            country: country,
            clubName: cleanClub,
            courseName: cleanCourse,
            teeName: cleanTee,
            sex: selectedRatingSex
        )
    }

    private func holeHandicapIndicesAreValid() -> Bool {
        let values = holeHandicapIndices.prefix(holes)
        let expected = Set(1...max(holes, 1))
        let actual = Set(values)
        return values.count == holes && actual == expected
    }

    @ViewBuilder
    private func holeParStepper(at index: Int) -> some View {
        if holePars.indices.contains(index) {
            Stepper(
                "Par \(holePars[index])",
                value: Binding(
                    get: { holePars[index] },
                    set: { updateHolePar(at: index, to: $0) }
                ),
                in: 3...8
            )
        }
    }

    @ViewBuilder
    private func holeHandicapStepper(at index: Int) -> some View {
        if holeHandicapIndices.indices.contains(index) {
            Stepper(
                "HCP \(holeHandicapIndices[index])",
                value: Binding(
                    get: { holeHandicapIndices[index] },
                    set: { holeHandicapIndices[index] = min(max($0, 1), 18) }
                ),
                in: 1...18
            )
        }
    }

    private var canSave: Bool {
        !country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !clubName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !teeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (27...80).contains(par) &&
        (25...90).contains(courseRating) &&
        (55...160).contains(slopeRating)
    }

    private func saveCourse() {
        if addHoleDetails && !holeHandicapIndicesAreValid() {
            showHoleHcpWarning = true
            return
        }

        if isDuplicate() {
            showDuplicateWarning = true
            return
        }

        let cleanClubName = clubName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCountry = country.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCourseName = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTeeName = teeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedHolePars: [Int]? = addHoleDetails ? Array(holePars.prefix(holes)) : nil
        let savedHoleHandicapIndices: [Int]? = addHoleDetails ? Array(holeHandicapIndices.prefix(holes)) : nil

        modelContext.insert(GolfClub(name: cleanClubName, city: cleanCity, country: cleanCountry, isCustom: true))
        modelContext.insert(GolfCourse(clubName: cleanClubName, name: cleanCourseName, isCustom: true))
        modelContext.insert(
            TeeSet(
                clubName: cleanClubName,
                courseName: cleanCourseName,
                name: cleanTeeName,
                holes: holes,
                par: par,
                courseRating: courseRating,
                slopeRating: slopeRating,
                ratingSexRawValue: selectedRatingSex.rawValue,
                isCustom: true,
                holeParsData: savedHolePars,
                holeHandicapIndicesData: savedHoleHandicapIndices
            )
        )
        dismiss()
    }
}

private struct InfoLabel: View {
    let title: String
    let explanation: String

    @State private var isShowingInfo = false

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            Button {
                isShowingInfo = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.caption)
                    .foregroundStyle(FairwayVectorColors.navy)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $isShowingInfo) {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "questionmark.circle")
                                    .font(.title2)
                                    .foregroundStyle(FairwayVectorColors.orange)
                                    .frame(width: 34)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(title)
                                        .font(.headline)
                                        .foregroundStyle(FairwayVectorColors.navy)
                                    Text(explanation)
                                        .font(.body)
                                        .foregroundStyle(FairwayVectorColors.charcoal)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding()
                    }
                    .background(FairwayVectorColors.background)
                    .navigationTitle("How It Works")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                isShowingInfo = false
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct HCPSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let courseCatalog: CourseCatalogStore
    var profile: PlayerProfile?
    var clubs: [GolfClub]
    var courses: [GolfCourse]
    var tees: [TeeSet]

    @State private var selectedCountry = "Sweden"
    @State private var selectedScoringMode = RoundInputMode.adjustedGrossScore
    @State private var selectedSex = PlayerSex.male
    #if DEBUG
    @State private var showTestDataImportConfirm = false
    @State private var testDataMessage: String?
    @State private var exportedTestDataURL: URL?
    #endif

    private var customTeesCount: Int {
        tees.filter { $0.isCustom ?? false }.count
    }

    private var availableCountries: [String] {
        let customCountries = clubs.map(\.country).filter { !$0.isEmpty }
        return Array(Set(courseCatalog.countries + customCountries)).sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Player") {
                    Picker("Tee Rating Category", selection: $selectedSex) {
                        ForEach(PlayerSex.allCases) { sex in
                            Text(sex == .male ? "Men" : "Women").tag(sex)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedSex) {
                        updateSex(to: selectedSex)
                    }
                }
                .listRowBackground(Color.white)

                Section("Round Defaults") {
                    Picker("Default Scoring Mode", selection: $selectedScoringMode) {
                        ForEach(RoundInputMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .background(Color.white)
                    .onChange(of: selectedScoringMode) {
                        updateScoringMode(to: selectedScoringMode)
                    }
                }
                .listRowBackground(Color.white)

                Section("Region") {
                    Picker("Country / Region", selection: $selectedCountry) {
                        ForEach(availableCountries, id: \.self) { country in
                            Text(country).tag(country)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .background(Color.white)
                    .onChange(of: selectedCountry) {
                        updateCountry(to: selectedCountry)
                    }
                }
                .listRowBackground(Color.white)

                Section("Course Data") {
                    NavigationLink {
                        CustomCoursesView(courseCatalog: courseCatalog, profile: profile, clubs: clubs, courses: courses, tees: tees)
                    } label: {
                        HStack {
                            Text("Custom Courses")
                            Spacer()
                            Text("\(customTeesCount)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listRowBackground(Color.white)

                Section {
                    Link("Privacy Policy", destination: URL(string: "https://fairwayvector.com/hcp-projection/privacy-policy")!)
                }

                #if DEBUG
                Section("Test Data") {
                    Button("Replace All Data With Test Data", role: .destructive) {
                        showTestDataImportConfirm = true
                    }
                    Button("Export Current Data") {
                        exportTestData()
                    }
                    if let exportedTestDataURL {
                        ShareLink(item: exportedTestDataURL) {
                            Text("Share Exported Snapshot")
                        }
                    }
                    if let testDataMessage {
                        Text(testDataMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Color.white)
                #endif
            }
            .scrollContentBackground(.hidden)
            .background(Color.white)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if let profile {
                    let savedCountry = profile.countryOrDefault
                    selectedCountry = availableCountries.contains(savedCountry)
                        ? savedCountry
                        : (availableCountries.first ?? "Sweden")
                    selectedScoringMode = profile.defaultInputMode
                    selectedSex = profile.sexOrDefault
                    if profile.countryOrDefault != selectedCountry {
                        profile.selectedCountry = selectedCountry
                    }
                }
            }
            .onChange(of: availableCountries) {
                guard !availableCountries.contains(selectedCountry),
                      let fallback = availableCountries.first else { return }
                selectedCountry = fallback
                updateCountry(to: fallback)
            }
            #if DEBUG
            .confirmationDialog(
                "Replace all data with the bundled test data?",
                isPresented: $showTestDataImportConfirm,
                titleVisibility: .visible
            ) {
                Button("Replace Everything", role: .destructive) { importTestData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Existing profile, custom courses and rounds on this device will be deleted.")
            }
            #endif
        }
    }

    #if DEBUG
    private func importTestData() {
        do {
            let snapshot = try TestDataStore.importBundledSnapshot(into: modelContext)
            testDataMessage = "Imported \"\(snapshot.name)\" · \(snapshot.rounds.count) rounds."
        } catch {
            testDataMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func exportTestData() {
        do {
            let stamp = ISO8601DateFormatter().string(from: .now)
            let data = try TestDataStore.exportSnapshotJSON(from: modelContext, name: "Device snapshot \(stamp)")
            let url = URL.temporaryDirectory.appending(path: "hcp-testdata.json")
            try data.write(to: url, options: .atomic)
            exportedTestDataURL = url
            testDataMessage = "Exported \(data.count) bytes."
        } catch {
            testDataMessage = "Export failed: \(error.localizedDescription)"
        }
    }
    #endif

    private func updateScoringMode(to newMode: RoundInputMode) {
        if let profile {
            profile.defaultInputMode = newMode
        } else {
            let newProfile = PlayerProfile(
                name: "Player",
                selectedCountry: selectedCountry,
                defaultInputModeRawValue: newMode.rawValue,
                sexRawValue: selectedSex.rawValue
            )
            modelContext.insert(newProfile)
        }
    }

    private func updateCountry(to newCountry: String) {
        if let profile {
            profile.selectedCountry = newCountry
        } else {
            let newProfile = PlayerProfile(
                name: "Player",
                selectedCountry: newCountry,
                defaultInputModeRawValue: selectedScoringMode.rawValue,
                sexRawValue: selectedSex.rawValue
            )
            modelContext.insert(newProfile)
        }
    }

    private func updateSex(to newSex: PlayerSex) {
        if let profile {
            profile.sexOrDefault = newSex
        } else {
            let newProfile = PlayerProfile(
                name: "Player",
                selectedCountry: selectedCountry,
                defaultInputModeRawValue: selectedScoringMode.rawValue,
                sexRawValue: newSex.rawValue
            )
            modelContext.insert(newProfile)
        }
    }
}

private struct RoundDetailView: View {
    var round: GolfRound
    var handicapIndex: Double?

    private var differential: Double? {
        WHSCalculator.scoringEntry(for: round, currentHandicapIndex: handicapIndex)?.scoreDifferential
    }

    private var courseHandicap: Int {
        WHSCalculator.courseHandicap(handicapIndex: handicapIndex ?? 0, tee: round.teeSnapshot)
    }

    private var isNoCourseRound: Bool {
        round.courseName.isEmpty && round.clubName.isEmpty
    }

    var body: some View {
        List {
            Section(isNoCourseRound ? "Round" : "Course & Tee") {
                if isNoCourseRound {
                    LabeledContent("Course", value: "No Course")
                } else {
                    LabeledContent("Course", value: round.courseName)
                    LabeledContent("Club", value: round.clubName)
                    LabeledContent("Tee", value: round.teeName)
                    LabeledContent("Holes", value: "\(round.holes)")
                }
                LabeledContent("Date", value: round.date.formatted(date: .abbreviated, time: .omitted))
            }
            .listRowBackground(FairwayVectorColors.surface)

            Section("Handicap Performance") {
                if let differential {
                    LabeledContent("HCP Score", value: WHSCalculator.formatHCPScore(differential))
                }
                if let handicapIndex {
                    LabeledContent("Playing Handicap Index", value: WHSCalculator.formatHCPScore(handicapIndex))
                }
                if !isNoCourseRound {
                    LabeledContent("Course Handicap", value: "\(courseHandicap)")
                }
                if round.pcc != 0 {
                    LabeledContent {
                        Text(round.pcc.formatted(.number.precision(.fractionLength(1))))
                    } label: {
                        InfoLabel(
                            title: "PCC Adjustment",
                            explanation: "Playing Conditions Calculation. This adjusts the score differential when the course is playing noticeably easier or harder than normal because of weather, setup, or course conditions."
                        )
                    }
                }
            }
            .listRowBackground(FairwayVectorColors.surface)

            if !isNoCourseRound {
                Section("Score Summary") {
                LabeledContent("Input Mode", value: round.inputMode.title)
                if let gross = round.adjustedGrossScore {
                    LabeledContent {
                        Text("\(gross)")
                            .monospacedDigit()
                    } label: {
                        InfoLabel(
                            title: "Adjusted Gross Score",
                            explanation: "Adjusted Gross Score is the adjusted total for handicap purposes. It reflects your actual score after WHS limits are applied to unusually high hole scores, so it is the number used in handicap calculation."
                        )
                    }
                }
                if let points = round.stablefordPoints {
                    LabeledContent("Stableford Points", value: "\(points) pts")
                }
                LabeledContent("Par / Course Rating / Slope", value: "\(round.par) / \(round.courseRating.formatted(.number.precision(.fractionLength(1)))) / \(round.slopeRating)")
                if !round.notes.isEmpty {
                    LabeledContent("Notes", value: round.notes)
                }
                }
                .listRowBackground(FairwayVectorColors.surface)
            } else if !round.notes.isEmpty {
                Section("Notes") {
                    Text(round.notes)
                }
                .listRowBackground(FairwayVectorColors.surface)
            }

            if let holeScores = round.holeScores, !holeScores.isEmpty {
                let pars = round.holePars ?? TeeSet.defaultPars(for: round.holes, totalPar: round.par)
                let indices = round.holeHandicapIndices ?? Array(1...max(round.holes, 1))
                let safeHoleCount = min(holeScores.count, min(pars.count, indices.count))
                let calc = WHSCalculator.calculateHoleByHole(
                    holeScores: holeScores,
                    holePars: pars,
                    holeHandicapIndices: indices,
                    courseHandicap: courseHandicap
                )

                Section("Hole by Hole Breakdown") {
                    ForEach(0..<safeHoleCount, id: \.self) { i in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Hole \(i + 1)")
                                    .font(.headline)
                                Text("Par \(pars[i]) · Index \(indices[i])")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if i < calc.holePoints.count {
                                Text("\(calc.holePoints[i]) pts")
                                    .font(.caption.bold().monospacedDigit())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(FairwayVectorColors.orange.opacity(0.15))
                                    .foregroundStyle(FairwayVectorColors.orange)
                                    .clipShape(Capsule())
                            }
                            Text("\(holeScores[i]) strokes")
                                .font(.headline.monospacedDigit())
                        }
                    }
                }
                .listRowBackground(FairwayVectorColors.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(FairwayVectorColors.background)
        .navigationTitle(isNoCourseRound ? "No Course Round" : round.courseName)
    }
}

private struct MetricCard: View {
    var title: String
    var value: String
    var systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(FairwayVectorColors.orange)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title.bold().monospacedDigit())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(FairwayVectorColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

private struct RoundRow: View {
    var round: GolfRound
    var isCountingRound: Bool = false

    private var differential: Double? {
        WHSCalculator.scoringEntry(for: round)?.scoreDifferential
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(round.courseName.isEmpty ? "No Course" : round.courseName)
                            .font(.headline)
                        if isCountingRound {
                            Text("Counts for HCP")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(FairwayVectorColors.orange.opacity(0.18))
                                .foregroundStyle(FairwayVectorColors.orange)
                                .clipShape(Capsule())
                        }
                    }
                    if !round.clubName.isEmpty || !round.teeName.isEmpty {
                        Text([round.clubName, round.teeName].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if let differential {
                        Text(WHSCalculator.formatHCPScore(differential))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(isCountingRound ? FairwayVectorColors.orange : Color.primary)
                    }
                    Text(round.date, format: .dateTime.year().month().day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let differential {
                if round.handicapDifferential == nil {
                    Text("HCP score: \(WHSCalculator.formatHCPScore(differential)) · \(round.scoreSummaryText)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(round.scoreSummaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct TargetResultRow: View {
    var result: TargetResult

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(primaryText)
                        .font(.headline)
                    if result.change == 0 {
                        Text("No impact")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(FairwayVectorColors.slate.opacity(0.18))
                            .foregroundStyle(FairwayVectorColors.slate)
                            .clipShape(Capsule())
                    }
                }
                Text("HCP score: \(WHSCalculator.formatHCPScore(result.scoreDifferential))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(WHSCalculator.formatHCPScore(result.projectedHandicapIndex))
                    .font(.headline.monospacedDigit())
                Text(changeText)
                    .font(.caption)
                    .foregroundStyle(changeColor)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var primaryText: String {
        switch result.inputMode {
        case .adjustedGrossScore, .holeByHole:
            "Score \(result.value)"
        case .stablefordPoints:
            "\(result.value) points"
        }
    }

    private var changeText: String {
        if result.change == 0 {
            return "±0.0 (Score not used)"
        }
        let prefix = result.change > 0 ? "+" : ""
        return "\(prefix)\(result.change.formatted(.number.precision(.fractionLength(1))))"
    }

    private var changeColor: Color {
        if result.change < 0 {
            return FairwayVectorColors.navy
        } else if result.change > 0 {
            return FairwayVectorColors.orange
        } else {
            return FairwayVectorColors.slate
        }
    }
}

private extension TeeSet {
    var displayName: String {
        "\(clubName) · \(courseName) · \(name)"
    }

    var snapshot: TeeSnapshot {
        TeeSnapshot(
            clubName: clubName,
            courseName: courseName,
            teeName: name,
            holes: holes,
            par: par,
            courseRating: courseRating,
            slopeRating: slopeRating
        )
    }
}

// FairwayVectorColors is a shared app-level type (see FairwayVectorColors.swift).
