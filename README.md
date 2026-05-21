# Wandova

A SwiftUI iOS app for tracking the countries you've visited and the ones still on your list — with an interactive map, personal notes, stats, and cloud sync.

## Features

- **Interactive Map** — Visualize your visited and want-to-visit countries on a world map powered by MapKit
- **Country Tracking** — Mark countries as visited or on your wishlist, add photos and personal notes
- **Stats Dashboard** — See how many countries and continents you've covered and your world coverage percentage
- **Achievements** — Unlock milestones as your travel footprint grows
- **Travel Comparison** — Compare your visited countries with friends
- **Map Export** — Export a snapshot of your travel map to share
- **Search & Filter** — Find countries by name or browse by continent
- **Cloud Sync** — Data syncs automatically across devices via Firestore
- **Offline Support** — Full functionality without internet; changes sync when connectivity returns
- **Sign in with Apple & Google** — Secure, fast authentication

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| Map | MapKit |
| Local storage | SwiftData |
| Cloud storage | Firestore |
| Authentication | Firebase Auth, Sign in with Apple, Google Sign-In |
| Architecture | MVVM + Repository Pattern |

## Architecture

```
SwiftUI Views
    └── ViewModels (AppState)
            └── Repository Layer
                    ├── SwiftData (local)
                    └── Firestore (cloud)
                            └── SyncService (bi-directional sync)
```

- **AppState** — Central state management coordinating repositories and sync
- **SyncService** — Handles bi-directional sync between local and cloud storage
- **AuthService** — Manages Firebase authentication and sign-in providers

## Getting Started

### Prerequisites
- Xcode 16.0 or later
- iOS 17.6+ deployment target
- A Firebase project with Authentication and Firestore enabled

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/selineren/wandova-ios.git
   cd wandova-ios
   ```

2. **Configure Firebase**
   - Create a project at [firebase.google.com](https://firebase.google.com)
   - Add an iOS app with bundle ID `com.selineren.Wandova`
   - Download `GoogleService-Info.plist` and place it at `WandovaIOS/Wandova/GoogleService-Info.plist`
   - Enable Email/Password, Google, and Apple sign-in methods in Firebase Console

3. **Open in Xcode**
   ```bash
   open WandovaIOS/Wandova.xcodeproj
   ```

4. **Run**
   Select a simulator or device and press `Cmd+R`

### Notes

- `GoogleService-Info.plist` is excluded from version control — you must add it manually
- Country boundaries are loaded from a bundled GeoJSON file — no external API needed
- Offline changes are queued locally and synced automatically when connectivity is restored

---

Built with SwiftUI · Designed for iOS 17.6+
