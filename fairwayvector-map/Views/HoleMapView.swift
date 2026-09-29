import MapKit
import SwiftUI

struct HoleMapView: View {
    let hole: Hole
    let origin: GeoPoint?
    @Binding var tapPoint: GeoPoint?

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        MapReader { proxy in
            Map(position: $position, bounds: cameraBounds, interactionModes: [.zoom]) {
                UserAnnotation()

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
            .onTapGesture { screenPoint in
                if let coordinate = proxy.convert(screenPoint, from: .local) {
                    tapPoint = GeoPoint(coordinate)
                }
            }
        }
        .onAppear(perform: frameHole)
        .onChange(of: hole.number) { frameHole() }
    }

    private var holeCoordinates: [CLLocationCoordinate2D] {
        (hole.path + hole.green).map(\.coordinate)
    }

    private var holeRect: MKMapRect {
        guard let first = holeCoordinates.first else { return .world }
        var rect = MKMapRect(origin: MKMapPoint(first), size: MKMapSize(width: 0, height: 0))
        for coordinate in holeCoordinates.dropFirst() {
            rect = rect.union(MKMapRect(origin: MKMapPoint(coordinate), size: MKMapSize(width: 0, height: 0)))
        }
        let paddingX = max(rect.size.width * 0.1, 18)
        let paddingY = max(rect.size.height * 0.1, 18)
        return rect.insetBy(dx: -paddingX, dy: -paddingY)
    }

    private var cameraBounds: MapCameraBounds {
        MapCameraBounds(
            centerCoordinateBounds: holeRect,
            minimumDistance: 100,
            maximumDistance: maximumCameraDistance
        )
    }

    private var maximumCameraDistance: Double {
        guard let tee = hole.tee, let target = hole.greenCenter else { return 500 }
        return max(GolfGeometry.distance(tee, target) * 3.2, 400)
    }

    /// Keeps the hole framed while preventing the camera from escaping the active hole bounds.
    private func frameHole() {
        guard let tee = hole.tee, let target = hole.greenCenter else { return }
        let length = GolfGeometry.distance(tee, target)
        let center = GolfGeometry.interpolate(tee, target, fraction: 0.4)
        position = .camera(
            MapCamera(
                centerCoordinate: center.coordinate,
                distance: min(max(length * 2.6, 300), maximumCameraDistance),
                heading: GolfGeometry.bearing(from: tee, to: target),
                pitch: 0
            )
        )
    }
}
