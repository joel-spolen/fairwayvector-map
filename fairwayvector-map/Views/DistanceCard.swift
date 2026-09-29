import CoreLocation
import SwiftUI

struct DistanceCard: View {
    let hole: Hole
    let origin: DistanceOrigin?
    let tapPoint: GeoPoint?
    let unit: DistanceUnit
    let onClearTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let origin, let center = hole.greenCenter {
                let frontBack = GolfGeometry.frontBack(from: origin.point, green: hole.green)
                HStack(alignment: .lastTextBaseline) {
                    metric("Front", frontBack?.front, color: FairwayVectorColors.gold, font: .title3.bold())
                    Spacer()
                    metric("Center", GolfGeometry.distance(origin.point, center), color: FairwayVectorColors.orange, font: .largeTitle.bold())
                    Spacer()
                    metric("Back", frontBack?.back, color: FairwayVectorColors.gold, font: .title3.bold())
                }

                if let tapPoint {
                    tapRow(from: origin.point, tap: tapPoint, flag: hole.flag, startLabel: origin.usesGPS ? "from you" : "from tee")
                }

                Text(origin.caption(unit: unit))
                    .font(.caption)
                    .foregroundStyle(FairwayVectorColors.slate)
            } else {
                Text("No green is mapped for this hole yet.")
                    .font(.subheadline)
                    .foregroundStyle(FairwayVectorColors.slate)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FairwayVectorColors.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func metric(_ title: String, _ meters: Double?, color: Color, font: Font) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(FairwayVectorColors.slate)
            Text(meters.map { "\(unit.value($0))" } ?? "–")
                .font(font.monospacedDigit())
                .foregroundStyle(color)
            Text(unit.symbol)
                .font(.caption2)
                .foregroundStyle(FairwayVectorColors.slate)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(meters.map(unit.format) ?? "unavailable")")
    }

    private func tapRow(from start: GeoPoint, tap: GeoPoint, flag: GeoPoint?, startLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Selected point")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FairwayVectorColors.slate)
                Spacer()
                Button("Clear target", systemImage: "xmark.circle.fill", action: onClearTap)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(FairwayVectorColors.slate)
                    .accessibilityLabel("Clear selected point")
            }
            HStack(spacing: 8) {
                Label("\(unit.format(GolfGeometry.distance(start, tap))) \(startLabel)", systemImage: "scope")
                    .foregroundStyle(FairwayVectorColors.orange)
                if let flag {
                    Image(systemName: "arrow.right")
                        .foregroundStyle(FairwayVectorColors.slate)
                    Label(unit.format(GolfGeometry.distance(tap, flag)), systemImage: "flag")
                        .foregroundStyle(FairwayVectorColors.flightBlue)
                }
            }
            .font(.subheadline.weight(.semibold).monospacedDigit())
        }
        .padding(10)
        .background(FairwayVectorColors.conditionsSurface, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct DistanceOrigin {
    enum Source {
        case gps(accuracy: Double)
        case teeNoFix
        case teeFarAway(distance: Double)
    }

    var point: GeoPoint
    var source: Source

    static let onHoleCorridor = 100.0

    var usesGPS: Bool {
        if case .gps = source { return true }
        return false
    }

    static func resolve(location: CLLocation?, hole: Hole) -> DistanceOrigin? {
        guard let tee = hole.tee else { return nil }
        guard let location, location.horizontalAccuracy >= 0 else {
            return DistanceOrigin(point: tee, source: .teeNoFix)
        }
        let player = GeoPoint(location.coordinate)
        let away = GolfGeometry.distance(player, toPath: hole.path) ?? .infinity
        if away > onHoleCorridor {
            return DistanceOrigin(point: tee, source: .teeFarAway(distance: away))
        }
        return DistanceOrigin(point: player, source: .gps(accuracy: location.horizontalAccuracy))
    }

    func caption(unit: DistanceUnit) -> String {
        switch source {
        case .gps(let accuracy):
            "From your position · GPS ±\(unit.format(accuracy)) · Map data © OpenStreetMap contributors"
        case .teeNoFix:
            "From the tee (waiting for GPS) · Map data © OpenStreetMap contributors"
        case .teeFarAway(let distance):
            "From the tee (you are \(String(format: "%.1f", distance / 1000)) km away) · Map data © OpenStreetMap contributors"
        }
    }
}
