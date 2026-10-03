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
                        .foregroundStyle(FairwayVectorColors.slate)
                }
                .listRowBackground(FairwayVectorColors.surface)

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
                .listRowBackground(FairwayVectorColors.surface)

                Section("Equipment & courses") {
                    NavigationLink("Clubs available for trajectory") {
                        BagClubsView(profileStore: trajectoryModel.playerProfileStore)
                    }
                    NavigationLink("Custom courses & tees") {
                        HCPCustomCoursesEntryView()
                    }
                }
                .listRowBackground(FairwayVectorColors.surface)

                Section("Flight units") {
                    NavigationLink("Advanced field overrides") {
                        TrajectoryUnitSettingsView(unitPreferences: trajectoryModel.unitPreferences)
                    }
                }
                .listRowBackground(FairwayVectorColors.surface)

                Section("About") {
                    Link("Handicap privacy", destination: URL(string: "https://fairwayvector.com/hcp-projection/privacy-policy")!)
                    Link("Trajectory privacy", destination: URL(string: "https://fairwayvector.com/trajectory/privacy-policy")!)
                    Link("Wedge Matrix privacy", destination: URL(string: "https://fairwayvector.com/wedge-matrix/privacy-policy")!)
                    Text("Course and GPS data provided by Golf API. Satellite imagery provided by Apple Maps.")
                        .font(.footnote)
                }
                .listRowBackground(FairwayVectorColors.surface)
            }
            .scrollContentBackground(.hidden)
            .background(FairwayVectorColors.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(FairwayVectorColors.navy)
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
            }
        }
        .navigationTitle("Flight units")
    }
}
