import SwiftUI

/// No acquisition in this view. It reads committed terrain and the existing weather store.
struct CourseShotRecommendationView: View {
    let terrainStore: TerrainElevationStore
    let weatherStore: CourseWeatherStore
    let weatherLocation: GeoPoint?
    let selectedTarget: GeoPoint?
    let unit: DistanceUnit
    @ObservedObject var model: TrajectoryCalculatorViewModel
    @State private var engine = ClubRecommendationEngine()
    @State private var result: CourseShotRecommendationResult?
    @State private var failedInput: CourseShotRecommendationInput?
    @State private var errorMessage: String?
    @State private var isShowingDetails = false
    @State private var isShowingProfile = false

    private var capturedWeather: CourseWeather? {
        guard let weatherLocation else { return nil }
        return weatherStore.weather(for: weatherLocation)
    }

    private var input: CourseShotRecommendationInput? {
        guard !terrainStore.shotPending else { return nil }
        return .capture(request: terrainStore.committedRequest, selectedTarget: selectedTarget,
                        weather: capturedWeather, weatherLocation: weatherStore.weatherLocation,
                        shotProfile: terrainStore.snapshot.shotProfile, profile: model.playerProfileStore.profile)
    }

    private var currentResult: CourseShotRecommendationResult? {
        guard let input, result?.input == input else { return nil }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if DevelopmentAPIConfiguration.current.golfAPI == .mock || terrainStore.metadata.contains(where: \.isSynthetic) {
                Text("DEMO DATA · recommendations use synthetic course/terrain, not for play")
                    .font(.caption2.bold())
            }
            if let currentResult, let best = currentResult.recommendations.first {
                Button { isShowingDetails = true } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Label("Best modeled club · \(best.club.label)", systemImage: "figure.golf")
                                .font(.subheadline.bold())
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.up")
                        }
                        recommendationRow(best, target: currentResult.input.distanceM)
                        HStack {
                            Text("Target \(unit.format(currentResult.input.distanceM)) · \(currentResult.input.request.usesGPS ? "Captured GPS" : "Captured tee fallback")")
                            Spacer(minLength: 0)
                            Text("Trajectory & alternatives")
                        }
                        .font(.caption2)
                        Text("Advice at the committed position, not live GPS. Release a target or confirm Refresh terrain to update.")
                            .font(.caption2)
                        if currentResult.input.profile.detailLevel == .easy {
                            Text("Handicap-based launch defaults · estimates, not measured calibration").font(.caption2)
                        }
                        ForEach(Array(currentResult.recommendations.dropFirst().prefix(2))) { alternative in
                            HStack {
                                Text(alternative.club.label).fontWeight(.semibold)
                                Spacer(minLength: 0)
                                recommendationRow(alternative, target: currentResult.input.distanceM)
                            }
                            .font(.caption)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens captured conditions, trajectory results and nearest alternatives")
            } else {
                HStack(spacing: 6) {
                    if input != nil, failedInput != input { ProgressView().controlSize(.small) }
                    Label("Club recommendation", systemImage: "figure.golf").font(.caption.bold())
                }
                Text(status).font(.caption2).fixedSize(horizontal: false, vertical: true)
            }
            if CourseShotRecommendationInput.profileIssue(model.playerProfileStore.profile) != nil || failedInput == input && errorMessage != nil {
                Button("Configure Practice / Profile") { isShowingProfile = true }.font(.caption.weight(.semibold))
            }
        }
        .foregroundStyle(FairwayVectorColors.navy)
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .accessibilityIdentifier("course-club-recommendation")
        .task(id: input) {
            result = nil
            failedInput = nil
            errorMessage = nil
            guard let captured = input else { return }
            do {
                // Coalesce committed-target/weather/profile changes, never live GPS.
                try await Task.sleep(for: .milliseconds(200))
                let launches = try ClubRecommendationEngine.launches(profile: captured.profile, conditions: captured.conditions)
                let recommendations = try await engine.recommend(for: captured.distanceM, launches: launches)
                try Task.checkCancellation()
                guard input == captured else { return }
                if recommendations.isEmpty {
                    failedInput = captured
                    errorMessage = "No club prediction is available. Configure Clubs & launch profile."
                } else {
                    result = CourseShotRecommendationResult(input: captured, recommendations: recommendations)
                }
            } catch is CancellationError {
                // A newer target or conditions own publication.
            } catch {
                guard !Task.isCancelled, input == captured else { return }
                failedInput = captured
                errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $isShowingDetails) {
            if let currentResult {
                CourseShotRecommendationDetail(result: currentResult, unit: unit,
                    unitPreferences: model.unitPreferences)
            } else {
                NavigationStack {
                    ContentUnavailableView("Recommendation changed", systemImage: "scope",
                                           description: Text(status))
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { isShowingDetails = false } } }
                }
            }
        }
        .sheet(isPresented: $isShowingProfile) {
            if model.playerProfileStore.needsSetup {
                TrajectoryProfileSetupWizardView(profileStore: model.playerProfileStore,
                    unitPreferences: model.unitPreferences, onClose: { isShowingProfile = false })
            } else {
                NavigationStack {
                    TrajectoryProfileSettingsView(profileStore: model.playerProfileStore, unitPreferences: model.unitPreferences,
                                                  settingsViewModel: model)
                        .navigationTitle("Clubs & launch profile")
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { isShowingProfile = false } } }
                }
            }
        }
    }

    private var status: String {
        if selectedTarget == nil { return "Release a point on the map to choose a shot target." }
        if terrainStore.shotPending { return "Target moving · release to calculate." }
        if let issue = CourseShotRecommendationInput.profileIssue(model.playerProfileStore.profile) { return issue }
        if capturedWeather.map({ CourseShotRecommendationInput.valid($0) }) != true {
            return "Waiting for complete course weather: temperature, surface pressure, humidity and wind. No flat/calm fallback."
        }
        if input == nil {
            return terrainStore.isShotLoading ? "Waiting for matching origin/target terrain…"
                : "Matching origin/target terrain unavailable. Release the target or confirm Retry terrain; no flat-ground assumption."
        }
        if failedInput == input { return errorMessage ?? "Club predictions unavailable." }
        return "Calculating with your Practice bag, captured weather and terrain…"
    }

    private func recommendationRow(_ recommendation: ClubRecommendation, target: Double) -> some View {
        Text("\(unit.format(recommendation.estimatedCarryM)) carry · \(CourseShotRecommendationDetail.errorText(recommendation, target: target, unit: unit))")
            .font(.caption).foregroundStyle(FairwayVectorColors.orange)
    }
}

