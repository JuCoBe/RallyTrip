import XCTest
@testable import RallyCore

final class StorageTests: XCTestCase {
    func testRideRoundTripPreservesSegmentsAndDisconnectedPaths() throws {
        let point = GPSPoint(latitude: 48.1, longitude: 11.5, speedMPS: 12, accuracy: 3)
        let ride = SavedRide(name: "WP 03", startedAt: Date(), elapsed: 600,
                             totalMeters: 8000, rawMeters: 7900, calibrationFactor: 1.01,
                             segments: RegularitySegment.example, paths: [[point], [point]],
                             isDemo: false, finalDeviation: 0.66)
        let decoded = try JSONDecoder().decode(SavedRide.self, from: JSONEncoder().encode(ride))
        XCTAssertEqual(decoded.id, ride.id)
        XCTAssertEqual(decoded.paths, ride.paths)
        XCTAssertEqual(decoded.segments, ride.segments)
        XCTAssertEqual(decoded.finalDeviation, 0.66)
        XCTAssertEqual(decoded.totalMeters, 8000)
    }
}
