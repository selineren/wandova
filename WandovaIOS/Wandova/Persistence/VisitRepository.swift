//
//  VisitRepository.swift
//  Wandova
//
//  Created by seren on 2.03.2026.
//

import Foundation

protocol VisitRepository {
    func visit(for countryId: String) throws -> Visit
    func allVisits() throws -> [Visit]
    func setVisited(_ countryId: String, isVisited: Bool, visitedDate: Date?) throws
    func setWantToVisit(_ countryId: String, wantToVisit: Bool) throws
    func updateNotes(_ countryId: String, notes: String) throws
    func addPhoto(_ countryId: String, photo: VisitPhoto) throws
    func removePhoto(_ countryId: String, photoId: UUID) throws
    func updatePhotoCaption(_ countryId: String, photoId: UUID, caption: String) throws
    func upsert(_ visit: Visit) throws
    func visitedCount() throws -> Int
    func deleteAllVisits() throws
}

/// Cloud-backed visit store as consumed by SyncService, including the
/// photo subcollection operations.
protocol RemoteVisitRepository {
    func allVisits() async throws -> [Visit]
    func setVisit(_ visit: Visit) async throws
    func syncPhotos(countryId: String, localPhotos: [VisitPhoto]) async throws -> [VisitPhoto]
    func deletePhoto(countryId: String, photoId: UUID) async throws
}
