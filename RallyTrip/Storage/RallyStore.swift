import Foundation

struct AppSettings: Codable {
    var theme = "Dunkel"
    var sound = true
    var haptics = true
    var keepAwake = true
    var profiles = [CalibrationProfile(name: "Mein Fahrzeug")]
    var selectedProfile: UUID?
    var segments = RegularitySegment.example
    var roadbook: [RoadbookPoint] = []

    var profile: CalibrationProfile {
        profiles.first { $0.id == selectedProfile } ?? profiles.first ?? CalibrationProfile(name: "Mein Fahrzeug")
    }
}

struct StoredData: Codable {
    var version = 1
    var settings = AppSettings()
    var rides: [SavedRide] = []
}

enum RallyStore {
    static var url: URL {
        URL.documentsDirectory.appending(path: "rallytrip.json")
    }
    static func load() throws -> StoredData {
        guard FileManager.default.fileExists(atPath: url.path) else { return StoredData() }
        return try JSONDecoder().decode(StoredData.self, from: Data(contentsOf: url))
    }
    static func save(_ data: StoredData) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(data).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
