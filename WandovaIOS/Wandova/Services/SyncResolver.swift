//
//  SyncResolver.swift
//  Wandova
//
//  Created by seren on 11.07.2026.
//

import Foundation

/// Pure conflict-resolution rules for visit sync.
/// No SwiftData, Firestore, or network dependencies — takes values, returns decisions.
enum SyncResolver {

    /// The action sync should take for a single country.
    enum Resolution: Equatable {
        /// Local version wins — write it to the cloud.
        case pushToCloud(Visit)
        /// Cloud version wins — save it locally.
        case saveToLocal(Visit)
        /// Versions are in sync — do nothing.
        case noChange
    }

    /// Per-country last-write-wins by `updatedAt`: the newer side overwrites the
    /// other, a one-sided visit copies to the missing side, and equal timestamps
    /// are a no-op.
    static func merge(local: Visit?, remote: Visit?) -> Resolution {
        switch (local, remote) {
        case let (local?, remote?):
            if local.updatedAt > remote.updatedAt {
                return .pushToCloud(local)
            } else if remote.updatedAt > local.updatedAt {
                return .saveToLocal(remote)
            }
            return .noChange

        case let (local?, nil):
            return .pushToCloud(local)

        case let (nil, remote?):
            return .saveToLocal(remote)

        case (nil, nil):
            return .noChange
        }
    }

    /// Result of merging local and cloud photo sets for one country.
    struct PhotoMerge: Equatable {
        /// Photos that exist only locally and must be written to the cloud.
        let toUpload: [VisitPhoto]
        /// The union of both sides, keyed by photo ID: local photos first,
        /// then cloud-only photos.
        let merged: [VisitPhoto]
    }

    /// Union-merge by photo ID. A photo absent from the cloud uploads; a photo
    /// absent locally comes down. Photos present on both sides are left alone —
    /// the local copy wins in `merged`.
    static func mergePhotos(local: [VisitPhoto], cloud: [VisitPhoto]) -> PhotoMerge {
        let cloudIds = Set(cloud.map { $0.id })
        let localIds = Set(local.map { $0.id })

        return PhotoMerge(
            toUpload: local.filter { !cloudIds.contains($0.id) },
            merged: local + cloud.filter { !localIds.contains($0.id) }
        )
    }

    /// When a cloud visit overwrites local, prefer the existing local photos;
    /// the photo subcollection sync handles cross-device transfer. If there are
    /// no existing local photos, keep any photos decoded from the legacy "photos"
    /// field (old Firestore format) so the first sync on a new device migrates them.
    static func applyingLocalPhotos(from existing: Visit?, to remote: Visit) -> Visit {
        var merged = remote
        if let existing, !existing.photos.isEmpty {
            merged.photos = existing.photos
        }
        return merged
    }
}
