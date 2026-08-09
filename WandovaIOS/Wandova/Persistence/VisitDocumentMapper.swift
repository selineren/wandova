//
//  VisitDocumentMapper.swift
//  Wandova
//

import Foundation
import FirebaseFirestore

/// Maps a Firestore visit metadata document to a `Visit`.
/// Pure data-in/data-out so the mapping rules are unit-testable without a
/// repository or network.
enum VisitDocumentMapper {

    /// Visit metadata documents never carry photo payloads — photos live in
    /// the photos subcollection and sync separately via syncPhotos. The
    /// returned visit always has empty `photos`, so bulk reads (e.g. Compare
    /// fetching another user's visits) never decode image bytes.
    static func visit(countryId: String, data: [String: Any]) throws -> Visit {
        guard let isVisited = data["isVisited"] as? Bool else {
            throw FirestoreVisitRepositoryError.invalidData
        }

        // Backward compatible: default to false if field doesn't exist in Firestore
        let wantToVisit = data["wantToVisit"] as? Bool ?? false

        // VALIDATION: Enforce mutual exclusivity
        // If cloud data has both states true (corrupted), visited takes priority
        let validatedIsVisited: Bool
        let validatedWantToVisit: Bool

        if isVisited && wantToVisit {
            #if DEBUG
            print("⚠️ Data integrity issue for \(countryId): both isVisited and wantToVisit are true")
            print("   Resolving by prioritizing visited state (clearing wantToVisit)")
            #endif
            // Visited is more important state - it has a date and represents completed travel
            validatedIsVisited = true
            validatedWantToVisit = false
        } else {
            validatedIsVisited = isVisited
            validatedWantToVisit = wantToVisit
        }

        let notes = data["notes"] as? String ?? ""

        let visitedDate: Date?
        if let timestamp = data["visitedDate"] as? Timestamp {
            visitedDate = timestamp.dateValue()
        } else {
            visitedDate = nil
        }

        let updatedAt: Date
        if let timestamp = data["updatedAt"] as? Timestamp {
            updatedAt = timestamp.dateValue()
        } else {
            throw FirestoreVisitRepositoryError.invalidData
        }

        // Ensure visited countries have a date - if missing, use updatedAt as best guess
        let finalVisitedDate: Date?
        if validatedIsVisited {
            finalVisitedDate = visitedDate ?? updatedAt
        } else {
            finalVisitedDate = nil
        }

        return Visit(
            countryId: countryId,
            isVisited: validatedIsVisited,
            wantToVisit: validatedWantToVisit,
            visitedDate: finalVisitedDate,
            notes: notes,
            photos: [],
            updatedAt: updatedAt
        )
    }
}
