import SwiftData
import SwiftUI

struct UnifiedSettingsView: View {
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
                        UnifiedProfileView()
                    } label: {
                        Label("Player profile", systemImage: "person.crop.circle")
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

                Section("About") {
                    Link("Handicap privacy", destination: URL(string: "https://fairwayvector.com/hcp-projection/privacy-policy")!)
                    Link("Trajectory privacy", destination: URL(string: "https://fairwayvector.com/trajectory/privacy-policy")!)
                    Link("Wedge Matrix privacy", destination: URL(string: "https://fairwayvector.com/wedge-matrix/privacy-policy")!)
                    Link("Weather data by Open-Meteo", destination: URL(string: "https://open-meteo.com/")!)
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
