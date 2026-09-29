import SwiftUI

struct ContentView: View {
    private enum Tab: Hashable {
        case home
        case course
    }

    @AppStorage("map.hasSeenSplash") private var hasSeenSplash = false
    @State private var isShowingSplash = true
    @State private var selectedTab: Tab = .home

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                HomeView {
                    selectedTab = .course
                }
                .tabItem { Label("Home", systemImage: "house") }
                .tag(Tab.home)

                CourseMapTabView()
                    .tabItem { Label("Course Map", systemImage: "map") }
                    .tag(Tab.course)
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
    }
}

private struct CourseMapTabView: View {
    @State private var selection: SelectedCourse?

    var body: some View {
        if let selection {
            CourseMapView(reference: selection.reference) {
                self.selection = nil
            }
        } else {
            CourseSelectionView { selection = $0 }
        }
    }
}

private struct HomeView: View {
    let onOpenCourseMap: () -> Void

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
                    Text("Course Map")
                        .font(.title.bold())
                        .foregroundStyle(FairwayVectorColors.navy)
                }
            }
            Text("See the hole. Pick your target. Know the distance.")
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
