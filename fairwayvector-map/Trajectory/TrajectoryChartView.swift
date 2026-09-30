import SwiftUI
import Charts

/// Side-view (downrange vs height) and top-down (downrange vs lateral) flight charts.
struct TrajectoryChartView: View {
    let trajectory: GolfTrajectory
    let unitPreferences: UnitPreferences

    private var unitSystem: UnitSystem { unitPreferences.unitSystem(for: .distance) }

    private struct Point: Identifiable {
        let id: Int
        let downrange: Double
        let value: Double
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Modeled Physics Flight Path")
                    .font(.headline)
                Text("The chart shows the modeled path. Headline values above include calibration corrections.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            chartSection(title: "Side View (Height)", points: sideViewPoints, valueLabel: "Height")
            chartSection(title: "Top-Down View (Curvature)", points: topDownPoints, valueLabel: "Lateral")
        }
        .padding()
        .background(FairwayVectorColors.surface, in: RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(FairwayVectorColors.charcoal)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Golf ball trajectory charts")
        .accessibilityHint("The side view shows height and the top-down view shows lateral curvature. \(chartSummary)")
    }

    private var sideViewPoints: [Point] {
        zip(trajectory.xM, trajectory.zM).enumerated().map { index, pair in
            Point(id: index, downrange: displayDistance(pair.0), value: displayDistance(pair.1))
        }
    }

    private var topDownPoints: [Point] {
        zip(trajectory.xM, trajectory.yM).enumerated().map { index, pair in
            Point(id: index, downrange: displayDistance(pair.0), value: displayDistance(pair.1))
        }
    }

    private func displayDistance(_ meters: Double) -> Double {
        unitSystem == .imperial ? Units.yardsFromMeters(meters) : meters
    }

    private var distanceUnitLabel: String {
        unitSystem == .imperial ? "yd" : "m"
    }

    @ViewBuilder
    private func chartSection(title: String, points: [Point], valueLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
            Chart(points) { point in
                LineMark(
                    x: .value("Downrange", point.downrange),
                    y: .value(valueLabel, point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(FairwayVectorColors.flightBlue)
                if point.id == points.last?.id {
                    PointMark(
                        x: .value("Downrange", point.downrange),
                        y: .value(valueLabel, point.value)
                    )
                    .foregroundStyle(FairwayVectorColors.orange)
                }
            }
            .chartXAxisLabel("Downrange (\(distanceUnitLabel))")
            .chartYAxisLabel("\(valueLabel) (\(distanceUnitLabel))")
            .frame(height: 160)
            .accessibilityLabel(title)
            .accessibilityValue(valueLabel == "Height" ? sideViewSummary : topDownSummary)
        }
    }

    private var chartSummary: String {
        "Estimated carry is \(formattedDistance(lastDownrange)) with an apex of \(formattedDistance(apexHeight)). \(lateralSummary)"
    }

    private var sideViewSummary: String {
        "Modeled physics path. Estimated carry is \(formattedDistance(lastDownrange)) and apex is \(formattedDistance(apexHeight))."
    }

    private var topDownSummary: String {
        "Modeled physics path. At landing, the ball finishes \(formattedDistance(abs(lastLateral))) \(lastLateralDirection) of the target line."
    }

    private var lastDownrange: Double {
        trajectory.xM.last ?? 0
    }

    private var apexHeight: Double {
        trajectory.zM.max() ?? 0
    }

    private var lastLateral: Double {
        trajectory.yM.last ?? 0
    }

    private var lastLateralDirection: String {
        if abs(lastLateral) < 0.01 {
            return "on the target line"
        }
        return lastLateral > 0 ? "right" : "left"
    }

    private var lateralSummary: String {
        if abs(lastLateral) < 0.01 {
            return "The ball finishes on the target line."
        }
        return "At landing, the ball finishes \(formattedDistance(abs(lastLateral))) \(lastLateralDirection) of the target line."
    }

    private func formattedDistance(_ meters: Double) -> String {
        Units.formattedDistance(meters: meters, system: unitSystem)
    }
}
