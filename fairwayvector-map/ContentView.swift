import SwiftUI

struct ContentView: View {
    @State private var store = CourseStore(reference: .hills)
    @State private var locationManager = LocationManager()
    @State private var holeIndex = 0
    @State private var tapPoint: GeoPoint?
    @AppStorage("distanceUnit") private var unit: DistanceUnit = .meters

    var body: some View {
        NavigationStack {
            content
                .background(FairwayVectorColors.background)
                .navigationTitle(store.reference.name)
                .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            locationManager.start()
            await store.load()
        }
        .onChange(of: holeIndex) { tapPoint = nil }
    }

    @ViewBuilder
    private var content: some View {
        if let holes = store.course?.holes, !holes.isEmpty {
            let hole = holes[min(holeIndex, holes.count - 1)]
            let origin = DistanceOrigin.resolve(location: locationManager.location, hole: hole)
            ZStack {
                HoleMapView(
                    hole: hole,
                    origin: origin?.point,
                    usesGPS: origin?.usesGPS == true,
                    tapPoint: $tapPoint
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    topDistanceMenu(hole: hole, origin: origin)
                    Spacer(minLength: 0)
                    bottomHoleMenu(hole: hole, holeCount: holes.count)
                }
                VStack {
                    Spacer(minLength: 0)
                    HStack {
                        Text("© OpenStreetMap contributors")
                            .font(.system(size: 7))
                            .foregroundStyle(.white.opacity(0.85))
                        Spacer()
                    }
                    .padding(.leading, 8)
                    .padding(.bottom, 66)
                }
            }
        } else if store.isLoading || store.errorMessage == nil {
            ProgressView("Loading course…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView {
                Label("Course unavailable", systemImage: "map")
            } description: {
                Text(store.errorMessage ?? "")
            } actions: {
                Button("Try again") { Task { await store.refresh() } }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func bottomHoleMenu(hole: Hole, holeCount: Int) -> some View {
        HStack(alignment: .center, spacing: 10) {
            holeNavigationButton(isPrevious: true, count: holeCount)
            holeSummary(hole)
                .frame(maxWidth: .infinity)
            holeNavigationButton(isPrevious: false, count: holeCount)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity)
        .background {
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func topDistanceMenu(hole: Hole, origin: DistanceOrigin?) -> some View {
        VStack(spacing: 4) {
            DistanceCard(hole: hole, origin: origin, unit: unit)
            HStack(spacing: 12) {
                distanceSummary("POINT", pointDistanceText(origin: origin), color: FairwayVectorColors.orange)
                Spacer(minLength: 0)
                distanceSummary("TO FLAG", flagDistanceText(hole: hole, origin: origin), color: FairwayVectorColors.flightBlue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 0)
        .padding(.bottom, 5)
        .frame(height: 68, alignment: .bottom)
        .frame(maxWidth: .infinity)
        .background {
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea(edges: .top)
        }
    }

    private func distanceSummary(_ title: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(FairwayVectorColors.slate)
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func pointDistanceText(origin: DistanceOrigin?) -> String {
        guard let tapPoint, let origin else { return unit.format(0) }
        return unit.format(GolfGeometry.distance(origin.point, tapPoint))
    }

    private func flagDistanceText(hole: Hole, origin: DistanceOrigin?) -> String {
        guard let origin, let flag = hole.flag else { return "–" }
        return unit.format(GolfGeometry.distance(tapPoint ?? origin.point, flag))
    }

    private func holeSummary(_ hole: Hole) -> some View {
        VStack(spacing: 5) {
            Text("HOLE \(hole.number)")
                .font(.headline.bold().monospacedDigit())
                .foregroundStyle(FairwayVectorColors.navy)
                .frame(maxWidth: .infinity, alignment: .center)
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                summaryValue("PAR", hole.par.map(String.init) ?? "–")
                summaryValue("HCP", hole.handicapIndex.map(String.init) ?? "–")
                summaryValue("LENGTH", hole.length > 0 ? unit.format(hole.length) : "–")
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .multilineTextAlignment(.center)
    }

    private func summaryValue(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(FairwayVectorColors.slate)
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(FairwayVectorColors.charcoal)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func holeNavigationButton(isPrevious: Bool, count: Int) -> some View {
        let unavailable = isPrevious ? holeIndex == 0 : holeIndex >= count - 1
        return Button {
            holeIndex += isPrevious ? -1 : 1
        } label: {
            Image(systemName: isPrevious ? "chevron.left" : "chevron.right")
                .font(.headline.weight(.bold))
                .frame(width: 42, height: 42)
        }
        .buttonStyle(.borderedProminent)
        .tint(FairwayVectorColors.navy)
        .disabled(unavailable)
        .accessibilityLabel(isPrevious ? "Previous hole" : "Next hole")
    }
}

#Preview {
    ContentView()
}
