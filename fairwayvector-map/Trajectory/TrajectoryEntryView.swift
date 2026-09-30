import SwiftUI

struct TrajectoryEntryView: View {
    let onClose: () -> Void

    var body: some View {
        TrajectoryRootView(onClose: onClose)
    }
}

#Preview {
    TrajectoryEntryView(onClose: {})
}
