import SwiftUI

struct CourseWeatherCard: View {
    let location: GeoPoint
    let store: CourseWeatherStore

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "cloud.sun.fill")
                .font(.title3)
                .foregroundStyle(FairwayVectorColors.orange)
                .frame(width: 34, height: 34)
                .background(FairwayVectorColors.conditionsSurface, in: Circle())

            if let weather = store.weather {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 10) {
                        weatherValue("TEMP", weather.temperatureC.map { String(format: "%.0f°C", $0) } ?? "–")
                        weatherValue("HUMIDITY", weather.relativeHumidityPercent.map { String(format: "%.0f%%", $0) } ?? "–")
                        weatherValue("ELEVATION", weather.elevationMeters.map { String(format: "%.0f m", $0) } ?? "–")
                    }
                    HStack(spacing: 10) {
                        weatherValue("PRESSURE", weather.surfacePressureHpa.map { String(format: "%.0f hPa", $0) } ?? "–")
                        weatherValue("WIND", windText(weather))
                        if store.isLoading {
                            ProgressView().controlSize(.mini)
                        } else {
                            Button {
                                Task { await store.load(for: location, forceRefresh: true) }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption.weight(.semibold))
                            }
                            .accessibilityLabel("Refresh course weather")
                        }
                    }
                }
            } else if store.isLoading {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Course weather")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FairwayVectorColors.navy)
                    ProgressView("Loading current conditions…")
                        .font(.caption2)
                }
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Course weather unavailable")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FairwayVectorColors.navy)
                    if let errorMessage = store.errorMessage {
                        Text(errorMessage)
                            .font(.caption2)
                            .foregroundStyle(FairwayVectorColors.slate)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                Button("Retry") {
                    Task { await store.load(for: location, forceRefresh: true) }
                }
                .font(.caption.weight(.semibold))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .task(id: locationKey) {
            await store.load(for: location)
        }
        .accessibilityElement(children: .contain)
    }

    private var locationKey: String {
        String(format: "%.3f,%.3f", location.lat, location.lon)
    }

    private func weatherValue(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 7, weight: .semibold))
                .foregroundStyle(FairwayVectorColors.slate)
            Text(value)
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(FairwayVectorColors.charcoal)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func windText(_ weather: CourseWeather) -> String {
        guard let speed = weather.windSpeedMps else { return "–" }
        let direction = weather.windDirectionDegrees.map(cardinalDirection) ?? ""
        let gust = weather.windGustsMps.map { " · gust \(Int($0.rounded()))" } ?? ""
        return "\(Int(speed.rounded())) m/s from \(direction)\(gust)"
    }

    private func cardinalDirection(_ degrees: Double) -> String {
        let points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int(((degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 45).rounded()) % points.count
        return points[index]
    }
}
