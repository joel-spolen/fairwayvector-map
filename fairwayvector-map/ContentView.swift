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

                HStack(alignment: .center, spacing: 0) {
                    VStack(spacing: 10) {
                        holeInfoCard(hole: hole, origin: origin)
                        Spacer(minLength: 0)
                        holeNavigationButton(isPrevious: true, count: holes.count)
                    }
                    Spacer(minLength: 0)
                    VStack(spacing: 10) {
                        DistanceCard(hole: hole, origin: origin, tapPoint: tapPoint, unit: unit) {
                            tapPoint = nil
                        }
                        Spacer(minLength: 0)
                        holeNavigationButton(isPrevious: false, count: holes.count)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
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

    private func holeInfoCard(hole: Hole, origin: DistanceOrigin?) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("HOLE")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(FairwayVectorColors.slate)
            Text("\(hole.number)")
                .font(.largeTitle.bold().monospacedDigit())
                .foregroundStyle(FairwayVectorColors.navy)
            if let par = hole.par {
                Text("Par \(par)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FairwayVectorColors.charcoal)
            }
            if case .gps(let accuracy) = origin?.source {
                Text("±\(unit.format(accuracy))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(FairwayVectorColors.slate)
            }
        }
        .padding(10)
        .frame(width: 78, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(FairwayVectorColors.surface.opacity(0.75), lineWidth: 1)
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
