//
//  SyncResolverTests.swift
//  WandovaTests
//

import XCTest
@testable import Wandova

final class SyncResolverTests: XCTestCase {

    // MARK: - merge: both sides present

    func test_merge_newerLocalWins_pushesLocalToCloud() {
        let local = makeVisit(notes: "local edit", updatedAt: date(2000))
        let remote = makeVisit(notes: "stale cloud", updatedAt: date(1000))

        let resolution = SyncResolver.merge(local: local, remote: remote)

        XCTAssertEqual(resolution, .pushToCloud(local))
    }

    func test_merge_newerCloudWins_savesCloudToLocal() {
        let local = makeVisit(notes: "stale local", updatedAt: date(1000))
        let remote = makeVisit(notes: "cloud edit", updatedAt: date(2000))

        let resolution = SyncResolver.merge(local: local, remote: remote)

        XCTAssertEqual(resolution, .saveToLocal(remote))
    }

    func test_merge_equalTimestamps_isNoChange_evenWhenContentDiffers() {
        let local = makeVisit(notes: "local", updatedAt: date(1500))
        let remote = makeVisit(notes: "cloud", updatedAt: date(1500))

        let resolution = SyncResolver.merge(local: local, remote: remote)

        XCTAssertEqual(resolution, .noChange)
    }

    // MARK: - merge: one side missing

    func test_merge_localOnly_pushesToCloud() {
        let local = makeVisit(notes: "only exists on device", updatedAt: date(1000))

        let resolution = SyncResolver.merge(local: local, remote: nil)

        XCTAssertEqual(resolution, .pushToCloud(local))
    }

    func test_merge_cloudOnly_savesToLocal() {
        let remote = makeVisit(notes: "only exists in cloud", updatedAt: date(1000))

        let resolution = SyncResolver.merge(local: nil, remote: remote)

        XCTAssertEqual(resolution, .saveToLocal(remote))
    }

    func test_merge_bothMissing_isNoChange() {
        XCTAssertEqual(SyncResolver.merge(local: nil, remote: nil), .noChange)
    }

    // MARK: - applyingLocalPhotos (cloud overwrite must not wipe device photos)

    func test_applyingLocalPhotos_cloudOverwrite_keepsExistingLocalPhotos() {
        let devicePhoto = makePhoto(caption: "on device")
        let existing = makeVisit(notes: "old local", photos: [devicePhoto], updatedAt: date(1000))
        // Cloud metadata docs carry no photos — a naive overwrite would wipe them.
        let remote = makeVisit(notes: "new cloud", photos: [], updatedAt: date(2000))

        let merged = SyncResolver.applyingLocalPhotos(from: existing, to: remote)

        XCTAssertEqual(merged.photos, [devicePhoto])
        XCTAssertEqual(merged.notes, "new cloud")
        XCTAssertEqual(merged.updatedAt, date(2000))
    }

    func test_applyingLocalPhotos_noLocalPhotos_keepsLegacyCloudPhotos() {
        let legacyCloudPhoto = makePhoto(caption: "legacy firestore field")
        let existing = makeVisit(photos: [], updatedAt: date(1000))
        let remote = makeVisit(photos: [legacyCloudPhoto], updatedAt: date(2000))

        XCTAssertEqual(
            SyncResolver.applyingLocalPhotos(from: existing, to: remote).photos,
            [legacyCloudPhoto]
        )
        XCTAssertEqual(
            SyncResolver.applyingLocalPhotos(from: nil, to: remote).photos,
            [legacyCloudPhoto]
        )
    }
}

// MARK: - Photo union-merge by ID

final class SyncResolverPhotoMergeTests: XCTestCase {

    func test_mergePhotos_localOnlyUploads_cloudOnlyComesDown() {
        let localOnly = makePhoto(caption: "local only")
        let shared = makePhoto(caption: "on both sides")
        let cloudOnly = makePhoto(caption: "cloud only")

        let result = SyncResolver.mergePhotos(
            local: [localOnly, shared],
            cloud: [shared, cloudOnly]
        )

        XCTAssertEqual(result.toUpload, [localOnly], "only the local-only photo should upload")
        XCTAssertEqual(result.merged, [localOnly, shared, cloudOnly], "union by ID, no duplicates")
    }
}

// MARK: - Helpers

func makeVisit(
    countryId: String = "TR",
    isVisited: Bool = true,
    wantToVisit: Bool = false,
    notes: String = "",
    photos: [VisitPhoto] = [],
    updatedAt: Date
) -> Visit {
    Visit(
        countryId: countryId,
        isVisited: isVisited,
        wantToVisit: wantToVisit,
        visitedDate: nil,
        notes: notes,
        photos: photos,
        updatedAt: updatedAt
    )
}

func date(_ seconds: TimeInterval) -> Date {
    Date(timeIntervalSince1970: seconds)
}

func makePhoto(caption: String = "") -> VisitPhoto {
    VisitPhoto(imageData: Data(caption.utf8), caption: caption, createdAt: date(0))
}
