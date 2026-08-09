//
//  CountryPolygonItems.swift
//  Wandova
//

import MapKit

/// One renderable polygon of a country. `polygon` is a reference into the
/// cached simplified geometry, interiorPolygons (holes) included — building
/// and concatenating items never copies coordinates.
struct CountryPolygonItem: Identifiable {
    let id: String
    let polygon: MKPolygon
    let countryID: String
}

/// A zoom request from the UI to the map. Carries a fresh identity so
/// repeating the same target latDelta still triggers `.onChange`.
struct MapZoomCommand: Equatable {
    let id: UUID
    let latDelta: Double

    init(latDelta: Double) {
        self.id = UUID()
        self.latDelta = latDelta
    }
}

enum CountryPolygonItemBuilder {
    /// Flattens the overlay dictionary into per-country item lists, exactly
    /// once at load. MKMultiPolygons are split into their sub-polygons; each
    /// sub-polygon keeps its own interiorPolygons.
    static func itemsByCountry(from overlaysByCountry: [String: [MKOverlay]]) -> [String: [CountryPolygonItem]] {
        var result: [String: [CountryPolygonItem]] = [:]
        result.reserveCapacity(overlaysByCountry.count)
        for (countryID, overlays) in overlaysByCountry {
            var items: [CountryPolygonItem] = []
            var idx = 0
            for overlay in overlays {
                if let polygon = overlay as? MKPolygon {
                    items.append(CountryPolygonItem(id: "\(countryID)_\(idx)", polygon: polygon, countryID: countryID))
                    idx += 1
                } else if let multiPolygon = overlay as? MKMultiPolygon {
                    for subPolygon in multiPolygon.polygons {
                        items.append(CountryPolygonItem(id: "\(countryID)_\(idx)", polygon: subPolygon, countryID: countryID))
                        idx += 1
                    }
                }
            }
            if !items.isEmpty {
                result[countryID] = items
            }
        }
        return result
    }

    /// Render list for the active countries, sorted by country code so the
    /// output order is deterministic — Set iteration order must never leak
    /// into the ForEach, or identical inputs produce spurious reorder diffs.
    static func items(for activeCountryIDs: Set<String>, in cache: [String: [CountryPolygonItem]]) -> [CountryPolygonItem] {
        activeCountryIDs.sorted().flatMap { cache[$0] ?? [] }
    }
}
