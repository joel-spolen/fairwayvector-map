import MapKit
import SwiftUI

struct FlagPlacementView: View {
    let hole: Hole
    let initialFlag: GeoPoint
    let onSave: (GeoPoint) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var flag: GeoPoint
    @State private var cameraPosition: MapCameraPosition = .automatic

    init(hole: Hole, initialFlag: GeoPoint, onSave: @escaping (GeoPoint) -> Void) {
        self.hole = hole
        self.initialFlag = initialFlag
        self.onSave = onSave
        _flag = State(initialValue: initialFlag)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Tap the green or drag the flag to move it.")
                    .font(.subheadline)
                    .foregroundStyle(FairwayVectorColors.slate)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()

                MapReader { proxy in
                    Map(position: $cameraPosition, interactionModes: []) {
                        if hole.green.count >= 3 {
                            MapPolygon(coordinates: hole.green.map(\.coordinate))
                                .foregroundStyle(FairwayVectorColors.gold.opacity(0.3))
                                .stroke(FairwayVectorColors.gold, lineWidth: 2)
                        }

                        Annotation("Flag", coordinate: flag.coordinate, anchor: .bottom) {
                            Image(systemName: "flag.fill")
                                .font(.title2)
                                .foregroundStyle(FairwayVectorColors.orange)
                                .shadow(color: .black.opacity(0.3), radius: 2)
                                .frame(width: 44, height: 52)
                                .contentShape(Rectangle())
                        }
                        .annotationTitles(.hidden)
                    }
                    .mapStyle(.imagery(elevation: .flat))
                    .onTapGesture { screenPoint in
                        moveFlag(to: screenPoint, using: proxy)
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 8, coordinateSpace: .local)
                            .onChanged { value in
                                guard let markerPoint = proxy.convert(flag.coordinate, to: .local) else { return }
                                let dx = value.startLocation.x - markerPoint.x
                                let dy = value.startLocation.y - markerPoint.y
                                guard hypot(dx, dy) <= 44 else { return }
                                moveFlag(to: value.location, using: proxy)
                            }
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(FairwayVectorColors.background)
            .navigationTitle("Move Flag · Hole \(hole.number)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(flag) }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let center = hole.greenCenter {
                    let heading = hole.tee.map { GolfGeometry.bearing(from: $0, to: center) } ?? 0
                    cameraPosition = .camera(
                        MapCamera(centerCoordinate: center.coordinate, distance: 120, heading: heading, pitch: 0)
                    )
                }
            }
        }
    }

    private func moveFlag(to screenPoint: CGPoint, using proxy: MapProxy) {
        guard let coordinate = proxy.convert(screenPoint, from: .local) else { return }
        let candidate = GeoPoint(coordinate)
        guard hole.green.count >= 3, GolfGeometry.contains(candidate, in: hole.green) else { return }
        flag = candidate
    }
}
