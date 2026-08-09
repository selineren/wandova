//
//  VisitDocumentMapperTests.swift
//  WandovaTests
//

import XCTest
import FirebaseFirestore
@testable import Wandova

final class VisitDocumentMapperTests: XCTestCase {

    func test_visit_normalDocumentWithNoLegacyField_mapsAllFields() throws {
        let data: [String: Any] = [
            "isVisited": true,
            "wantToVisit": false,
            "visitedDate": Timestamp(date: date(500)),
            "notes": "great trip",
            "updatedAt": Timestamp(date: date(1000))
        ]

        let visit = try VisitDocumentMapper.visit(countryId: "TR", data: data)

        XCTAssertEqual(visit.countryId, "TR")
        XCTAssertTrue(visit.isVisited)
        XCTAssertFalse(visit.wantToVisit)
        XCTAssertEqual(visit.visitedDate, date(500))
        XCTAssertEqual(visit.notes, "great trip")
        XCTAssertEqual(visit.updatedAt, date(1000))
        XCTAssertEqual(visit.photos, [])
    }

    func test_visit_neverReturnsPhotoPayload_evenIfDocumentCarriesPhotosField() throws {
        // Compare fetches other users' visit documents in bulk; the mapper must
        // never surface image bytes from them, whatever the document contains.
        let strayPhotos = try JSONEncoder().encode(
            [VisitPhoto(imageData: Data("jpeg-bytes".utf8), caption: "should never decode")]
        )
        let data: [String: Any] = [
            "isVisited": true,
            "wantToVisit": false,
            "notes": "",
            "updatedAt": Timestamp(date: date(1000)),
            "photos": strayPhotos.base64EncodedString()
        ]

        let visit = try VisitDocumentMapper.visit(countryId: "TR", data: data)

        XCTAssertEqual(visit.photos, [], "metadata documents must map with no photo payload")
    }

    func test_visit_missingRequiredFields_throwsInvalidData() {
        XCTAssertThrowsError(
            try VisitDocumentMapper.visit(countryId: "TR", data: ["updatedAt": Timestamp(date: date(1000))])
        )
        XCTAssertThrowsError(
            try VisitDocumentMapper.visit(countryId: "TR", data: ["isVisited": true])
        )
    }

    func test_visit_bothStatesTrue_resolvesToVisitedOnly() throws {
        let data: [String: Any] = [
            "isVisited": true,
            "wantToVisit": true,
            "notes": "",
            "updatedAt": Timestamp(date: date(1000))
        ]

        let visit = try VisitDocumentMapper.visit(countryId: "TR", data: data)

        XCTAssertTrue(visit.isVisited)
        XCTAssertFalse(visit.wantToVisit, "corrupted double-true state resolves to visited")
        XCTAssertEqual(visit.visitedDate, date(1000), "visited without a date falls back to updatedAt")
    }
}
