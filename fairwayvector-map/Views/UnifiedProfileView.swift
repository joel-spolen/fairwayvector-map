import SwiftData
import SwiftUI

struct SharedHandicapSync: View {
    @Query private var profiles: [PlayerProfile]
    @Query(sort: \GolfRound.date, order: .reverse) private var rounds: [GolfRound]
    @ObservedObject var trajectoryModel: TrajectoryCalculatorViewModel

    private var handicapIndex: Double? {
        let entries = WHSCalculator.scoringEntries(from: rounds, lowHandicapIndex: profiles.first?.lowHandicapIndex)
        return WHSCalculator.handicapIndex(from: entries, lowHandicapIndex: profiles.first?.lowHandicapIndex)
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear(perform: sync)
            .onChange(of: handicapIndex) { _, _ in sync() }
    }

    private func sync() {
        guard let handicapIndex else { return }
        let band = HandicapBand.forHandicap(handicapIndex)
        let profileStore = trajectoryModel.playerProfileStore
        guard profileStore.profile.exactHandicap != handicapIndex || profileStore.profile.handicapBand != band || !profileStore.profile.isSetupComplete else { return }
        profileStore.update {
            $0.handicapBand = band
            $0.exactHandicap = handicapIndex
            $0.isSetupComplete = true
        }
    }
}

extension HandicapBand {
    static func forHandicap(_ value: Double) -> HandicapBand {
        switch value {
        case ..<0: .plusToZero
        case ..<5: .zeroToFive
        case ..<10: .fiveToTen
        case ..<15: .tenToFifteen
        case ..<20: .fifteenToTwenty
        case ..<25: .twentyToTwentyFive
        case ..<35: .twentyFiveToThirtyFive
        default: .thirtyFivePlus
        }
    }
}

struct UnifiedProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [PlayerProfile]
    @Query(sort: \GolfRound.date, order: .reverse) private var rounds: [GolfRound]
    @ObservedObject var trajectoryModel: TrajectoryCalculatorViewModel
    let onOpenWedge: () -> Void
    @State private var showSettings = false

    private var profile: PlayerProfile? { profiles.first }

    private var handicapIndex: Double? {
        let entries = WHSCalculator.scoringEntries(from: rounds, lowHandicapIndex: profile?.lowHandicapIndex)
        return WHSCalculator.handicapIndex(from: entries, lowHandicapIndex: profile?.lowHandicapIndex)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Player") {
                    TextField("Name", text: Binding(
                        get: { profile?.name ?? "" },
                        set: { name in updateProfile { $0.name = name } }
                    ))
                    Picker("Tee rating", selection: Binding(
                        get: { profile?.sexOrDefault ?? .male },
                        set: { sex in updateProfile { $0.sexOrDefault = sex } }
                    )) {
                        Text("Men").tag(PlayerSex.male)
                        Text("Women").tag(PlayerSex.female)
                    }
                    LabeledContent("Handicap Index", value: handicapIndex.map { WHSCalculator.formatHCPScore($0) } ?? "Not yet calculated")
                    LabeledContent("Rounds", value: "\(rounds.count)")
                }
                .listRowBackground(FairwayVectorColors.surface)

                Section("Your game") {
                    NavigationLink {
                        TrajectoryProfileSettingsView(
                            profileStore: trajectoryModel.playerProfileStore,
                            unitPreferences: trajectoryModel.unitPreferences
                        )
                        .navigationTitle("Clubs & launch profile")
                    } label: {
                        Label("Clubs & launch profile", systemImage: "figure.golf")
                    }
                    Button(action: onOpenWedge) {
                        Label("Wedge bag & matrix", systemImage: "square.grid.3x3")
                    }
                }
                .listRowBackground(FairwayVectorColors.surface)
            }
            .scrollContentBackground(.hidden)
            .background(FairwayVectorColors.background)
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { showSettings = true }
                }
            }
            .sheet(isPresented: $showSettings) {
                UnifiedSettingsView()
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