private struct CourseShotRecommendationDetail: View {
    let result: CourseShotRecommendationResult
    let unit: DistanceUnit
    @ObservedObject var unitPreferences: UnitPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var selectedClub: TrajectoryGolfClub?

    private var input: CourseShotRecommendationInput { result.input }
    private var selected: ClubRecommendation? {
        result.recommendations.first { $0.club == selectedClub } ?? result.recommendations.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if DevelopmentAPIConfiguration.isDemoCourse(input.request.courseID) || input.originSample.provenance.contains(where: \.isSynthetic) {
                        Text("DEMO DATA · Synthetic development course/terrain · real Open-Meteo weather · not for play")
                            .font(.caption.bold())
                    }
                    Text("\(unit.format(input.distanceM)) horizontal target · \(input.request.usesGPS ? "Captured GPS origin" : "Tee fallback origin")")
                        .font(.headline)
                    Text("Advice uses the committed origin, not your live GPS position. Release a map target or confirm Refresh terrain to capture a new origin.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Ranked by absolute corrected carry error, using the same full-swing club profiles and Physics V1.1 + HGB residual models as Practice. Not roll, a guaranteed hit, or obstacle clearance.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Corrected carry is horizontal landing distance (including lateral drift), not downrange alone. A closest-carry ranking can still miss the point sideways.")
                        .font(.caption).foregroundStyle(.secondary)
                    if input.profile.detailLevel == .easy {
                        Text("Simple profile: launch values are handicap-based defaults, not measured club calibration.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Profile: \(input.profile.detailLevel.label). Unentered fields use Practice’s existing calibrated/interpolated defaults.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(Array(result.recommendations.prefix(3))) { recommendation in
                        Button { selectedClub = recommendation.club } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(recommendation.id == result.recommendations.first?.id ? "Best modeled club" : "Alternative") · \(recommendation.club.label)").bold()
                                    Text("\(unit.format(recommendation.estimatedCarryM)) carry · \(Self.errorText(recommendation, target: input.distanceM, unit: unit))")
                                }
                                Spacer(minLength: 0)
                                Image(systemName: selected?.club == recommendation.club ? "checkmark.circle.fill" : "circle")
                            }
                            .font(.subheadline).padding(12)
                            .background(FairwayVectorColors.surface, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                    if let selected {
                        Text(selected.club.label).font(.title2.bold())
                        outcome(selected)
                        TrajectoryResultsView(prediction: selected.prediction, unitPreferences: unitPreferences)
                        let launch = ClubProfileDefaults.effectiveProfile(for: selected.club, playerProfile: input.profile)
                        Text(String(format: "Modeled spin axis: %+.1f° (+ curves right, − curves left). Wind and spin both contribute to the path.", launch.spinAxisDeg.value))
                            .font(.caption).foregroundStyle(.secondary)
                        TrajectoryChartView(trajectory: selected.trajectory, unitPreferences: unitPreferences,
                                            targetDistanceM: input.distanceM, targetElevationM: input.conditions.elevationDeltaM,
                                            capturedWind: (tail: input.conditions.tailwindMps, right: input.conditions.crosswindMps),
                                            shotBearingDeg: input.bearingDeg)
                    }
                    conditions
                }
                .padding()
            }
            .background(FairwayVectorColors.background)
            .foregroundStyle(FairwayVectorColors.navy)
            .navigationTitle("Shot recommendation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .tint(FairwayVectorColors.navy)
    }

