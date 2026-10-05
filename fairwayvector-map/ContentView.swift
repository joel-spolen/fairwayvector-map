import SwiftUI

struct CourseMapView: View {
    let reference: CourseReference
    let onChangeCourse: () -> Void
    @EnvironmentObject private var trajectoryModel: TrajectoryCalculatorViewModel

    @State private var store: CourseStore
    @State private var weatherStore = CourseWeatherStore()
    @State private var terrainStore = TerrainElevationStore()
    @State private var isShowingTerrainProfile = false
    @State private var isConfirmingTerrainRetry = false
    @State private var terrainInspectionPoint: GeoPoint?
    @State private var mapHeading = 0.0
    @State private var locationManager = LocationManager()
    @State private var holeIndex = 0
    @State private var tapPoint: GeoPoint?
    @State private var isShowingFlagEditor = false
    @AppStorage("distanceUnit") private var unit: DistanceUnit = .meters
    @AppStorage("customFlagPositions") private var customFlagPositions = ""

    init(reference: CourseReference, onChangeCourse: @escaping () -> Void = {}) {
        self.reference = reference
        self.onChangeCourse = onChangeCourse
        _store = State(initialValue: CourseStore(reference: reference))
    }

    var body: some View {
        NavigationStack {
            content
                .background(FairwayVectorColors.background)
                .navigationTitle(store.reference.courseName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .tabBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(store.reference.golfAPICourseID == nil ? "Refresh course" : "Check for course updates", systemImage: "arrow.clockwise") {
                            Task { await store.refresh() }
                        }
                        .labelStyle(.iconOnly)
                        .disabled(store.isLoading)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Change course", systemImage: "arrow.left.arrow.right", action: onChangeCourse)
                            .labelStyle(.iconOnly)
                            .accessibilityLabel("Change course, club, or tee")
                    }
                }
        }
        .task {
            locationManager.start()
            await store.load()
        }
        .onChange(of: holeIndex) { tapPoint = nil; terrainStore.invalidateShot() }
        .onDisappear { terrainStore.deactivate() }
        .sheet(isPresented: $isShowingTerrainProfile, onDismiss: { terrainInspectionPoint = nil }) {
            if let holes = store.course?.holes, !holes.isEmpty {
                let hole = holes[min(holeIndex, holes.count - 1)]
                HoleElevationProfileView(
                    store: terrainStore, holeNumber: hole.number, unit: unit,
                    usesGPS: terrainStore.usesGPS,
                    inspectionPoint: $terrainInspectionPoint
                )
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
        }
        .sheet(isPresented: $isShowingFlagEditor) {
            if let holes = store.course?.holes, !holes.isEmpty {
                let hole = holes[min(holeIndex, holes.count - 1)]
                if let flag = flagPosition(for: hole) {
                    FlagPlacementView(hole: hole, initialFlag: flag) { movedFlag in
                        saveFlagPosition(movedFlag, for: hole)
                        isShowingFlagEditor = false
                    }
                    .presentationDetents([.medium, .large])
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let holes = store.course?.holes, !holes.isEmpty {
            let hole = holes[min(holeIndex, holes.count - 1)]
            let origin = DistanceOrigin.resolve(location: locationManager.location, hole: hole)
            let holeRequest = terrainRequest(for: hole, origin: nil, target: nil)
            ZStack {
                HoleMapView(
                    hole: hole,
                    flag: flagPosition(for: hole),
                    origin: origin?.point,
                    usesGPS: origin?.usesGPS == true,
                    tapPoint: $tapPoint,
                    onDoubleTapGreen: { isShowingFlagEditor = true },
                    onHeadingChange: { mapHeading = $0 },
                    terrainInspectionPoint: terrainInspectionPoint,
                    onTargetInteractionBegan: { terrainStore.beginTargetInteraction() },
                    onTargetCommitted: { point in
                        terrainInspectionPoint = nil
                        terrainStore.commitShot(terrainRequest(for: hole,
                            origin: DistanceOrigin.resolve(location: locationManager.location, hole: hole), target: point))
                    }
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    topDistanceMenu(hole: hole, origin: origin, flag: flagPosition(for: hole))
                    if DevelopmentAPIConfiguration.isDemoCourse(store.reference.golfAPICourseID ?? "") {
                        Text("DEMO HILLS · invented GPS layout & ratings · not for play")
                            .font(.caption2.bold()).padding(6)
                            .frame(maxWidth: .infinity)
                            .background(FairwayVectorColors.conditionsSurface)
                    } else if DevelopmentAPIConfiguration.current.golfAPI == .mock {
                            Text(store.reference.golfAPICourseID == BundledSavedCourseStore.hillsCourseID
                                ? "Saved Hills offline · APIs paused" : "Saved course · APIs paused")
                            .font(.caption2.bold()).padding(6)
                            .frame(maxWidth: .infinity)
                            .background(FairwayVectorColors.conditionsSurface)
                    }
                    if let location = courseWeatherLocation {
                        CourseWeatherCard(location: location, store: weatherStore)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 4)
                    }
                    if hole.usesPointOnlyGeometry {
                        Label("GPS tee and green points are available; detailed fairway and green outlines are not.", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(FairwayVectorColors.navy)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(FairwayVectorColors.surface.opacity(0.95))
                            .padding(.horizontal, 12)
                    }
                    if store.errorMessage != nil {
                        HStack(spacing: 10) {
                            Label("Showing saved map · update unavailable", systemImage: "wifi.slash")
                                .font(.caption)
                                .lineLimit(2)
                            Spacer(minLength: 0)
                            Button("Retry") { Task { await store.refresh() } }
                                .font(.caption.weight(.semibold))
                        }
                        .padding(10)
                        .background(FairwayVectorColors.surface, in: RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 12)
                    }
                    if let weather = weatherStore.weather, courseWeatherLocation != nil {
                        HStack {
                            Spacer(minLength: 0)
                            CourseWindIndicator(weather: weather, mapHeading: mapHeading)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                    }
                    Spacer(minLength: 0)
                    CourseShotRecommendationView(terrainStore: terrainStore, weatherStore: weatherStore,
                        weatherLocation: courseWeatherLocation, selectedTarget: tapPoint,
                        unit: unit, model: trajectoryModel)
                    terrainPanel(hole: hole)
                    bottomHoleMenu(hole: hole, holeCount: holes.count)
                }
                VStack {
                    Spacer(minLength: 0)
                    HStack {
                            Text(DevelopmentAPIConfiguration.isDemoCourse(store.reference.golfAPICourseID ?? "")
                             ? "Demo course data · Imagery © Apple Maps · Weather © Open-Meteo (live)"
                                : "Saved course data © \(store.reference.golfAPICourseID == nil ? "OpenStreetMap contributors" : "Golf API") · Imagery © Apple Maps · Weather © Open-Meteo")
                            .font(.system(size: 7))
                            .foregroundStyle(.white.opacity(0.85))
                        Spacer()
                    }
                    .padding(.leading, 8)
                    .padding(.bottom, 66)
                }
            }
            .task(id: holeRequest) {
                // Opening geometry/tee/hole/saved flag reads terrain cache ONLY.
                tapPoint = nil
                terrainInspectionPoint = nil
                terrainStore.open(terrainRequest(for: hole,
                    origin: DistanceOrigin.resolve(location: locationManager.location, hole: hole), target: nil))
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

    private var courseWeatherLocation: GeoPoint? {
        if let location = store.reference.location { return location }
        var points: [GeoPoint] = []
        for hole in store.course?.holes ?? [] {
            points.append(contentsOf: hole.path)
            points.append(contentsOf: hole.green)
            for polygon in hole.fairways { points.append(contentsOf: polygon) }
            for polygon in hole.roughs { points.append(contentsOf: polygon) }
            for polygon in hole.tees { points.append(contentsOf: polygon) }
        }
        guard !points.isEmpty else { return nil }
        let count = Double(points.count)
        let latitudeTotal = points.reduce(0.0) { total, point in total + point.lat }
        let longitudeTotal = points.reduce(0.0) { total, point in total + point.lon }
        return GeoPoint(
            lat: latitudeTotal / count,
            lon: longitudeTotal / count
        )
    }

    private func terrainRequest(for hole: Hole, origin: DistanceOrigin?, target: GeoPoint?) -> TerrainRequest {
        let flag = flagPosition(for: hole)
        var path = hole.path
        if let flag {
            if path.count >= 2 { path[path.count - 1] = flag }
            else if let tee = hole.tee { path = [tee, flag] }
        }
        return TerrainRequest(
            courseID: store.terrainCourseID ?? "",
            holeNumber: hole.number, path: path, flag: flag,
            origin: origin?.point, target: target ?? flag,
            usesPointOnlyGeometry: hole.usesPointOnlyGeometry || path.count <= 2,
            usesGPS: origin?.usesGPS == true
        )
    }

    private func terrainPanel(hole: Hole) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                Image(systemName: "mountain.2.fill")
                    .foregroundStyle(FairwayVectorColors.orange)
                Picker("Terrain profile", selection: $terrainStore.mode) {
                    ForEach(TerrainProfileMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                if terrainStore.isLoading { ProgressView().controlSize(.small) }
                Button("Refresh terrain", systemImage: "arrow.clockwise") {
                    terrainInspectionPoint = nil
                    isConfirmingTerrainRetry = true
                }
                .labelStyle(.iconOnly)
                .disabled(terrainStore.isHoleLoading || terrainStore.isShotLoading)
                .accessibilityHint("Asks before retrying failed terrain requests. Existing call reservations are retained.")
                Button("Expand terrain profile", systemImage: "arrow.up.left.and.arrow.down.right") { isShowingTerrainProfile = true }
                    .labelStyle(.iconOnly)
            }
            if let profile = terrainStore.selectedProfile, profile.samples.contains(where: { $0.elevationMeters != nil }) {
                TerrainProfileChart(profile: profile, unit: unit, selectedDistance: .constant(nil), height: 74)
                Text("\(terrainStore.mode == .hole ? "Tee → flag" : terrainStore.usesGPS ? "Committed GPS → target" : "Tee fallback → target") · \(profile.elevationChangeMeters.map(terrainDeltaText) ?? "Partial coverage")")
                    .font(.caption2)
                if terrainStore.mode == .shot, let next = terrainStore.snapshot.targetToFlagElevationChangeMeters {
                    Text("Target → flag: \(terrainDeltaText(next))").font(.caption2)
                }
            } else if terrainStore.isLoading {
                Text("Loading terrain…").font(.caption2)
            }
            if terrainStore.shotPending { Text("Shot pending · release target to commit").font(.caption2) }
            if let message = terrainStore.statusMessage { Text(message).font(.caption2).fixedSize(horizontal: false, vertical: true) }
            if DevelopmentAPIConfiguration.current.gpxz == .mock {
                Text("DEMO DATA · Synthetic development terrain · 0 paid requests · live quota/history unchanged")
                    .font(.caption2.bold())
            } else {
                HStack {
                    Link("Terrain by GPXZ", destination: URL(string: "https://www.gpxz.io/")!)
                    Link("Source credit / licence catalogue", destination: URL(string: "https://api.gpxz.io/v1/elevation/sources")!)
                }
                .font(.system(size: 8))
                if let quota = terrainStore.quota {
                    Text("GPXZ · \(quota.used)/100 calls used · \(quota.remaining) remaining · \(terrainStore.plannedCalls) uncovered spans planned · local UTC month")
                        .font(.system(size: 8))
                } else {
                    Text("GPXZ · local quota unavailable; no paid request without a valid ledger").font(.system(size: 8))
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(FairwayVectorColors.navy)
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .accessibilityIdentifier("terrain-profile-button")
        .confirmationDialog("Retry terrain requests?", isPresented: $isConfirmingTerrainRetry, titleVisibility: .visible) {
            Button("Retry terrain") {
                terrainStore.retryFailedRequests(terrainRequest(for: hole,
                    origin: DistanceOrigin.resolve(location: locationManager.location, hole: hole), target: tapPoint))
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(DevelopmentAPIConfiguration.current.gpxz == .mock
                 ? "Recompute from local synthetic terrain. No GPXZ requests or changes to the live ledger, failure locks or quota."
                 : "Correct the reported cause first. Saved terrain is reused, but uncovered paths may spend additional calls. This clears failed-request locks only; used calls are not reset or refunded, and provider backoff still applies.")
        }
    }

    private func terrainDeltaText(_ meters: Double) -> String {
        let value = unit == .meters ? meters : meters / 0.9144
        let amount = String(format: "%+.1f %@", value, unit.symbol)
        return "\(amount) \(meters > 0.1 ? "uphill" : meters < -0.1 ? "downhill" : "level")"
    }

    private func bottomHoleMenu(hole: Hole, holeCount: Int) -> some View {
        HStack(alignment: .center, spacing: 10) {
            holeNavigationButton(isPrevious: true, count: holeCount)
            VStack(spacing: 4) {
                holeSummary(hole)
                selectedCourseSummary
            }
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

    private var selectedCourseSummary: some View {
        let location = store.reference.city.isEmpty ? store.reference.region : store.reference.city
        return VStack(spacing: 1) {
            Text("\(store.reference.clubName) · \(location) · \(store.reference.teeName) tee (\(store.reference.teeSex.capitalized))")
            Text("\(store.reference.holeCount) holes · Par \(store.reference.totalPar) · CR \(store.reference.courseRating, specifier: "%.1f") · Slope \(store.reference.slopeRating)")
        }
        .font(.system(size: 8, weight: .medium))
        .foregroundStyle(FairwayVectorColors.slate)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .multilineTextAlignment(.center)
    }

    private func topDistanceMenu(hole: Hole, origin: DistanceOrigin?, flag: GeoPoint?) -> some View {
        VStack(spacing: 4) {
            DistanceCard(hole: hole, origin: origin, unit: unit)
            HStack(spacing: 12) {
                distanceSummary("POINT", pointDistanceText(origin: origin), color: FairwayVectorColors.orange)
                Spacer(minLength: 0)
                distanceSummary("TO FLAG", flagDistanceText(flag: flag, origin: origin), color: FairwayVectorColors.flightBlue)
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

    private func flagDistanceText(flag: GeoPoint?, origin: DistanceOrigin?) -> String {
        guard let origin, let flag else { return "–" }
        return unit.format(GolfGeometry.distance(tapPoint ?? origin.point, flag))
    }

    private func flagPosition(for hole: Hole) -> GeoPoint? {
        if let data = customFlagPositions.data(using: .utf8),
           let positions = try? JSONDecoder().decode([String: GeoPoint].self, from: data),
           let custom = positions["\(store.reference.cacheKey)-\(hole.number)"] {
            return custom
        }
        return hole.flag ?? hole.greenCenter
    }

    private func saveFlagPosition(_ position: GeoPoint, for hole: Hole) {
        let key = "\(store.reference.cacheKey)-\(hole.number)"
        let data = customFlagPositions.data(using: .utf8) ?? Data()
        var positions = (try? JSONDecoder().decode([String: GeoPoint].self, from: data)) ?? [:]
        positions[key] = position
        guard let encoded = try? JSONEncoder().encode(positions),
              let value = String(data: encoded, encoding: .utf8) else { return }
        customFlagPositions = value
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
    CourseMapView(reference: .hills)
        .environmentObject(TrajectoryCalculatorViewModel())
}
