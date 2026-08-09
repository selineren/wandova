//
//  WorldGeoJSONStoreTests.swift
//  WandovaTests
//

import XCTest
import MapKit
@testable import Wandova

final class WorldGeoJSONStoreTests: XCTestCase {

    func test_load_producesBothProductsFromOneDecode() {
        let data = WorldGeoJSONStore.shared.load()

        XCTAssertGreaterThan(data.overlaysByCountry.count, 150)
        XCTAssertGreaterThan(data.countries.count, 150)
        XCTAssertEqual(data.countries.map(\.name), data.countries.map(\.name).sorted())
        XCTAssertEqual(Set(data.countries.map(\.id)).count, data.countries.count, "country IDs must be unique")
    }

    func test_load_isCached_repeatCallsReturnSameObjects() {
        let first = WorldGeoJSONStore.shared.load()
        let second = WorldGeoJSONStore.shared.load()

        guard let a = first.overlaysByCountry["US"]?.first,
              let b = second.overlaysByCountry["US"]?.first else {
            return XCTFail("expected US overlays")
        }
        XCTAssertTrue(a === b, "repeat load() must return the cached decode, not re-parse")
    }

    func test_services_delegateToSharedStore() {
        let store = WorldGeoJSONStore.shared.load()

        XCTAssertEqual(CountryDataService.shared.loadCountries(), store.countries)

        guard let viaService = CountryBoundaryService.shared.getCountryOverlays()["US"]?.first,
              let viaStore = store.overlaysByCountry["US"]?.first else {
            return XCTFail("expected US overlays")
        }
        XCTAssertTrue(viaService === viaStore)
    }
}

final class MapZoomStateTests: XCTestCase {

    func test_zoomUIState_thresholds() {
        XCTAssertTrue(MapZoomUIState(latDelta: 89.9).showBitmojis)
        XCTAssertFalse(MapZoomUIState(latDelta: 90).showBitmojis)

        XCTAssertTrue(MapZoomUIState(latDelta: 0.51).canZoomIn)
        XCTAssertFalse(MapZoomUIState(latDelta: 0.5).canZoomIn)

        XCTAssertTrue(MapZoomUIState(latDelta: 169.9).canZoomOut)
        XCTAssertFalse(MapZoomUIState(latDelta: 170).canZoomOut)
    }

    func test_zoomUIState_equalWithinSameBand_soCameraSettlesDontInvalidate() {
        XCTAssertEqual(MapZoomUIState(latDelta: 10), MapZoomUIState(latDelta: 80))
        XCTAssertNotEqual(MapZoomUIState(latDelta: 80), MapZoomUIState(latDelta: 95))
    }

    func test_zoomCommand_freshIdentity_soRepeatedTargetsStillFireOnChange() {
        XCTAssertNotEqual(MapZoomCommand(latDelta: 30), MapZoomCommand(latDelta: 30))
    }
}
