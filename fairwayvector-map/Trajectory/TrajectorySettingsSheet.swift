import SwiftUI

private enum FieldOverrideOption: String, CaseIterable, Identifiable {
    case useDefault
    case imperial
    case metric

    var id: String { rawValue }

    var label: String {
        switch self {
        case .useDefault: return "Use Default"
        case .imperial: return "Imperial"
        case .metric: return "Metric"
        }
    }

    init(override: UnitSystem?) {
        switch override {
        case .none: self = .useDefault
        case .imperial: self = .imperial
        case .metric: self = .metric
        }
    }

    var override: UnitSystem? {
        switch self {
        case .useDefault: return nil
        case .imperial: return .imperial
        case .metric: return .metric
        }
    }
}

struct TrajectorySettingsSheet: View {
    @ObservedObject var viewModel: TrajectoryCalculatorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        BagClubsView(profileStore: viewModel.playerProfileStore)
                    } label: {
                        HStack {
                            Text("Clubs Available")
                            Spacer()
                            Text("\(viewModel.playerProfileStore.profile.availableClubs.count) clubs")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Equipment")
                } footer: {
                    Text("Choose the clubs available for selection. This controls the club selector and Medium profile carry distances.")
                }

                Section("Default Units") {
                    Picker("Unit System", selection: Binding(
                        get: { viewModel.unitPreferences.globalDefault },
                        set: { viewModel.unitPreferences.globalDefault = $0 }
                    )) {
                        ForEach(UnitSystem.allCases) { system in
                            Text(system.label).tag(system)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    ForEach(UnitField.allCases) { field in
                        Picker(field.label, selection: Binding(
                            get: { FieldOverrideOption(override: viewModel.unitPreferences.override(for: field)) },
                            set: { viewModel.unitPreferences.setOverride($0.override, for: field) }
                        )) {
                            ForEach(FieldOverrideOption.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                    }
                } header: {
                    Text("Field Overrides")
                } footer: {
                    Text("Override the default unit system for individual fields, e.g. imperial ball speed with metric everything else.")
                }

                Section {
                    Link("Privacy Policy", destination: URL(string: "https://fairwayvector.com/trajectory/privacy-policy")!)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.white)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
