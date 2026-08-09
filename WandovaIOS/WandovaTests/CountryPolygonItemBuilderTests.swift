//
//  CountryPolygonItemBuilderTests.swift
//  WandovaTests
//

import XCTest
import MapKit
@testable import Wandova

final class CountryPolygonItemBuilderTests: XCTestCase {

    // MARK: - Fixtures

    private func square(at origin: Double, hole: Bool = false) -> MKPolygon {
        let coords = [
            CLLocationCoordinate2D(latitude: origin, longitude: origin),
            CLLocationCoordinate2D(latitude: origin + 10, longitude: origin),
            CLLocationCoordinate2D(latitude: origin + 10, longitude: origin + 10),
            CLLocationCoordinate2D(latitude: origin, longitude: origin + 10)
        ]
        guard hole else { return MKPolygon(coordinates: coords, count: coords.count) }

        let holeCoords = [
            CLLocationCoordinate2D(latitude: origin + 4, longitude: origin + 4),
            CLLocationCoordinate2D(latitude: origin + 6, longitude: origin + 4),
            CLLocationCoordinate2D(latitude: origin + 6, longitude: origin + 6),
            CLLocationCoordinate2D(latitude: origin + 4, longitude: origin + 6)
        ]
        let interior = MKPolygon(coordinates: holeCoords, count: holeCoords.count)
        return MKPolygon(coordinates: coords, count: coords.count, interiorPolygons: [interior])
    }

    // MARK: - itemsByCountry

    func test_itemsByCountry_flattensMultiPolygonsAndKeepsStableIDs() {
        let overlays: [String: [MKOverlay]] = [
            "US": [square(at: 0), MKMultiPolygon([square(at: 20), square(at: 40)])],
            "TR": [square(at: 60)]
        ]

        let cache = CountryPolygonItemBuilder.itemsByCountry(from: overlays)

        XCTAssertEqual(cache["US"]?.map(\.id), ["US_0", "US_1", "US_2"])
        XCTAssertEqual(cache["TR"]?.map(\.id), ["TR_0"])
        XCTAssertEqual(cache["US"]?.map(\.countryID), ["US", "US", "US"])
    }

    func test_itemsByCountry_preservesInteriorPolygons() {
        let holed = square(at: 0, hole: true)
        let cache = CountryPolygonItemBuilder.itemsByCountry(from: ["ZA": [holed]])

        let item = cache["ZA"]?.first
        XCTAssertNotNil(item)
        // Same object, not a copy — holes ride along untouched.
        XCTAssertTrue(item?.polygon === holed)
        XCTAssertEqual(item?.polygon.interiorPolygons?.count, 1)
    }

    func test_itemsByCountry_multiPolygonSubPolygonsKeepTheirHoles() {
        let holed = square(at: 0, hole: true)
        let multi = MKMultiPolygon([holed, square(at: 20)])
        let cache = CountryPolygonItemBuilder.itemsByCountry(from: ["ID": [multi]])

        XCTAssertEqual(cache["ID"]?.count, 2)
        XCTAssertEqual(cache["ID"]?.first?.polygon.interiorPolygons?.count, 1)
    }

    // MARK: - items(for:in:)

    func test_items_sortedByCountryCode_regardlessOfSetOrder() {
        let cache = CountryPolygonItemBuilder.itemsByCountry(from: [
            "US": [square(at: 0)],
            "AR": [square(at: 20)],
            "TR": [square(at: 40)]
        ])

        // Sets built in different insertion orders must yield the same list.
        let a = CountryPolygonItemBuilder.items(for: Set(["US", "AR", "TR"]), in: cache)
        let b = CountryPolygonItemBuilder.items(for: Set(["TR", "US", "AR"]), in: cache)

        XCTAssertEqual(a.map(\.id), ["AR_0", "TR_0", "US_0"])
        XCTAssertEqual(a.map(\.id), b.map(\.id))
    }

    func test_items_onlyIncludesActiveCountries_andIgnoresUnknownCodes() {
        let cache = CountryPolygonItemBuilder.itemsByCountry(from: [
            "US": [square(at: 0)],
            "TR": [square(at: 20)]
        ])

        let items = CountryPolygonItemBuilder.items(for: Set(["TR", "XX"]), in: cache)
        XCTAssertEqual(items.map(\.id), ["TR_0"])
    }

    func test_items_returnsCachedPolygonReferences_noCopying() {
        let polygon = square(at: 0)
        let cache = CountryPolygonItemBuilder.itemsByCountry(from: ["US": [polygon]])

        let first = CountryPolygonItemBuilder.items(for: ["US"], in: cache)
        let second = CountryPolygonItemBuilder.items(for: ["US"], in: cache)
        XCTAssertTrue(first.first?.polygon === polygon)
        XCTAssertTrue(second.first?.polygon === polygon)
    }
}
