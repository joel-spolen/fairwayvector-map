import CoreLocation
import SwiftUI

struct DistanceCard: View {
    let hole: Hole
    let origin: DistanceOrigin?
    let tapPoint: GeoPoint?
    let unit: DistanceUnit
    let onClearTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let origin, let center = hole.greenCenter {
                let frontBack = GolfGeometry.frontBack(from: origin.point, green: hole.green)
                metric("Front", frontBack?.front, color: FairwayVectorColors.gold)
                metric("Center", GolfGeometry.distance(origin.point, center), color: FairwayVectorColors.orange, prominent: true)
                metric("Back", frontBack?.back, color: FairwayVectorColors.gold)

                if let tapPoint {
                    tapRow(from: origin.point, tap: tapPoint, flag: hole.flag, startLabel: origin.usesGPS ? "from you" : "from tee")
                }

            } else {
                Text("No green is mapped for this hole yet.")
                    .font(.subheadline)
                    .foregroundStyle(FairwayVectorColors.slate)
            }
            Text("© OpenStreetMap contributors")
                .font(.system(size: 8))
                .foregroundStyle(FairwayVectorColors.slate)
        }
        .padding(10)
        .frame(width: 94, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(FairwayVectorColors.surface.opacity(0.75), lineWidth: 1)
        }
    }

    private func metric(_ title: String, _ meters: Double?, color: Color, prominent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(FairwayVectorColors.slate)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(meters.map { "\(unit.value($0))" } ?? "–")
                    .font((prominent ? Font.title2.bold() : Font.title3.bold()).monospacedDigit())
                    .foregroundStyle(color)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(unit.symbol)
                    .font(.caption2)
                    .foregroundStyle(FairwayVectorColors.slate)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(meters.map(unit.format) ?? "unavailable")")
    }

    private func tapRow(from start: GeoPoint, tap: GeoPoint, flag: GeoPoint?, startLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("TARGET")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FairwayVectorColors.slate)
                Spacer()
                Button("Clear target", systemImage: "xmark.circle.fill", action: onClearTap)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(FairwayVectorColors.slate)
                    .accessibilityLabel("Clear selected point")
            }
            Text("\(unit.format(GolfGeometry.distance(start, tap))) \(startLabel)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(FairwayVectorColors.orange)
            if let flag {
                Text("\(unit.format(GolfGeometry.distance(tap, flag))) to flag")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(FairwayVectorColors.flightBlue)
            }
            Text("Drag marker to adjust")
                .font(.caption2)
                .foregroundStyle(FairwayVectorColors.slate)
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

}
