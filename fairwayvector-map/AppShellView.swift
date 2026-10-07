import SwiftData
import SwiftUI

struct ContentView: View {
    private enum Tab: Hashable {
        case home
        case course
        case handicap
        case practice
        case profile
        case statistics
    }

    @AppStorage("map.hasSeenSplash") private var hasSeenSplash = false
    @AppStorage("distanceUnit") private var distanceUnit: DistanceUnit = .meters
    @AppStorage("wedgeMatrix.distanceUnit") private var wedgeDistanceUnit = WedgeDistanceUnit.yards.rawValue
    @State private var isShowingSplash = true
    @State private var selectedTab: Tab = .home
    @State private var practiceDestination: PracticeDestination = .trajectory
    @StateObject private var trajectoryModel = TrajectoryCalculatorViewModel()
    @State private var roundStore = PlayedRoundStore()
    @State private var requestStartRound = false

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                PureLineHomeView(
                    onOpenCourseMap: { selectedTab = .course },
                    onStartRound: { requestStartRound = true; selectedTab = .course },
                    onOpenHandicap: { selectedTab = .handicap },
                    onOpenWedge: {
                        practiceDestination = .wedge
                        selectedTab = .practice
                    },
                    onOpenTrajectory: {
                        practiceDestination = .trajectory
                        selectedTab = .practice
                    }
                )
                .tabItem { Label("Home", systemImage: "house") }
                .tag(Tab.home)

                CourseMapTabView(requestStartRound: $requestStartRound)
                    .tabItem { Label("Course", systemImage: "map") }
                    .tag(Tab.course)

                HCPProjectionEntryView()
                    .tabItem { Label("Handicap", systemImage: "chart.line.uptrend.xyaxis") }
                    .tag(Tab.handicap)

                RoundStatisticsView()
                    .tabItem { Label("Statistics", systemImage: "chart.xyaxis.line") }
                    .tag(Tab.statistics)

                PracticeView(destination: $practiceDestination, trajectoryModel: trajectoryModel)
                    .tabItem { Label("Practice", systemImage: "target") }
                    .tag(Tab.practice)

                UnifiedProfileView(trajectoryModel: trajectoryModel, onOpenWedge: {
                    practiceDestination = .wedge
                    selectedTab = .practice
                })
                    .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                    .tag(Tab.profile)
            }
            .tint(selectedTab == .home || selectedTab == .course || selectedTab == .handicap ? PureLineStyle.accent : FairwayVectorColors.navy)

            if isShowingSplash {
                SplashView(isReturningUser: hasSeenSplash) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isShowingSplash = false
                        hasSeenSplash = true
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .environment(\.colorScheme, .light)
        .overlay { SharedHandicapSync(trajectoryModel: trajectoryModel).allowsHitTesting(false) }
        .environmentObject(trajectoryModel)
        .environment(roundStore)
        .modelContainer(HCPProjectionEntryView.sharedModelContainer)
        .onChange(of: distanceUnit, initial: true) { _, unit in
            wedgeDistanceUnit = unit == .meters ? WedgeDistanceUnit.meters.rawValue : WedgeDistanceUnit.yards.rawValue
            trajectoryModel.unitPreferences.globalDefault = unit == .meters ? .metric : .imperial
        }
    }
}

private struct CourseMapTabView: View {
    @State private var selection: CourseReference?
    @State private var resumedRound: PlayedRound?
    @Binding var requestStartRound: Bool
    @Environment(PlayedRoundStore.self) private var roundStore

    var body: some View {
        if let selection {
            CourseMapView(reference: selection, requestStartRound: $requestStartRound, resumedRound: resumedRound) {
                self.selection = nil
                resumedRound = nil
            }
        } else {
            CourseSelectionView(onStartRound: { reference in
                requestStartRound = true; selection = reference
            }, onResumeRound: { round in
                requestStartRound = false; resumedRound = round; selection = round.reference
            }, onStartCourse: { selection = $0 })
        }
    }
}

#Preview {
    ContentView()
}
