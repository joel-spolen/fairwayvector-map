import SwiftData
import SwiftUI

struct ContentView: View {
    private enum Tab: Hashable {
        case home
        case course
        case handicap
        case practice
        case profile
    }

    @AppStorage("map.hasSeenSplash") private var hasSeenSplash = false
    @AppStorage("distanceUnit") private var distanceUnit: DistanceUnit = .meters
    @AppStorage("wedgeMatrix.distanceUnit") private var wedgeDistanceUnit = WedgeDistanceUnit.yards.rawValue
    @State private var isShowingSplash = true
    @State private var selectedTab: Tab = .home
    @State private var practiceDestination: PracticeDestination = .trajectory
    @StateObject private var trajectoryModel = TrajectoryCalculatorViewModel()

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                HomeView(
                    onOpenCourseMap: { selectedTab = .course },
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

                CourseMapTabView()
                    .tabItem { Label("Course", systemImage: "map") }
                    .tag(Tab.course)

                HCPProjectionEntryView()
                    .tabItem { Label("Handicap", systemImage: "chart.line.uptrend.xyaxis") }
                    .tag(Tab.handicap)

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
            .tint(FairwayVectorColors.navy)

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
        .modelContainer(HCPProjectionEntryView.sharedModelContainer)
        .onChange(of: distanceUnit, initial: true) { _, unit in
            wedgeDistanceUnit = unit == .meters ? WedgeDistanceUnit.meters.rawValue : WedgeDistanceUnit.yards.rawValue
            trajectoryModel.unitPreferences.globalDefault = unit == .meters ? .metric : .imperial
        }
    }
}

private struct CourseMapTabView: View {
    @State private var selection: CourseReference?

    var body: some View {
        if let selection {
            CourseMapView(reference: selection) {
                self.selection = nil
            }
        } else {
            CourseSelectionView { selection = $0 }
        }
    }
}

private struct HomeView: View {
    let onOpenCourseMap: () -> Void
    let onOpenHandicap: () -> Void
    let onOpenWedge: () -> Void
    let onOpenTrajectory: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    brandHeader

                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(FairwayVectorColors.orange)
                                .frame(width: 48, height: 48)
                                .background(FairwayVectorColors.conditionsSurface, in: RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("SWEDEN COURSE CATALOG")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(FairwayVectorColors.slate)
                                Text("394 golf clubs")
                                    .font(.headline)
                                    .foregroundStyle(FairwayVectorColors.navy)
                                Text("Select a club, course, and tee")
                                    .font(.subheadline)
                                    .foregroundStyle(FairwayVectorColors.slate)
                            }
                        }

                        Button(action: onOpenCourseMap) {
                            Label("Choose Club & Course", systemImage: "map.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(FairwayVectorColors.navy)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FairwayVectorColors.surface, in: RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(FairwayVectorColors.orange)
                                .frame(width: 48, height: 48)
                                .background(FairwayVectorColors.conditionsSurface, in: RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("HANDICAP")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(FairwayVectorColors.slate)
                                Text("HCP Projection")
                                    .font(.headline)
                                    .foregroundStyle(FairwayVectorColors.navy)
                                Text("Log rounds and see how a score would change your index")
                                    .font(.subheadline)
                                    .foregroundStyle(FairwayVectorColors.slate)
                            }
                        }

                        Button {
                            onOpenHandicap()
                        } label: {
                            Label("View Handicap", systemImage: "chart.line.uptrend.xyaxis")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(FairwayVectorColors.navy)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FairwayVectorColors.surface, in: RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "target")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(FairwayVectorColors.flightBlue)
                                .frame(width: 48, height: 48)
                                .background(FairwayVectorColors.conditionsSurface, in: RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("WEDGE PLAY")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(FairwayVectorColors.slate)
                                Text("Wedge Matrix")
                                    .font(.headline)
                                    .foregroundStyle(FairwayVectorColors.navy)
                                Text("Club recommendations for partial wedge shots")
                                    .font(.subheadline)
                                    .foregroundStyle(FairwayVectorColors.slate)
                            }
                        }

                        Button {
                            onOpenWedge()
                        } label: {
                            Label("Explore Wedge Matrix", systemImage: "target")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(FairwayVectorColors.navy)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FairwayVectorColors.surface, in: RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "chart.xyaxis.line")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(FairwayVectorColors.flightBlue)
                                .frame(width: 48, height: 48)
                                .background(FairwayVectorColors.conditionsSurface, in: RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("SHOT TRAJECTORY")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(FairwayVectorColors.slate)
                                Text("Trajectory")
                                    .font(.headline)
                                    .foregroundStyle(FairwayVectorColors.navy)
                                Text("Simulate ball flight and get club recommendations")
                                    .font(.subheadline)
                                    .foregroundStyle(FairwayVectorColors.slate)
                            }
                        }

                        Button {
                            onOpenTrajectory()
                        } label: {
                            Label("Explore Trajectory", systemImage: "chart.xyaxis.line")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(FairwayVectorColors.navy)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FairwayVectorColors.surface, in: RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 14) {
                        Text("On the course")
                            .font(.headline)
                            .foregroundStyle(FairwayVectorColors.charcoal)

                        featureRow(
                            symbol: "location.fill",
                            title: "Know where you are",
                            detail: "See your live position on each hole."
                        )
                        featureRow(
                            symbol: "scope",
                            title: "Choose a target",
                            detail: "Tap the map for distance to any point."
                        )
                        featureRow(
                            symbol: "flag.fill",
                            title: "Set the pin",
                            detail: "Double-tap the green to move the flag."
                        )
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FairwayVectorColors.surface, in: RoundedRectangle(cornerRadius: 12))

                    Text("Allow location access while using the app for live GPS distances. Course data is cached for offline use after it loads.")
                        .font(.footnote)
                        .foregroundStyle(FairwayVectorColors.slate)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
            }
            .background(FairwayVectorColors.background)
            .toolbar(.hidden, for: .navigationBar)
        }
        .accessibilityIdentifier("map-home-screen")
    }

    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                FairwayVectorMark()
                    .frame(width: 58, height: 58)
                VStack(alignment: .leading, spacing: 1) {
                    Text("FAIRWAYVECTOR")
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(FairwayVectorColors.slate)
                    Text("Your golf companion")
                        .font(.title.bold())
                        .foregroundStyle(FairwayVectorColors.navy)
                }
            }
            Text("Your course, handicap, and practice in one place.")
                .font(.title3.weight(.medium))
                .foregroundStyle(FairwayVectorColors.charcoal)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private func featureRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FairwayVectorColors.navy)
                .frame(width: 28, height: 28)
                .background(FairwayVectorColors.conditionsSurface, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FairwayVectorColors.charcoal)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(FairwayVectorColors.slate)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ContentView()
}
