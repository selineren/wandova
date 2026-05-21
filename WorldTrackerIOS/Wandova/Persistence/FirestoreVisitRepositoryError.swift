//
//  FirestoreVisitRepositoryError.swift
//  Wandova
//
//  Created by seren on 10.03.2026.
//

import Foundation

enum FirestoreVisitRepositoryError: LocalizedError, Equatable {
    case notAuthenticated
    case documentNotFound
    case invalidData
    case permissionDenied
    case offline
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated."
        case .documentNotFound:
            return "Document not found."
        case .invalidData:
            return "Firestore document contains invalid data."
        case .permissionDenied:
            return "Permission denied."
        case .offline:
            return "No internet connection - unable to sync with server."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
    
    static func == (lhs: FirestoreVisitRepositoryError, rhs: FirestoreVisitRepositoryError) -> Bool {
        switch (lhs, rhs) {
        case (.notAuthenticated, .notAuthenticated),
             (.documentNotFound, .documentNotFound),
             (.invalidData, .invalidData),
             (.permissionDenied, .permissionDenied),
             (.offline, .offline):
            return true
        case (.unknown, .unknown):
            return true // Simplified comparison for unknown errors
        default:
            return false
        }
    }
}
