//
//  ContentView.swift
//  fairwayvector-trajectory
//
//  Created by FairwayVector on 2026-08-22.
//

import SwiftUI

struct TrajectoryRootView: View {
    private enum Tab {
        case home
        case calculator
        case club
        case profile
    }

    @StateObject private var viewModel = TrajectoryCalculatorViewModel()
    @State private var selectedTab: Tab = .home
    let onClose: () -> Void

    var body: some View {
        TabView(selection: $selectedTab) {
            TrajectoryHomeView(
                viewModel: viewModel,
                onClose: onClose,
                onOpenLastCalculation: {
                    viewModel.restoreLastCalculationInputs()
                    selectedTab = .calculator
                },
                onExampleShot: {
                    viewModel.randomizeExampleShot()
                },
                onOpenClub: {
                    selectedTab = .club
                },
                onOpenTrajectory: {
                    selectedTab = .calculator
                }
            )
            .tabItem { Label("Home", systemImage: "house") }
            .tag(Tab.home)

            TrajectoryCalculatorView(viewModel: viewModel)
                .tabItem { Label("Trajectory", systemImage: "chart.xyaxis.line") }
                .tag(Tab.calculator)

            TrajectoryClubView(
                viewModel: viewModel,
                onOpenTrajectory: {
                    selectedTab = .calculator
                }
            )
                .tabItem { Label("Club Selector", systemImage: "target") }
                .tag(Tab.club)

            NavigationStack {
                TrajectoryProfileSettingsView(
                    profileStore: viewModel.playerProfileStore,
                    unitPreferences: viewModel.unitPreferences,
                    settingsViewModel: viewModel
                )
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            .tag(Tab.profile)
        }
        .tint(FairwayVectorColors.navy)
        .fullScreenCover(isPresented: setupBinding) {
            TrajectoryProfileSetupWizardView(
                profileStore: viewModel.playerProfileStore,
                unitPreferences: viewModel.unitPreferences,
                onClose: onClose
            )
        }
    }

    private var setupBinding: Binding<Bool> {
        Binding(
            get: { viewModel.playerProfileStore.needsSetup },
            set: { _ in }
        )
    }
}

#Preview {
    TrajectoryRootView(onClose: {})
}
