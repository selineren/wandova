# Phase 4 QA

## Scope
Phase 4 adds:
- Firebase Authentication
- Firestore cloud sync
- statistics dashboard
- offline handling / sync reliability
- map validation after sync

---

## Test Environment
- Platform: iOS
- Deployment Target: iOS 17+
- Tested On: Physical iPhone Device

---

## QA Checklist

### 1. Authentication
- ✅ User can sign in successfully
- ✅ User session persists after app restart
- ✅ Sign out returns app to signed-out state
- ✅ Invalid auth state is handled gracefully

### 2. Firestore Sync
- ✅ Visiting a country saves to Firestore
- ✅ Unvisiting a country updates/removes remote state correctly
- ✅ Notes sync correctly
- ✅ Visit date syncs correctly
- ✅ Relaunch restores remote data correctly

### 3. Offline / Reliability
- ✅ App works with no network connection
- ✅ Local edits made offline are preserved
- ✅ Changes sync after reconnect
- ✅ No duplicate visit records appear
- ✅ Last update behavior is consistent

### 4. Stats
- ✅ Total visited count is correct
- ✅ Derived stats update immediately after edits
- ✅ Stats persist after relaunch
- ✅ Stats match synced data

### 5. Map
- ✅ Visited countries appear correctly on the map
- ✅ Map reflects synced changes
- ✅ Annotation tap still opens detail screen
- ✅ No stale markers after sync changes

---

## Test Cases

### Case 1 — Sign in and restore session
**Steps**
1. Launch app
2. Sign in
3. Close app
4. Reopen app

**Expected**
- User remains signed in
- Synced visit data is available

### Case 2 — Mark country visited and sync
**Steps**
1. Open a country detail
2. Mark as visited
3. Add date + notes
4. Return to list / relaunch app

**Expected**
- Country remains visited
- Date and notes persist
- Data appears in Firestore

### Case 3 — Offline update then reconnect
**Steps**
1. Disable network
2. Edit visit data
3. Re-enable network

**Expected**
- App does not lose local changes
- Changes sync when connection returns

### Case 4 — Stats refresh
**Steps**
1. Add/remove visited countries
2. Open Stats screen

**Expected**
- Counts update correctly
- No mismatch with list/map data

---

## QA Result
Phase 4 QA completed successfully.