    private func outcome(_ recommendation: ClubRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            let downrange = recommendation.trajectory.xM.last ?? 0
            let lateral = recommendation.trajectory.yM.last ?? 0
            Text("Physics landing: \(unit.format(downrange)) downrange; \(unit.format(abs(lateral))) \(lateral >= 0 ? "right" : "left") of target line.")
            if let height = recommendation.heightAtTargetDistanceM {
                Text("Physics height at target distance: \(height.formatted(.number.precision(.fractionLength(1)))) m above origin (target: \(input.conditions.elevationDeltaM.formatted(.number.precision(.fractionLength(1)))) m).")
            } else {
                Label("Physics flight ends before the target distance, even if corrected carry is closer.", systemImage: "exclamationmark.triangle")
            }
            if recommendation.estimatedCarryM < input.distanceM {
                Text("This club’s corrected carry estimate is short of the target.")
            }
            Text("The model lands on a horizontal plane at the target elevation; intermediate terrain, trees, hazards and roll are not simulated. Crosswind/spin drift is shown, not compensated by an optimized aim.")
        }
        .font(.caption).foregroundStyle(.secondary)
    }

    private var conditions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Captured conditions & sources").font(.headline)
            LabeledContent("Shot bearing (true)", value: String(format: "%.1f°", input.bearingDeg))
            LabeledContent("Temperature / humidity", value: String(format: "%.1f °C / %.0f%%", input.conditions.temperatureC, input.conditions.humidityPct))
            LabeledContent("Surface pressure", value: String(format: "%.1f hPa", input.conditions.pressureHpa))
            LabeledContent("Wind (meteorological FROM)", value: String(format: "%.1f m/s (%.1f km/h) from %.0f°", input.weather.windSpeedMps!, input.weather.windSpeedMps! * 3.6, input.weather.windDirectionDegrees!))
            LabeledContent(input.conditions.tailwindMps >= 0 ? "Tailwind" : "Headwind", value: String(format: "%.1f m/s", abs(input.conditions.tailwindMps)))
            LabeledContent("Crosswind toward \(input.conditions.crosswindMps >= 0 ? "right" : "left")", value: String(format: "%.1f m/s", abs(input.conditions.crosswindMps)))
            LabeledContent(input.originSample.provenance.contains(where: \.isSynthetic) ? "Synthetic terrain origin / target" : "Terrain origin / target (EGM2008)", value: String(format: "%.1f / %.1f m", input.originSample.elevationMeters!, input.targetSample.elevationMeters!))
            LabeledContent("Target minus origin", value: String(format: "%+.1f m", input.conditions.elevationDeltaM))
            Text("Open-Meteo course weather snapshot: \(input.weather.observedAt) (\(input.weather.timezone ?? "provider local time")). This may be cached; course-level surface pressure and 10 m wind are used unchanged, not measured at the ball. Absolute terrain height is provenance only: pressure is supplied directly, not altitude-compensated again. Gusts are not used.")
            Text(String(format: "Weather location: %.5f, %.5f · origin: %.5f, %.5f · target: %.5f, %.5f", input.weatherLocation.lat, input.weatherLocation.lon, input.originSample.point.lat, input.originSample.point.lon, input.targetSample.point.lat, input.targetSample.point.lon))
            ForEach(Array(Set(input.originSample.provenance + input.targetSample.provenance)).sorted { $0.dataSource < $1.dataSource }, id: \.self) { record in
                if record.isSynthetic {
                    Text("Synthetic development terrain · analytical surface · no surveyed datum/resolution or capture date · generated/saved \(record.fetchedAt.formatted())")
                } else {
                    Text("GPXZ · \(record.dataSource) · source resolution \(record.resolutionMeters.formatted()) m · captured \(record.captureDateMin ?? "unknown")–\(record.captureDateMax ?? "unknown") · dataset \(record.datasetVersion ?? "unknown") · saved \(record.fetchedAt.formatted())")
                }
            }
            if input.originSample.locallyInterpolated || input.targetSample.locallyInterpolated {
                Text("Endpoint heights include local interpolation along saved provider coverage.")
            }
            Text("Terrain source spacing is not accuracy. GPS error, forecast age, source resolution and your launch-profile quality affect these estimates. Practice inputs and selected club have not been changed.")
        }
        .font(.caption).padding()
        .background(FairwayVectorColors.conditionsSurface, in: RoundedRectangle(cornerRadius: 12))
    }

    static func errorText(_ recommendation: ClubRecommendation, target: Double, unit: DistanceUnit) -> String {
        let error = recommendation.estimatedCarryM - target
        if abs(error) < 0.05 { return "on target (estimate)" }
        let value = unit == .meters ? abs(error) : abs(error) / 0.9144
        return String(format: "%.1f %@ %@", value, unit.symbol, error < 0 ? "short" : "long")
    }
}