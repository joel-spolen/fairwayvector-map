import MapKit
import SwiftUI

struct HoleMapView: View {
    let hole: Hole
    let origin: GeoPoint?
    let usesGPS: Bool
    @Binding var tapPoint: GeoPoint?

    @State private var position: MapCameraPosition = .automatic
    @State private var cameraRevision = 0

    var body: some View {
        MapReader { proxy in
            Map(position: $position, bounds: cameraBounds, interactionModes: [.zoom]) {
                if usesGPS {
                    UserAnnotation()
                }

                if let tee = hole.tee {
                    Annotation(usesGPS ? "Tee" : "You", coordinate: tee.coordinate, anchor: .bottom) {
                        VStack(spacing: 3) {
                            Text(usesGPS ? "TEE" : "YOU")
                                .font(.caption2.bold())
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(FairwayVectorColors.surface, in: Capsule())
                            Image(systemName: "mappin.and.ellipse")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(usesGPS ? FairwayVectorColors.navy : FairwayVectorColors.orange)
                                .shadow(color: .black.opacity(0.3), radius: 2)
                        }
                    }
                    .annotationTitles(.hidden)
                }

                ForEach(Array(hole.roughs.enumerated()), id: \.offset) { _, polygon in
                    MapPolygon(coordinates: polygon.map(\.coordinate))
                        .foregroundStyle(FairwayVectorColors.flightBlue.opacity(0.10))
                }

                ForEach(Array(hole.fairways.enumerated()), id: \.offset) { _, polygon in
                    MapPolygon(coordinates: polygon.map(\.coordinate))
                        .foregroundStyle(FairwayVectorColors.gold.opacity(0.12))
                }

                if highlightBoundary.count >= 3 {
                    MapPolyline(coordinates: (highlightBoundary + [highlightBoundary[0]]).map(\.coordinate))
                        .stroke(FairwayVectorColors.gold.opacity(0.42), style: StrokeStyle(lineWidth: 7, lineJoin: .round))
                    MapPolyline(coordinates: (highlightBoundary + [highlightBoundary[0]]).map(\.coordinate))
                        .stroke(FairwayVectorColors.surface.opacity(0.92), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
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
                        ZStack {
                            Circle()
                                .fill(FairwayVectorColors.navy.opacity(0.18))
                                .frame(width: 48, height: 48)
                            Circle()
                                .fill(.white)
                                .stroke(FairwayVectorColors.navy, lineWidth: 3)
                                .frame(width: 22, height: 22)
                            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(FairwayVectorColors.navy)
                        }
                        .contentShape(Circle())
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .named("holeMap"))
                                .onChanged { value in
                                    if let coordinate = proxy.convert(value.location, from: .named("holeMap")) {
                                        self.tapPoint = GeoPoint(coordinate)
                                    }
                                }
                        )
                    }
                    .annotationTitles(.hidden)
                }
            }
            .coordinateSpace(name: "holeMap")
            .mapStyle(.imagery(elevation: .flat))
            .onMapCameraChange(frequency: .continuous) { _ in
                cameraRevision &+= 1
            }
            .overlay {
                Canvas { context, size in
                    guard !visibleAreaPolygons.isEmpty else { return }
                    context.drawLayer { layer in
                        layer.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.45)))
                        layer.blendMode = .destinationOut
                        for polygon in visibleAreaPolygons {
                            guard let first = polygon.first,
                                  let firstPoint = proxy.convert(first.coordinate, to: .local) else { continue }
                            var cutout = Path()
                            cutout.move(to: firstPoint)
                            for point in polygon.dropFirst() {
                                guard let screenPoint = proxy.convert(point.coordinate, to: .local) else { continue }
                                cutout.addLine(to: screenPoint)
                            }
                            cutout.closeSubpath()
                            layer.fill(cutout, with: .color(.black))
                        }
                    }
                }
                .id(cameraRevision)
                .allowsHitTesting(false)
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

    private var holeCoordinates: [CLLocationCoordinate2D] {
        (hole.path + hole.green).map(\.coordinate)
    }

    private var boundaryPolygons: [[GeoPoint]] {
        if !hole.roughs.isEmpty { return hole.roughs }
        if !hole.fairways.isEmpty { return hole.fairways }
        let fallback = GolfGeometry.corridorBoundary(for: hole.path)
        return fallback.isEmpty ? [] : [fallback]
    }

    private var highlightBoundary: [GeoPoint] {
        let polygons = boundaryPolygons + teeConnectors
        guard polygons.count > 1 else { return polygons.first ?? [] }
        return GolfGeometry.convexHull(of: polygons)
    }

    private var visibleAreaPolygons: [[GeoPoint]] {
        highlightBoundary.count >= 3 ? [highlightBoundary] : boundaryPolygons
    }

    private var teeConnectors: [[GeoPoint]] {
        let playableAreas = hole.roughs + hole.fairways
        guard !hole.tees.isEmpty, !playableAreas.isEmpty else { return [] }
        return hole.tees.compactMap { teePolygon in
            guard let teeCenter = GolfGeometry.centroid(of: teePolygon) else { return nil }
            let teeRadius = teePolygon.map { GolfGeometry.distance(teeCenter, $0) }.max() ?? 0
            let nearestAreaPoint = playableAreas
                .compactMap { polygon -> (point: GeoPoint, distance: Double)? in
                    guard let nearest = GolfGeometry.nearestPoint(onPath: polygon + [polygon[0]], to: teeCenter) else { return nil }
                    return (nearest, GolfGeometry.distance(teeCenter, nearest))
                }
                .min { $0.distance < $1.distance }?
                .point
            guard let nearestAreaPoint else { return nil }
            let boundary = GolfGeometry.smoothConnectorBoundary(
                from: teeCenter,
                to: nearestAreaPoint,
                radius: max(teeRadius + 5, 22)
            )
            return boundary.count >= 3 ? boundary : nil
        }
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
        return max(GolfGeometry.distance(tee, target) * 3.5, 400)
    }

    /// Keeps the hole framed while preventing the camera from escaping the active hole bounds.
    private func frameHole() {
        guard let tee = hole.tee, let target = hole.greenCenter else { return }
        let length = GolfGeometry.distance(tee, target)
        let center = GolfGeometry.interpolate(tee, target, fraction: 0.52)
        position = .camera(
            MapCamera(
                centerCoordinate: center.coordinate,
            distance: min(max(length * 3, 400), maximumCameraDistance),
                heading: GolfGeometry.bearing(from: tee, to: target),
                pitch: 0
            )
        )
    }
}
