//
//  FirestoreVisitRepository.swift
//  Wandova
//
//  Created by seren on 10.03.2026.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore

final class FirestoreVisitRepository: RemoteVisitRepository {
    private let db = Firestore.firestore()

    // MARK: - Public API

    func visit(for countryId: String) async throws -> Visit {
        let doc = try await getVisitDocument(countryId: countryId)

        guard let data = doc.data() else {
            throw FirestoreVisitRepositoryError.documentNotFound
        }

        return try VisitDocumentMapper.visit(countryId: countryId, data: data)
    }

    func allVisits() async throws -> [Visit] {
        let userID = try requireUserID()

        let snapshot = try await getDocuments(
            from: db.collection("users")
                .document(userID)
                .collection("visits")
        )

        return try snapshot.documents.map { document in
            try VisitDocumentMapper.visit(countryId: document.documentID, data: document.data())
        }
    }
    
    /// Fetch all visits for a specific user (read-only)
    /// Used for travel comparison - can only read users who have allowComparison enabled
    /// - Parameter userId: The Firebase Auth user ID to fetch visits for
    /// - Returns: Array of Visit objects for the specified user
    /// - Throws: FirestoreVisitRepositoryError if the fetch fails
    /// - Note: This is a read-only operation. No write access to other users' data is possible.
    func allVisits(forUserId userId: String) async throws -> [Visit] {
        // Ensure we're authenticated (even though we're reading someone else's data)
        _ = try requireUserID()
        
        let snapshot = try await getDocuments(
            from: db.collection("users")
                .document(userId)
                .collection("visits")
        )

        return try snapshot.documents.map { document in
            try VisitDocumentMapper.visit(countryId: document.documentID, data: document.data())
        }
    }

    func setVisited(_ countryId: String, isVisited: Bool, visitedDate: Date?, notes: String, wantToVisit: Bool = false) async throws {
        let userID = try requireUserID()

        let data: [String: Any] = [
            "isVisited": isVisited,
            "wantToVisit": wantToVisit,
            "visitedDate": visitedDate as Any,
            "notes": notes,
            "updatedAt": Timestamp(date: Date())
        ]

        try await setData(
            data,
            for: db.collection("users")
                .document(userID)
                .collection("visits")
                .document(countryId)
        )
    }

    /// Writes visit metadata to Firestore. Photos are stored separately in the photos subcollection.
    func setVisit(_ visit: Visit) async throws {
        let userID = try requireUserID()
        let ref = db.collection("users")
            .document(userID)
            .collection("visits")
            .document(visit.countryId)

        let data: [String: Any] = [
            "isVisited": visit.isVisited,
            "wantToVisit": visit.wantToVisit,
            "visitedDate": visit.visitedDate as Any,
            "notes": visit.notes,
            "updatedAt": Timestamp(date: visit.updatedAt)
        ]

        try await setData(data, for: ref)
    }

    func updateNotes(_ countryId: String, notes: String) async throws {
        let userID = try requireUserID()

        let ref = db.collection("users")
            .document(userID)
            .collection("visits")
            .document(countryId)

        let data: [String: Any] = [
            "notes": notes,
            "updatedAt": Timestamp(date: Date())
        ]

        try await updateData(data, for: ref)
    }
    
    func deleteVisit(_ countryId: String) async throws {
        let userID = try requireUserID()

        try await deleteDocument(
            db.collection("users")
                .document(userID)
                .collection("visits")
                .document(countryId)
        )
    }
    
    /// Delete all visit documents for the current user
    /// Used during account deletion to clean up cloud data before removing the Firebase Auth account
    /// - Throws: `FirestoreVisitRepositoryError.notAuthenticated` if no user is signed in
    /// - Note: Succeeds silently if the user has no visit documents (empty collection is valid)
    func deleteAllUserVisits() async throws {
        let userID = try requireUserID()
        
        // Fetch all visit documents for this user
        let snapshot = try await getDocuments(
            from: db.collection("users")
                .document(userID)
                .collection("visits")
        )
        
        // Delete each document individually
        // Note: Firestore doesn't support batch deletes via the client SDK for collections,
        // so we must delete each document separately
        for document in snapshot.documents {
            try await deleteDocument(document.reference)
        }
        
        #if DEBUG
        print("🗑️ Deleted \(snapshot.documents.count) visit document(s) for user \(userID)")
        #else
        print("🗑️ Deleted \(snapshot.documents.count) visit document(s)")
        #endif
    }

    // MARK: - Helpers

