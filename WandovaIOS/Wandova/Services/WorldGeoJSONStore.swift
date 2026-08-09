//
//  WorldGeoJSONStore.swift
//  Wandova
//

import Foundation
import MapKit

/// Decodes the full-resolution world_countries.geojson exactly once and
/// builds both products consumed by the app — the per-country overlay
/// dictionary (tap hit-testing) and the Country list. Previously
/// CountryBoundaryService and CountryDataService each ran their own
/// 13 MB decode at startup.
final class WorldGeoJSONStore {
    static let shared = WorldGeoJSONStore()

    struct FullResolutionData {
        let overlaysByCountry: [String: [MKOverlay]]
        let countries: [Country]
    }

    private var cached: FullResolutionData?
    private let lock = NSLock()

    private init() {}

    func load() -> FullResolutionData {
        lock.lock()
        defer { lock.unlock() }

        if let cached {
            return cached
        }

        let objects = Self.decodeObjects(resource: "world_countries")
        let data = FullResolutionData(
            overlaysByCountry: CountryBoundaryService.shared.buildOverlays(from: objects),
            countries: CountryDataService.shared.buildCountries(from: objects)
        )
        cached = data
        return data
    }

    /// One decode of a bundled GeoJSON resource. The raw Data and the
    /// decoder are released when this returns; only what the builders
    /// keep survives.
    static func decodeObjects(resource: String) -> [MKGeoJSONObject] {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "geojson") else {
            print("⚠️ \(resource).geojson not found in bundle")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try MKGeoJSONDecoder().decode(data)
        } catch {
            print("❌ Failed to decode \(resource).geojson:", error)
            return []
        }
    }
}
