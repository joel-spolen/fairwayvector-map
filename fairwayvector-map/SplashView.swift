import SwiftUI

struct SplashView: View {
    let isReturningUser: Bool
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress = 0.0
    @State private var isVisible = false
    @State private var didScheduleDismissal = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                FairwayVectorColors.navy
                    .ignoresSafeArea()

                VStack(spacing: 26) {
                    FairwayVectorMark(progress: progress)
                        .frame(width: min(proxy.size.width * 0.5, 180), height: min(proxy.size.width * 0.5, 180))

                    VStack(spacing: 10) {
                        Text("FairwayVector")
                            .font(.largeTitle.bold())
                            .foregroundStyle(FairwayVectorColors.surface)
                        Rectangle()
                            .fill(FairwayVectorColors.gold)
                            .frame(width: 44, height: 2)
                        Text("Course Map")
                            .font(.headline)
                            .foregroundStyle(FairwayVectorColors.surface.opacity(0.9))
                        Text("Know your place on the course")
                            .font(.subheadline)
                            .foregroundStyle(FairwayVectorColors.surface.opacity(0.68))
                    }
                }
                .opacity(isVisible ? 1 : 0)
                .scaleEffect(isVisible ? 1 : 0.94)
                .offset(y: -40)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("FairwayVector, Course Map")
            .accessibilityAddTraits(.isHeader)
        }
        .onAppear(perform: startAnimation)
    }

    private func startAnimation() {
        guard !didScheduleDismissal else { return }
        didScheduleDismissal = true

        if reduceMotion {
            progress = 1
            isVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + (isReturningUser ? 0.3 : 0.75), execute: onDismiss)
            return
        }

        withAnimation(.easeOut(duration: isReturningUser ? 0.2 : 0.45)) {
            isVisible = true
        }
        withAnimation(.easeInOut(duration: isReturningUser ? 0.35 : 1.15).delay(isReturningUser ? 0.05 : 0.2)) {
            progress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (isReturningUser ? 0.65 : 1.8)) {
            withAnimation(.easeInOut(duration: isReturningUser ? 0.15 : 0.3)) {
                isVisible = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (isReturningUser ? 0.15 : 0.3), execute: onDismiss)
        }
    }
}