    private func requireUserID() throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw FirestoreVisitRepositoryError.notAuthenticated
        }
        return uid
    }

    private func getVisitDocument(countryId: String) async throws -> DocumentSnapshot {
        let userID = try requireUserID()

        return try await getDocument(
            from: db.collection("users")
                .document(userID)
                .collection("visits")
                .document(countryId)
        )
    }

    // MARK: - Async wrappers

    private func getDocument(from ref: DocumentReference) async throws -> DocumentSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            // Use source: .server to force network fetch, not cache
            ref.getDocument(source: .server) { snapshot, error in
                if let error {
                    continuation.resume(throwing: self.mapError(error))
                    return
                }

                guard let snapshot else {
                    continuation.resume(throwing: FirestoreVisitRepositoryError.documentNotFound)
                    return
                }

                continuation.resume(returning: snapshot)
            }
        }
    }

    private func getDocuments(from ref: CollectionReference) async throws -> QuerySnapshot {
        try await withCheckedThrowingContinuation { continuation in
            // Use source: .server to force network fetch, not cache
            ref.getDocuments(source: .server) { snapshot, error in
                if let error {
                    #if DEBUG
                    print("🔥 Firestore error: \(error)")
                    #endif
                    continuation.resume(throwing: self.mapError(error))
                    return
                }

                guard let snapshot else {
                    #if DEBUG
                    print("🔥 Firestore: No snapshot returned")
                    #endif
                    continuation.resume(throwing: FirestoreVisitRepositoryError.invalidData)
                    return
                }
                
                #if DEBUG
                // Check if this data came from cache despite requesting server
                print("🔥 Firestore snapshot: \(snapshot.documents.count) docs, metadata.isFromCache: \(snapshot.metadata.isFromCache)")
                #endif
                
                // If we requested server but got cache, and we're offline, throw error
                if snapshot.metadata.isFromCache {
                    #if DEBUG
                    print("⚠️ Received cached data when server was requested - treating as offline")
                    #endif
                    continuation.resume(throwing: FirestoreVisitRepositoryError.offline)
                    return
                }

                continuation.resume(returning: snapshot)
            }
        }
    }

    private func setData(_ data: [String: Any], for ref: DocumentReference) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.setData(data) { error in
                if let error {
                    continuation.resume(throwing: self.mapError(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func updateData(_ data: [String: Any], for ref: DocumentReference) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.updateData(data) { error in
                if let error {
                    continuation.resume(throwing: self.mapError(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func deleteDocument(_ ref: DocumentReference) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.delete { error in
                if let error {
                    continuation.resume(throwing: self.mapError(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func mapError(_ error: Error) -> FirestoreVisitRepositoryError {
        let nsError = error as NSError

        // 7 is permission denied in gRPC / Firestore permission failures
        if nsError.code == 7 {
            return .permissionDenied
        }

        return .unknown(error)
    }
    
    // MARK: - Photo Subcollection

    /// Syncs photos for a country using the photos subcollection.
    /// Uploads local-only photos to cloud and returns the union of local + cloud-only photos.
    func syncPhotos(countryId: String, localPhotos: [VisitPhoto]) async throws -> [VisitPhoto] {
        let userID = try requireUserID()
        let ref = photosCollection(userID: userID, countryId: countryId)
        let snapshot = try await getDocuments(from: ref)
        let cloudPhotos = snapshot.documents.compactMap { photoFromDocument($0) }

        let merge = SyncResolver.mergePhotos(local: localPhotos, cloud: cloudPhotos)

        for photo in merge.toUpload {
            try await setData(photoDocument(photo), for: ref.document(photo.id.uuidString))
        }

        for photo in merge.toUpdateCaption {
            try await updateData(
                [
                    "caption": photo.caption,
                    "captionUpdatedAt": Timestamp(date: photo.captionUpdatedAt)
                ],
                for: ref.document(photo.id.uuidString)
            )
        }

        return merge.merged
    }

    func deletePhoto(countryId: String, photoId: UUID) async throws {
        let userID = try requireUserID()
        try await deleteDocument(
            photosCollection(userID: userID, countryId: countryId).document(photoId.uuidString)
        )
    }

    private func photosCollection(userID: String, countryId: String) -> CollectionReference {
        db.collection("users")
            .document(userID)
            .collection("visits")
            .document(countryId)
            .collection("photos")
    }

    private func photoDocument(_ photo: VisitPhoto) -> [String: Any] {
        [
            "imageData": photo.imageData.base64EncodedString(),
            "caption": photo.caption,
            "captionUpdatedAt": Timestamp(date: photo.captionUpdatedAt),
            "createdAt": Timestamp(date: photo.createdAt)
        ]
    }

    private func photoFromDocument(_ doc: QueryDocumentSnapshot) -> VisitPhoto? {
        let data = doc.data()
        guard let s = data["imageData"] as? String,
              let imageData = Data(base64Encoded: s) else { return nil }
        return VisitPhoto(
            id: UUID(uuidString: doc.documentID) ?? UUID(),
            imageData: imageData,
            caption: data["caption"] as? String ?? "",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            captionUpdatedAt: (data["captionUpdatedAt"] as? Timestamp)?.dateValue()
        )
    }
}
