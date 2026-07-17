# Wandova — Architecture

Wandova is an offline-first SwiftUI iOS app for tracking visited countries, with bi-directional sync between on-device storage (SwiftData) and the cloud (Firestore). This document describes how it's put together and, at the end, the trade-offs it knowingly makes.

## Layers

MVVM with a repository layer between view models and storage:

```
SwiftUI Views
    └── ViewModels  (AppState — central store, sync-status presenter)
            └── VisitRepository (protocol)
                    ├── SwiftDataVisitRepository   — local, source of truth for the UI
                    └── FirestoreVisitRepository   — cloud, per-user document store
            └── SyncService — reconciles the two sides
```

- **`AppState`** is the app-wide store: every screen reads visit data from it, and every mutation (mark visited, edit notes, add/remove photos) goes through it. It writes to the local repository first, then kicks off a fire-and-forget cloud sync.
- **`SyncService`** orchestrates sync. It depends only on the `VisitRepository` / `RemoteVisitRepository` protocols, an injectable `NetworkMonitor`, and an injectable auth check — no concrete Firestore or SwiftData types — so it runs under test with mocks.
- **`SyncResolver`** holds the conflict-resolution *rules* as pure functions (values in, decisions out; no I/O). `SyncService` executes the decisions.

State and reactivity use **Combine**: view models are `ObservableObject`s with `@Published` properties, and `AppState` subscribes to `NetworkMonitor.$isConnected` to re-trigger sync when connectivity returns.

## Sync model

The app is offline-first: all writes land in SwiftData immediately and the UI never waits on the network. Sync runs after each local mutation, at app start, after sign-in, and when connectivity is restored.

**Visit records — last-write-wins per record.** Sync loads all local and all cloud visits, unions the country IDs, and resolves each country with `SyncResolver.merge`: whichever side has the newer `updatedAt` overwrites the other in full; a record that exists on only one side is copied to the other; equal timestamps are a no-op.

**Photos — union-merge by ID.** Photos live in a per-country Firestore subcollection and are reconciled separately from the visit document: photos that exist only locally are uploaded, photos that exist only in the cloud are downloaded, and photos present on both sides are left alone. When a newer cloud record overwrites a local one, existing local photos are preserved rather than clobbered — cross-device photo transfer is the subcollection sync's job. Deleting a photo calls a best-effort cloud delete *before* the follow-up sync, so the union-merge doesn't resurrect it.

**Failure handling.** Sync retries up to 3 times with a 2-second delay; network and auth errors are not retried (retrying won't fix them — the user needs connectivity or a session). A failure on one country doesn't abort the rest: errors are counted and surfaced as a partial-failure status the UI can present, and offline changes simply sync on the next trigger.

## Tests

`WandovaTests` (XCTest) covers the sync engine at two levels:

- **`SyncResolverTests`** — the pure conflict rules: newer-side-wins in both directions, equal timestamps as no-op even when content differs, one-sided copies, photo union-merge, and local-photo preservation on cloud overwrite (including the legacy-format migration path).
- **`SyncServiceTests`** — the orchestrator against in-memory mock repositories: end-to-end merge outcomes, deleted-photo non-resurrection, partial failure continuing past a bad country, retry counts, and that offline/auth errors short-circuit without retrying.

This split is deliberate: the rules are tested exhaustively as pure functions, and the service tests check that the orchestration honors them.

## Known trade-offs

These are conscious simplifications, each with a known upgrade path:

- **Whole-record LWW loses concurrent field edits.** If device A edits a country's notes while device B toggles its visited flag, whichever record has the later `updatedAt` wins entirely and the other device's change is silently discarded. *Upgrade path:* field-level merge — track `updatedAt` (or a version) per field and resolve conflicts field-by-field, so independent edits to different fields both survive.
- **LWW trusts client wall-clocks.** `updatedAt` is set with `Date()` on the device, so clock skew between devices can pick the wrong winner. *Upgrade path:* server-assigned timestamps (Firestore `FieldValue.serverTimestamp()`) or a hybrid logical clock, so ordering doesn't depend on device clocks.
- **No tombstones for visit records.** "Un-visiting" a country flips flags on the record rather than deleting the document — which is why record sync mostly avoids deletion conflicts — and photo deletion relies on the best-effort cloud delete landing before the next sync. If that delete fails (e.g., the app is killed mid-operation), the union-merge resurrects the photo. *Upgrade path:* tombstones — record deletions as their own synced facts with timestamps, and let the merge honor them.
