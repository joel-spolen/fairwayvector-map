import Testing
@testable import fairwayvector_map

struct TrajectoryIntegrationTests {
    @Test func bundledModelsPredictShot() throws {
        let predictor = try HybridPredictor()
        let shot = ShotInputs(
            ballSpeedMps: Units.mpsFromMph(150),
            launchAngleDeg: 12,
            launchDirectionDeg: 0,
            spinRateRpm: 2700,
            spinAxisDeg: 0
        )

        let prediction = try predictor.predict(shot)
        #expect((prediction.hybrid["carry_m"] ?? 0) > 0)
        #expect((prediction.hybrid["apex_m"] ?? 0) > 0)
    }
}