import CoreLocation
import SwiftUI

struct DistanceCard: View {
    let hole: Hole
    let origin: DistanceOrigin?
    let unit: DistanceUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let origin, let center = hole.greenCenter {
                let front = hole.greenFront.map { GolfGeometry.distance(origin.point, $0) }
                    ?? GolfGeometry.frontBack(from: origin.point, green: hole.green)?.front
                let back = hole.greenBack.map { GolfGeometry.distance(origin.point, $0) }
                    ?? GolfGeometry.frontBack(from: origin.point, green: hole.green)?.back
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    metric("Front", front, color: FairwayVectorColors.gold)
                    Spacer(minLength: 4)
                    metric("Center", GolfGeometry.distance(origin.point, center), color: FairwayVectorColors.orange, prominent: true)
                    Spacer(minLength: 4)
                    metric("Back", back, color: FairwayVectorColors.gold)
                }

            } else {
                Text("No green is mapped for this hole yet.")
                    .font(.subheadline)
                    .foregroundStyle(FairwayVectorColors.slate)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metric(_ title: String, _ meters: Double?, color: Color, prominent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(FairwayVectorColors.slate)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(meters.map { "\(unit.value($0))" } ?? "–")
                    .font((prominent ? Font.title3.bold() : Font.subheadline.bold()).monospacedDigit())
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

}

struct DistanceOrigin {
    enum Source {
        case gps(accuracy: Double)
        case simulated
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

    var isSimulated: Bool {
        if case .simulated = source { return true }
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
