//
//  SyncServiceTests.swift
//  WandovaTests
//

import XCTest
@testable import Wandova

final class SyncServiceTests: XCTestCase {

    private var local: MockLocalRepository!
    private var cloud: MockCloudRepository!

    override func setUp() {
        super.setUp()
        local = MockLocalRepository()
        cloud = MockCloudRepository()
    }

    private func makeService(isAuthenticated: Bool = true) -> SyncService {
        SyncService(
            localRepository: local,
            cloudRepository: cloud,
            isAuthenticated: { isAuthenticated }
        )
    }

    // MARK: - Cloud overwrite must preserve device photos

    func test_sync_cloudOverwrite_preservesExistingLocalPhotos() async throws {
        // The dangerous case: the device photo has NOT reached the cloud photo
        // subcollection yet. If the metadata overwrite wipes local photos, the
        // photo is unrecoverable — phase 2 reads the wiped state and never uploads it.
        let devicePhoto = makePhoto(caption: "device photo")
        local.visits["TR"] = makeVisit(notes: "old local", photos: [devicePhoto], updatedAt: date(1000))
        cloud.cloudVisits = [makeVisit(notes: "newer cloud", photos: [], updatedAt: date(2000))]

        try await makeService().syncVisits(withRetry: false)

        let saved = try local.visit(for: "TR")
        XCTAssertEqual(saved.notes, "newer cloud", "cloud metadata should win")
        XCTAssertEqual(saved.updatedAt, date(2000))
        XCTAssertEqual(saved.photos, [devicePhoto], "cloud overwrite must not wipe device photos")
        XCTAssertEqual(cloud.uploadedPhotoIds, [devicePhoto.id], "preserved photo should then upload in the photo phase")
    }

    // MARK: - Photo union-merge across devices

    func test_sync_photoUnion_uploadsLocalOnly_downloadsCloudOnly() async throws {
        let localPhoto = makePhoto(caption: "taken on this device")
        let cloudPhoto = makePhoto(caption: "taken on other device")
        // Same updatedAt: metadata is in sync, only photos differ.
        local.visits["TR"] = makeVisit(photos: [localPhoto], updatedAt: date(1000))
        cloud.cloudVisits = [makeVisit(updatedAt: date(1000))]
        cloud.cloudPhotos["TR"] = [cloudPhoto]

        try await makeService().syncVisits(withRetry: false)

        XCTAssertTrue(cloud.setVisitCountryIds.isEmpty, "equal timestamps must not write metadata")
        XCTAssertEqual(cloud.uploadedPhotoIds, [localPhoto.id], "local-only photo uploads")
        XCTAssertEqual(cloud.cloudPhotos["TR"]?.map(\.id), [cloudPhoto.id, localPhoto.id])
        XCTAssertEqual(
            try local.visit(for: "TR").photos.map(\.id),
            [localPhoto.id, cloudPhoto.id],
            "cloud-only photo comes down to the device"
        )
    }

    func test_sync_doesNotResurrectPhotoDeletedViaDeleteCloudPhoto() async throws {
        // Photo existed on both sides, then the user deleted it on this device:
        // the app removes it locally and calls deleteCloudPhoto.
        let deleted = makePhoto(caption: "deleted by user")
        local.visits["TR"] = makeVisit(photos: [], updatedAt: date(1000))
        cloud.cloudVisits = [makeVisit(updatedAt: date(1000))]
        cloud.cloudPhotos["TR"] = [deleted]

        let service = makeService()
        await service.deleteCloudPhoto(countryId: "TR", photoId: deleted.id)
        try await service.syncVisits(withRetry: false)

        XCTAssertEqual(cloud.deletedPhotoIds, [deleted.id])
        XCTAssertEqual(try local.visit(for: "TR").photos, [], "deleted photo must not come back down")
        XCTAssertTrue(cloud.uploadedPhotoIds.isEmpty, "deleted photo must not be re-uploaded")
        XCTAssertEqual(cloud.cloudPhotos["TR"] ?? [], [], "deleted photo must stay deleted in the cloud")
    }

    // MARK: - Per-country failures

    func test_sync_countryFailure_continuesWithOthers_andSurfacesPartialFailure() async throws {
        struct CountryWriteFailed: Error {}
        local.visits["TR"] = makeVisit(countryId: "TR", updatedAt: date(1000))
        local.visits["FR"] = makeVisit(countryId: "FR", updatedAt: date(1000))
        local.visits["DE"] = makeVisit(countryId: "DE", updatedAt: date(1000))
        cloud.setVisitErrorByCountry["FR"] = CountryWriteFailed()

        do {
            try await makeService().syncVisits(withRetry: false)
            XCTFail("expected sync to throw")
        } catch let SyncError.syncFailed(underlying, attempts) {
            XCTAssertEqual(attempts, 1)
            XCTAssertEqual(
                underlying as? SyncError,
                .partialFailure(syncedCount: 2, failedCount: 1),
                "one country failed, two synced"
            )
        }

        XCTAssertEqual(cloud.setVisitCountryIds.sorted(), ["DE", "TR"], "sync must continue past the failing country")
    }

    // MARK: - Auth and retry behavior

    func test_sync_whenNotAuthenticated_throwsWithoutTouchingCloud() async {
        local.visits["TR"] = makeVisit(updatedAt: date(1000))

        do {
            try await makeService(isAuthenticated: false).syncVisits()
            XCTFail("expected sync to throw")
        } catch {
            XCTAssertEqual(error as? FirestoreVisitRepositoryError, .notAuthenticated)
        }

        XCTAssertEqual(cloud.allVisitsCallCount, 0, "unauthenticated sync must not hit the network")
    }

    func test_sync_genericError_isRetried_maxThreeAttempts() async {
        struct TransientServerError: Error {}
        cloud.allVisitsError = TransientServerError()

        do {
            try await makeService().syncVisits(withRetry: true)
            XCTFail("expected sync to throw")
        } catch let SyncError.syncFailed(underlying, attempts) {
            XCTAssertEqual(attempts, 3)
            XCTAssertTrue(underlying is TransientServerError)
        } catch {
            XCTFail("expected syncFailed, got \(error)")
        }

        XCTAssertEqual(cloud.allVisitsCallCount, 3, "generic errors should be retried exactly maxRetries times")
    }

    func test_sync_offlineError_surfacesNoConnection_andIsNotRetried() async {
        cloud.allVisitsError = FirestoreVisitRepositoryError.offline

        do {
            try await makeService().syncVisits(withRetry: true)
            XCTFail("expected sync to throw")
        } catch {
            XCTAssertEqual(error as? SyncError, .noConnection)
        }

        XCTAssertEqual(cloud.allVisitsCallCount, 1, "network errors must not be retried")
    }

    func test_sync_authErrorMidSync_isNotRetried() async {
        cloud.allVisitsError = FirestoreVisitRepositoryError.notAuthenticated

        do {
            try await makeService().syncVisits(withRetry: true)
            XCTFail("expected sync to throw")
        } catch {
            XCTAssertEqual(error as? FirestoreVisitRepositoryError, .notAuthenticated)
        }

        XCTAssertEqual(cloud.allVisitsCallCount, 1, "auth errors must not be retried")
    }
}
