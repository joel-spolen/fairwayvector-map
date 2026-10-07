import SwiftData
import SwiftUI

struct UnifiedSettingsView: View {
    var onOpenWedge: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [PlayerProfile]
    @Query(filter: #Predicate<GolfClub> { $0.isCustom == true }) private var customClubs: [GolfClub]
    @AppStorage("distanceUnit") private var mapUnit: DistanceUnit = .meters
    @AppStorage("wedgeMatrix.distanceUnit") private var wedgeUnit = WedgeDistanceUnit.yards.rawValue
    @EnvironmentObject private var trajectoryModel: TrajectoryCalculatorViewModel

    private var profile: PlayerProfile? { profiles.first }
    private var countries: [String] {
        Array(Set(CourseCatalogStore().countries + customClubs.map(\.country).filter { !$0.isEmpty })).sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Player & calibration") {
                    NavigationLink {
                        UnifiedProfileView(trajectoryModel: trajectoryModel, onOpenWedge: onOpenWedge)
                    } label: {
                        Label("Profile & personal club data", systemImage: "person.crop.circle")
                    }
                }
                .listRowBackground(PureLineStyle.surface)

                Section("Distance units") {
                    Picker("Distance", selection: Binding(
                        get: { mapUnit },
                        set: { unit in
                            mapUnit = unit
                            wedgeUnit = unit == .meters ? WedgeDistanceUnit.meters.rawValue : WedgeDistanceUnit.yards.rawValue
                            trajectoryModel.unitPreferences.globalDefault = unit == .meters ? .metric : .imperial
                        }
                    )) {
                        ForEach(DistanceUnit.allCases) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("Applies to course distances, wedge carries, and trajectory defaults.")
                        .font(.footnote)
                        .foregroundStyle(PureLineStyle.muted)
                }
                .listRowBackground(PureLineStyle.surface)

                Section("Handicap rounds") {
                    Picker("Default scoring", selection: Binding(
                        get: { profile?.defaultInputMode ?? .adjustedGrossScore },
                        set: { mode in updateProfile { $0.defaultInputMode = mode } }
                    )) {
                        ForEach(RoundInputMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    Picker("Country / Region", selection: Binding(
                        get: { profile?.countryOrDefault ?? "Sweden" },
                        set: { country in updateProfile { $0.selectedCountry = country } }
                    )) {
                        ForEach(countries, id: \.self) { country in
                            Text(country).tag(country)
                        }
                    }
                }
                .listRowBackground(PureLineStyle.surface)

                Section("Equipment & courses") {
                    NavigationLink("Clubs available for trajectory") {
                        BagClubsView(profileStore: trajectoryModel.playerProfileStore)
                    }
                    NavigationLink("Custom courses & tees") {
                        HCPCustomCoursesEntryView()
                    }
                }
                .listRowBackground(PureLineStyle.surface)

                Section("Flight units") {
                    NavigationLink("Advanced field overrides") {
                        TrajectoryUnitSettingsView(unitPreferences: trajectoryModel.unitPreferences)
                    }
                }
                .listRowBackground(PureLineStyle.surface)

                Section("Development API mode (build-time)") {
                    LabeledContent("Golf API", value: DevelopmentAPIConfiguration.current.golfAPI.status)
                    LabeledContent("GPXZ", value: DevelopmentAPIConfiguration.current.gpxz.status)
                    if DevelopmentAPIConfiguration.current.gpxz == .mock {
                        Text("Synthetic development terrain · not surveyed")
                            .font(.footnote)
                            .foregroundStyle(PureLineStyle.muted)
                    }
                    DisclosureGroup("Build-mode details") {
                        Text("Mock modes ignore existing keys. Saved real Hills is bundled read-only for fresh devices, alongside complete downloaded courses. Real IDs and tee ratings are retained; Demo Hills is separate invented data. Terrain remains synthetic in a separate mock namespace. The full real Hills terrain export is a private ignored local backup, not an app resource. Live caches and GPXZ budget/history remain unchanged. Activation requires an explicit per-provider build setting and rebuild; there is no runtime toggle.")
                            .font(.footnote)
                            .foregroundStyle(PureLineStyle.muted)
                        Text("Weather remains Open-Meteo (live/cache); Apple Maps imagery is unchanged. This is not an entirely offline app.")
                            .font(.footnote)
                            .foregroundStyle(PureLineStyle.muted)
                    }
                }
                .listRowBackground(PureLineStyle.surface)

                Section("About") {
                    Link("Handicap privacy", destination: URL(string: "https://fairwayvector.com/hcp-projection/privacy-policy")!)
                    Link("Trajectory privacy", destination: URL(string: "https://fairwayvector.com/trajectory/privacy-policy")!)
                    Link("Wedge Matrix privacy", destination: URL(string: "https://fairwayvector.com/wedge-matrix/privacy-policy")!)
                    Text(DevelopmentAPIConfiguration.current.golfAPI == .mock
                        ? "Course/GPS: saved downloaded Golf API/OpenStreetMap data when available, otherwise separately labelled invented Demo Hills. Satellite imagery provided by Apple Maps."
                        : "Course and GPS data provided by Golf API. Satellite imagery provided by Apple Maps.")
                        .font(.footnote)
                        .foregroundStyle(PureLineStyle.muted)
                    Link("Weather data by Open-Meteo", destination: URL(string: "https://open-meteo.com/")!)
                    if DevelopmentAPIConfiguration.current.gpxz == .mock {
                        Text("Terrain: Synthetic development terrain. Analytical local surface with no survey dates, real source resolution or surveyed height datum. No coordinates sent to GPXZ; no paid quota spent.")
                            .font(.footnote)
                            .foregroundStyle(PureLineStyle.muted)
                    } else {
                        Link("Terrain profiles by GPXZ", destination: URL(string: "https://www.gpxz.io/")!)
                        Link("Terrain source credits and licences", destination: URL(string: "https://api.gpxz.io/v1/elevation/sources")!)
                        Text("The profile shows returned source identifiers for both origin→target and target→flag. Source-specific attribution records and full licence texts have not been downloaded or bundled; the link opens the GPXZ catalogue for review.")
                            .font(.footnote)
                            .foregroundStyle(PureLineStyle.muted)
                        Text("Committed terrain profiles can send path coordinates, including your captured GPS position, to GPXZ. Source resolution and survey dates vary; sample spacing is not guaranteed accuracy. Saved data has no automatic expiry, prefetch, or retries. The local 100-call UTC monthly ledger is a device safeguard, not cross-device account enforcement.")
                            .font(.footnote)
                            .foregroundStyle(PureLineStyle.muted)
                    }
                }
                .listRowBackground(PureLineStyle.surface)
            }
            .scrollContentBackground(.hidden)
            .background(PureLineStyle.canvas)
            .foregroundStyle(PureLineStyle.ink)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(PureLineStyle.canvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(PureLineStyle.accent)
    }

    private func updateProfile(_ edit: (PlayerProfile) -> Void) {
        if let profile {
            edit(profile)
        } else {
            let newProfile = PlayerProfile(name: "Player")
            modelContext.insert(newProfile)
            edit(newProfile)
        }
    }
}

private struct TrajectoryUnitSettingsView: View {
    @ObservedObject var unitPreferences: UnitPreferences

    var body: some View {
        Form {
            ForEach(UnitField.allCases) { field in
                Picker(field.label, selection: Binding(
                    get: { unitPreferences.override(for: field)?.rawValue ?? "default" },
                    set: { unitPreferences.setOverride(UnitSystem(rawValue: $0), for: field) }
                )) {
                    Text("Use Default").tag("default")
                    ForEach(UnitSystem.allCases) { unit in
                        Text(unit.label).tag(unit.rawValue)
                    }
                }
                .listRowBackground(PureLineStyle.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(PureLineStyle.canvas)
        .foregroundStyle(PureLineStyle.ink)
        .tint(PureLineStyle.accent)
        .navigationTitle("Flight units")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(PureLineStyle.canvas, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}
