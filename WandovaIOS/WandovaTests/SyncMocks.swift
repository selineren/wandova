//
//  SyncMocks.swift
//  WandovaTests
//

import Foundation
@testable import Wandova

/// In-memory stand-in for the SwiftData-backed local store.
final class MockLocalRepository: VisitRepository {
    var visits: [String: Visit] = [:]
    private(set) var upserted: [Visit] = []

    struct NotFound: Error {}

    func visit(for countryId: String) throws -> Visit {
        guard let visit = visits[countryId] else { throw NotFound() }
        return visit
    }

    func allVisits() throws -> [Visit] {
        Array(visits.values)
    }

    func upsert(_ visit: Visit) throws {
        visits[visit.countryId] = visit
        upserted.append(visit)
    }

    // Unused by SyncService.
    func setVisited(_ countryId: String, isVisited: Bool, visitedDate: Date?) throws {}
    func setWantToVisit(_ countryId: String, wantToVisit: Bool) throws {}
    func updateNotes(_ countryId: String, notes: String) throws {}
    func addPhoto(_ countryId: String, photo: VisitPhoto) throws {}
    func removePhoto(_ countryId: String, photoId: UUID) throws {}
    func updatePhotoCaption(_ countryId: String, photoId: UUID, caption: String) throws {}
    func visitedCount() throws -> Int { visits.values.filter(\.isVisited).count }
    func deleteAllVisits() throws { visits = [:] }
}

/// In-memory stand-in for Firestore: visit metadata plus a per-country photo
/// store mirroring the photos subcollection. `syncPhotos` uses the production
/// `SyncResolver.mergePhotos` rule, like the real repository does.
final class MockCloudRepository: RemoteVisitRepository {
    var cloudVisits: [Visit] = []
    var cloudPhotos: [String: [VisitPhoto]] = [:]

    /// Error thrown from `allVisits()` when set.
    var allVisitsError: Error?
    /// Per-country errors thrown from `setVisit`.
    var setVisitErrorByCountry: [String: Error] = [:]

    private(set) var allVisitsCallCount = 0
    private(set) var setVisitCountryIds: [String] = []
    private(set) var uploadedPhotoIds: [UUID] = []
    private(set) var deletedPhotoIds: [UUID] = []

    func allVisits() async throws -> [Visit] {
        allVisitsCallCount += 1
        if let allVisitsError { throw allVisitsError }
        return cloudVisits
    }

    func setVisit(_ visit: Visit) async throws {
        if let error = setVisitErrorByCountry[visit.countryId] { throw error }
        cloudVisits.removeAll { $0.countryId == visit.countryId }
        cloudVisits.append(visit)
        setVisitCountryIds.append(visit.countryId)
    }

    func syncPhotos(countryId: String, localPhotos: [VisitPhoto]) async throws -> [VisitPhoto] {
        let merge = SyncResolver.mergePhotos(local: localPhotos, cloud: cloudPhotos[countryId] ?? [])
        cloudPhotos[countryId, default: []].append(contentsOf: merge.toUpload)
        uploadedPhotoIds.append(contentsOf: merge.toUpload.map(\.id))
        return merge.merged
    }

    func deletePhoto(countryId: String, photoId: UUID) async throws {
        cloudPhotos[countryId]?.removeAll { $0.id == photoId }
        deletedPhotoIds.append(photoId)
    }
}
