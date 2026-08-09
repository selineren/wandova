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
        /// Photos on both sides whose local caption is newer — push the caption
        /// (not the image) to the cloud.
        let toUpdateCaption: [VisitPhoto]
        /// The union of both sides, keyed by photo ID: local photos first,
        /// then cloud-only photos.
        let merged: [VisitPhoto]
    }

    /// Union-merge by photo ID. A photo absent from the cloud uploads; a photo
    /// absent locally comes down. For photos on both sides the newer caption
    /// wins (by captionUpdatedAt): a newer local caption is queued for cloud
    /// update, a newer cloud caption is adopted into `merged`.
    static func mergePhotos(local: [VisitPhoto], cloud: [VisitPhoto]) -> PhotoMerge {
        let cloudById = Dictionary(uniqueKeysWithValues: cloud.map { ($0.id, $0) })
        let localIds = Set(local.map { $0.id })

        var toUpdateCaption: [VisitPhoto] = []
        let localMerged = local.map { localPhoto -> VisitPhoto in
            guard let cloudPhoto = cloudById[localPhoto.id] else { return localPhoto }
            if localPhoto.captionUpdatedAt > cloudPhoto.captionUpdatedAt {
                toUpdateCaption.append(localPhoto)
                return localPhoto
            }
            var adopted = localPhoto
            adopted.caption = cloudPhoto.caption
            adopted.captionUpdatedAt = cloudPhoto.captionUpdatedAt
            return adopted
        }

        return PhotoMerge(
            toUpload: local.filter { cloudById[$0.id] == nil },
            toUpdateCaption: toUpdateCaption,
            merged: localMerged + cloud.filter { !localIds.contains($0.id) }
        )
    }

    /// When a cloud visit overwrites local, keep the existing local photos;
    /// cloud metadata documents never carry photo payloads, and the photo
    /// subcollection sync handles cross-device transfer.
    static func applyingLocalPhotos(from existing: Visit?, to remote: Visit) -> Visit {
        var merged = remote
        merged.photos = existing?.photos ?? []
        return merged
    }
}
