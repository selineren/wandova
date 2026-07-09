# Wandova iOS — Architecture Audit

Audit date: 2026-07-09. Read-only audit — no code was modified. All paths are relative to `WandovaIOS/Wandova/`.

---

## 1. Combine vs. Observation

**Combine (`ObservableObject` + `@Published`) is used everywhere. The `@Observable` / Observation framework is not used at all** — zero occurrences of `@Observable` or `import Observation` in the codebase.

Seven files `import Combine`:

| File | What it uses from Combine |
|---|---|
| `ViewModels/AppState.swift` | `@Published` ×5, `AnyCancellable`, one `.sink` pipeline |
| `ViewModels/CountriesViewModel.swift` | `@Published` ×5 only |
| `ViewModels/AchievementNotifier.swift` | `@Published` ×1 only |
| `Services/AuthService.swift` | `@Published` ×3 only |
| `Services/NetworkMonitor.swift` | `@Published` ×2 only |
| `Services/ComparisonView.swift` (ComparisonViewModel) | `@Published` ×6 only |
| `Views/Stats/StatsScreen.swift` (nested StatsViewModel) | `@Published` ×2 only |

The only genuinely *reactive* Combine usage in the app is one subscription: `AppState` observes `NetworkMonitor.$isConnected` via `.sink` (`AppState.swift:54-58`). Everything else is `@Published` used purely as SwiftUI change notification. There are no `PassthroughSubject`s or `CurrentValueSubject`s anywhere.

Two quirks worth knowing:
- `AppState` repeatedly calls `objectWillChange.send()` manually before batch mutations (labeled "OPTIMIZATION", e.g. `AppState.swift:237`) to coalesce re-renders. Note this actually causes *two* notifications, not one — the manual send plus the automatic one from the first `@Published` assignment — so the optimization doesn't do what the comments claim.
- `MapScreen.swift:143` uses `.onReceive(NotificationCenter.default.publisher(...))` — Combine via NotificationCenter, without an explicit import.

**Verdict:** migration to `@Observable` would be mechanical for 6 of the 7 types; only `AppState`'s NetworkMonitor subscription and the manual `objectWillChange` pattern need real rework.

---

## 2. ViewModels and their dependencies

There is exactly **one repository protocol** in the app: `VisitRepository` (`Persistence/VisitRepository.swift`), implemented by `SwiftDataVisitRepository` (SwiftData) and `FirestoreVisitRepository` (Firestore). Only `AppState` actually consumes it. Everything else depends on concrete types, mostly self-instantiated.

### ViewModels

| ViewModel | File | Dependencies | Via protocol? |
|---|---|---|---|
| `AppState` | `ViewModels/AppState.swift` | `VisitRepository` (injected), `SyncService?` (injected, concrete class), `NetworkMonitor` (defaults to `.shared` singleton) | **Partly.** Repository yes; but `clearLocalDataAfterSignOut()` downcasts `repository as? SwiftDataVisitRepository` (line 435), leaking the concrete type through the abstraction. |
| `CountriesViewModel` | `ViewModels/CountriesViewModel.swift` | `CountryDataService.shared` (GeoJSON loader singleton) | No — hardcoded singleton. No SwiftData/Firestore access. |
| `AchievementNotifier` | `ViewModels/AchievementNotifier.swift` | `UserDefaults.standard` directly, `AchievementEngine` (static) | No. |
| `StatsViewModel` (nested inside `StatsScreen`) | `Views/Stats/StatsScreen.swift:458` | `CountryDataService.shared`, `AchievementEngine` | No — hardcoded singleton. |
| `ComparisonViewModel` | `Services/ComparisonView.swift:528` | **`FirestoreUserRepository()` and `FirestoreVisitRepository()` instantiated directly** (lines 545-546), plus `CountryDataService.shared`, `TravelComparisonEngine` | **No — direct Firestore access, not injectable, not testable without Firebase.** |

### ObservableObjects that act like ViewModels but live in Services/

| Type | File | Dependencies |
|---|---|---|
| `AuthService` | `Services/AuthService.swift` | `Auth.auth()` (FirebaseAuth) directly throughout; `GIDSignIn.sharedInstance`; instantiates `FirestoreUserRepository()` inline (lines 132, 182, 224) and `FirestoreVisitRepository()` inline for account deletion (line 291). No protocol. |
| `NetworkMonitor` | `Services/NetworkMonitor.swift` | `NWPathMonitor`. Singleton (`.shared`). |

### Direct data access from Views (bypassing ViewModels entirely)

