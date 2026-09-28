import SwiftUI

struct ContentView: View {
    @State private var store = CourseStore(reference: .hills)
    @State private var locationManager = LocationManager()
    @State private var holeIndex = 0
    @State private var tapPoint: GeoPoint?
    @State private var showSettings = false
    @AppStorage("distanceUnit") private var unit: DistanceUnit = .meters

    var body: some View {
        NavigationStack {
            content
                .background(FairwayVectorColors.background)
                .navigationTitle(store.reference.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Settings", systemImage: "gearshape") { showSettings = true }
                            .labelStyle(.iconOnly)
                            .accessibilityLabel("Settings")
                    }
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView(store: store)
                }
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
            ZStack(alignment: .bottom) {
                HoleMapView(hole: hole, origin: origin?.point, tapPoint: $tapPoint)
                    .ignoresSafeArea(edges: .bottom)

                VStack(spacing: 12) {
                    if locationManager.isDenied {
                        locationDeniedBanner
                    }
                    DistanceCard(hole: hole, origin: origin, tapPoint: tapPoint, unit: unit) {
                        tapPoint = nil
                    }
                    holeSelector(hole: hole, count: holes.count)
                }
                .padding()
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

    private func holeSelector(hole: Hole, count: Int) -> some View {
        HStack {
            Button("Previous hole", systemImage: "chevron.left") { holeIndex -= 1 }
                .labelStyle(.iconOnly)
                .disabled(holeIndex == 0)
            Spacer()
            VStack(spacing: 2) {
                Text("Hole \(hole.number)")
                    .font(.headline)
                    .foregroundStyle(FairwayVectorColors.navy)
                if let par = hole.par {
                    Text("Par \(par)")
                        .font(.caption)
                        .foregroundStyle(FairwayVectorColors.slate)
                }
            }
            Spacer()
            Button("Next hole", systemImage: "chevron.right") { holeIndex += 1 }
                .labelStyle(.iconOnly)
                .disabled(holeIndex >= count - 1)
        }
        .font(.title3.weight(.semibold))
        .buttonStyle(.bordered)
        .padding(12)
        .background(FairwayVectorColors.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private var locationDeniedBanner: some View {
        HStack {
            Label("Location is off. Distances are from the tee.", systemImage: "location.slash")
                .font(.footnote)
                .foregroundStyle(FairwayVectorColors.charcoal)
            Spacer()
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Settings", destination: url)
                    .font(.footnote.bold())
            }
        }
        .padding(12)
        .background(FairwayVectorColors.conditionsSurface, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ContentView()
}
