import SwiftUI

struct TrajectoryProfileSetupWizardView: View {
    @ObservedObject var profileStore: PlayerProfileStore
    let unitPreferences: UnitPreferences
    let onClose: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedBand: HandicapBand

    init(profileStore: PlayerProfileStore, unitPreferences: UnitPreferences, onClose: @escaping () -> Void) {
        self.profileStore = profileStore
        self.unitPreferences = unitPreferences
        self.onClose = onClose
        let profile = profileStore.profile
        _selectedBand = State(initialValue: profile.handicapBand)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FairwayVectorColors.background
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18) {
                    Text("Set your starting profile")
                        .font(.title2.bold())
                        .foregroundStyle(FairwayVectorColors.navy)

                    Text("Choose the handicap range that best matches your game. More detailed distances and club values live in the Profile tab.")
                        .font(.subheadline)
                        .foregroundStyle(FairwayVectorColors.slate)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Handicap Range")
                            .font(.headline)
                            .foregroundStyle(FairwayVectorColors.navy)
                        Picker("Handicap Range", selection: $selectedBand) {
                            ForEach(HandicapBand.allCases) { band in
                                Text(band.label).tag(band)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                    .padding()
                    .background(FairwayVectorColors.surface, in: RoundedRectangle(cornerRadius: 12))

                    Spacer()
                }
                .padding()
            }
            .tint(FairwayVectorColors.navy)
            .navigationTitle("Profile Setup")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if profileStore.profile.isSetupComplete {
                        Button("Cancel") { dismiss() }
                    } else {
                        Button("Close", action: onClose)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") { finishSetup() }
                }
            }
        }
    }

    private func finishSetup() {
        profileStore.update { profile in
            profile.isSetupComplete = true
            profile.detailLevel = .easy
            profile.handicapBand = selectedBand
        }
        dismiss()
    }
}

#Preview {
    TrajectoryProfileSetupWizardView(profileStore: PlayerProfileStore(), unitPreferences: UnitPreferences(), onClose: {})
}