- `AccountScreen.swift:28` — holds `private let profileRepository = FirestoreUserRepository()` directly in the View.
- `CountryDetailScreen`, `MapScreen`, etc. mutate data through `AppState` (fine — that's the intended path).

**Verdict:** the repository pattern exists but only on the visit-persistence seam consumed by `AppState`. `SyncService` itself depends on the two *concrete* repository classes (not the protocol). `FirestoreUserRepository` has no protocol at all. `ComparisonViewModel`, `AuthService`, and `AccountScreen` talk to Firestore directly.

---

## 3. Sync & conflict-resolution logic

All of it lives in two files:

### `Services/SyncService.swift` — the orchestrator and conflict resolver

- **`syncVisits(withRetry:)` (line 34)** — entry point. Auth guard, concurrent-sync guard, retry loop (max 3 attempts, 2 s fixed delay; network and auth errors are not retried).
- **`performSync()` (line 104)** — **the core conflict-resolution function.** Loads all local visits (SwiftData) and all cloud visits (Firestore), unions the country IDs, then per country:
  - Both exist → **last-write-wins on the whole record**, compared by `updatedAt` (lines 122-132): newer local → push to cloud; newer cloud → save to local; equal timestamps → do nothing.
  - Local only → push to cloud. Cloud only → save to local.
  - Per-country errors are counted and sync continues; any failures surface as `SyncError.partialFailure`.
  - Phase 2 (lines 164-189): photo sync per country via the Firestore subcollection; photo errors are non-fatal except offline.
  - The catch block (lines 194-240) does heuristic network-error classification (NSURLError codes, Firestore codes 14/7, string matching on the error description) and maps to `SyncError.noConnection`.
- **`saveToLocal(_:)` (line 247)** — a second, subtler conflict rule: when a newer cloud record overwrites local, **existing local photos are preserved** (photos are reconciled separately by the subcollection sync, not by document LWW).
- **`deleteCloudPhoto(countryId:photoId:)` (line 260)** — best-effort cloud photo deletion, called by `AppState.removePhoto` *before* the follow-up sync so the union-merge doesn't resurrect the deleted photo.

### `Persistence/FirestoreVisitRepository.swift` — photo-level merge

- **`syncPhotos(countryId:localPhotos:)` (line 430)** — **union merge by photo ID**: uploads local-only photos to the cloud subcollection, returns local photos + cloud-only photos. There is no photo-level LWW and no tombstones — deletion consistency relies entirely on `deleteCloudPhoto` being called at removal time.

### Status/error presentation

- **`AppState.syncWithCloud(showStatus:)` (`ViewModels/AppState.swift:106`)** — wraps `SyncService.syncVisits`, maps errors to the `SyncStatus` enum (defined at the top of the same file), reloads local persistence after sync. `retrySyncIfNeeded()` (line 173) re-runs sync from an error state.
- Sync is triggered from: `RootTabView.task` (on appear), `AppState.handleSignIn()`, and fire-and-forget after every local mutation (`setVisited`, `setWantToVisit`, `updateNotes`, photo ops).

### Caveats to be aware of (observed, not fixed)

- Conflict resolution is **whole-record LWW**: if device A edits notes and device B toggles visited on the same country, whichever `updatedAt` is later wins and the other device's change is silently lost. There is no field-level merge.
- LWW depends on client wall-clocks (`Date()` set locally in `AppState`), so clock skew between devices can pick the wrong winner.
- There are no tombstones for visit records; "un-visiting" flips flags rather than deleting the document, which is why this mostly works.

---

## 4. Tests

**None.** There is no test target in `Wandova.xcodeproj/project.pbxproj` (no `XCTest`, Swift Testing, `.xctestplan`, or `*Tests*` references anywhere), and no test source files in the repo. The closest thing is manual QA checklists in `docs/PHASE1_QA.md` through `docs/PHASE4_QA.md`.

Testability note: only `AppState` (protocol-injected `VisitRepository`) and `SyncService`/`AppState` (injectable `NetworkMonitor`) are unit-testable today. `ComparisonViewModel`, `AuthService`, and `SyncService`'s concrete repository dependencies would need seams first.

---

## 5. Distinct screens / navigable destinations

**Top-level states** (from `AuthGatedRootView` in `App/WandovaApp.swift:140`):

1. **LoadingView** — auth state unknown
2. **AuthScreen** — sign in / sign up (signed out)
3. **RootTabView** — signed in, containing **5 tabs**:
   4. **MapScreen**
   5. **CountriesScreen**
   6. **StatsScreen**
   7. **ComparisonView** (Compare tab)
   8. **AccountScreen**

**Pushed destinations:**

9. **CountryDetailScreen** — reachable from Map (`navigationDestination`), Countries, Stats (4 link sites), and Compare
10. **ContinentCountriesView** — pushed from CountriesScreen

**Sheets / full-screen covers:**

11. **CountryQuickActionSheet** — Map, tapping a country
12. **MapMemoriesSheet** — Map
13. **MapExportSheet** — Map (plus a nested UIKit share sheet)
14. **BadgeDetailSheet** — Stats, tapping an achievement
15. **ChangePasswordView** — Account (file lives in `Services/`)
16. **DeleteAccountView** — Account (file lives in `Services/`)
17. **PhotoFullScreenView** — Country detail, full-screen photo viewer
18. **AllPhotosSheetView** — Country detail, photo grid

Plus one modal-style overlay: **AchievementCelebrationView** (achievement unlock popup, driven by `AchievementNotifier`).

**Count: 18 distinct navigable screens/destinations** (3 top-level states, 5 tabs, 2 pushed screens, 8 sheets/covers), plus 1 overlay. `Views/Shared/ContentView.swift` is dead code — the Xcode template view, referenced only by its own preview.

---

## File-organization observations (for future cleanup, not changed)

- Several Views live in non-View folders: `SyncStatusView.swift` in `ViewModels/`; `ComparisonView.swift`, `ChangePasswordView.swift`, `DeleteAccountView.swift` in `Services/`; `CountryDataService.swift`, `MapSnapshotService.swift` in `Views/Map/`.
- `ComparisonViewModel` (120+ lines) is embedded at the bottom of the 650-line `ComparisonView.swift`; `StatsViewModel` is nested inside `StatsScreen`.
- `AppState` is both the app-wide store and the sync-status presenter — it is the de facto ViewModel for most screens.
