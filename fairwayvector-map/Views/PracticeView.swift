import SwiftUI

enum PracticeDestination: String, CaseIterable {
    case trajectory
    case wedge

    var title: String {
        switch self {
        case .trajectory: "Trajectory"
        case .wedge: "Wedge Matrix"
        }
    }
}

struct PracticeView: View {
    @Binding var destination: PracticeDestination
    @ObservedObject var trajectoryModel: TrajectoryCalculatorViewModel

    var body: some View {
        Group {
            switch destination {
            case .trajectory:
                TrajectoryRootView(viewModel: trajectoryModel)
            case .wedge:
                WedgeMatrixView()
            }
        }
        .tint(destination == .wedge ? PureLineStyle.accent : FairwayVectorColors.navy)
    }
}
