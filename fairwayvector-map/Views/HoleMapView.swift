import MapKit
import SwiftUI

struct HoleMapView: View {
    let hole: Hole
    let origin: GeoPoint?
    @Binding var tapPoint: GeoPoint?

    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        MapReader { proxy in
            Map(position: $position) {
                UserAnnotation()

                if hole.path.count >= 2 {
                    MapPolyline(coordinates: hole.path.map(\.coordinate))
                        .stroke(.white.opacity(0.8), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                }

                if hole.green.count >= 3 {
                    MapPolygon(coordinates: hole.green.map(\.coordinate))
                        .foregroundStyle(FairwayVectorColors.gold.opacity(0.25))
                        .stroke(FairwayVectorColors.gold, lineWidth: 2)
                }

                if let flag = hole.flag {
                    Annotation("Flag", coordinate: flag.coordinate, anchor: .bottomLeading) {
                        Image(systemName: "flag.fill")
                            .font(.title3)
                            .foregroundStyle(FairwayVectorColors.orange)
                            .shadow(radius: 2)
                    }
                    .annotationTitles(.hidden)
                }

                if let tapPoint {
                    if let origin {
                        MapPolyline(coordinates: [origin.coordinate, tapPoint.coordinate])
                            .stroke(FairwayVectorColors.orange, lineWidth: 3)
                    }
                    if let flag = hole.flag {
                        MapPolyline(coordinates: [tapPoint.coordinate, flag.coordinate])
                            .stroke(FairwayVectorColors.flightBlue, lineWidth: 3)
                    }
                    Annotation("Target", coordinate: tapPoint.coordinate) {
                        Circle()
                            .fill(.white)
                            .stroke(FairwayVectorColors.navy, lineWidth: 3)
                            .frame(width: 18, height: 18)
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.imagery(elevation: .flat))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .onTapGesture { screenPoint in
                if let coordinate = proxy.convert(screenPoint, from: .local) {
                    tapPoint = GeoPoint(coordinate)
                }
            }
        }
        .onAppear(perform: frameHole)
        .onChange(of: hole.number) { frameHole() }
    }

    /// Orients the camera so the hole plays bottom-to-top, leaving room for the distance card.
    private func frameHole() {
        guard let tee = hole.tee, let target = hole.greenCenter else { return }
        let length = GolfGeometry.distance(tee, target)
        let center = GolfGeometry.interpolate(tee, target, fraction: 0.4)
        position = .camera(
            MapCamera(
                centerCoordinate: center.coordinate,
                distance: max(length * 2.6, 300),
                heading: GolfGeometry.bearing(from: tee, to: target),
                pitch: 0
            )
        )
    }
}
