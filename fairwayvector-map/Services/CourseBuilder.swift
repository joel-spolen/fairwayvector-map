import Foundation

enum CourseBuilderError: LocalizedError {
    case noHoles

    var errorDescription: String? {
        "No mapped holes were found for this course in OpenStreetMap."
    }
}

enum CourseBuilder {
    static func build(reference: CourseReference, elements: [OverpassElement], fetchedAt: Date = .now) throws -> Course {
        let greens: [[GeoPoint]] = elements
            .filter { $0.type == "way" && $0.tags?["golf"] == "green" }
            .compactMap { $0.geometry }
            .filter { $0.count >= 3 }

        let pins: [GeoPoint] = elements
            .filter { $0.type == "node" && $0.tags?["golf"] == "pin" }
            .compactMap { element in
                guard let lat = element.lat, let lon = element.lon else { return nil }
                return GeoPoint(lat: lat, lon: lon)
            }

        let holes: [Hole] = elements
            .filter { $0.type == "way" && $0.tags?["golf"] == "hole" }
            .compactMap { element in
                guard let number = element.tags?["ref"].flatMap({ Int($0) }),
                      let path = element.geometry, path.count >= 2,
                      let end = path.last else { return nil }
                let green = matchGreen(for: end, in: greens) ?? []
                let pin = pins.first { GolfGeometry.contains($0, in: green) }
                return Hole(
                    number: number,
                    par: element.tags?["par"].flatMap { Int($0) },
                    path: path,
                    green: green,
                    pin: pin
                )
            }
            .sorted { $0.number < $1.number }

        guard !holes.isEmpty else { throw CourseBuilderError.noHoles }
        return Course(osmRelationID: reference.osmRelationID, name: reference.name, holes: holes, fetchedAt: fetchedAt)
    }

    private static func matchGreen(for end: GeoPoint, in greens: [[GeoPoint]]) -> [GeoPoint]? {
        if let containing = greens.first(where: { GolfGeometry.contains(end, in: $0) }) {
            return containing
        }
        let maxMatchDistance = 60.0
        return greens
            .compactMap { green -> (green: [GeoPoint], distance: Double)? in
                guard let center = GolfGeometry.centroid(of: green) else { return nil }
                return (green, GolfGeometry.distance(center, end))
            }
            .filter { $0.distance <= maxMatchDistance }
            .min { $0.distance < $1.distance }?
            .green
    }
}
