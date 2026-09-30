//
//  ContentView.swift
//  fairwayvector-trajectory
//
//  Created by FairwayVector on 2026-08-22.
//

import SwiftUI

struct TrajectoryRootView: View {
    private enum Tab: String, CaseIterable {
        case home
        case calculator
        case club

        var title: String {
            switch self {
            case .home: "Overview"
            case .calculator: "Trajectory"
            case .club: "Club Selector"
            }
        }
    }

    @ObservedObject var viewModel: TrajectoryCalculatorViewModel
    @State private var selectedTab: Tab = .home

    var body: some View {
        VStack(spacing: 0) {
            Picker("Trajectory tools", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(12)
            .background(FairwayVectorColors.background)

            Group {
                switch selectedTab {
                case .home:
                    TrajectoryHomeView(
                        viewModel: viewModel,
                        onClose: {},
                        onOpenLastCalculation: {
                            viewModel.restoreLastCalculationInputs()
                            selectedTab = .calculator
                        },
                        onExampleShot: { viewModel.randomizeExampleShot() },
                        onOpenClub: { selectedTab = .club },
                        onOpenTrajectory: { selectedTab = .calculator }
                    )
                case .calculator:
                    TrajectoryCalculatorView(viewModel: viewModel)
                case .club:
                    TrajectoryClubView(viewModel: viewModel, onOpenTrajectory: { selectedTab = .calculator })
                }
            }
        }
        .tint(FairwayVectorColors.navy)
    }
}

#Preview {
    TrajectoryRootView(viewModel: TrajectoryCalculatorViewModel())
}
