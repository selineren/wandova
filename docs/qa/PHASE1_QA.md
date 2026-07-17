# Phase 1 – QA Checklist

This checklist verifies that the UI foundation and navigation flow are fully functional using mock data.

---

## App Launch
- [ ] App launches without errors
- [ ] Tab bar is visible (Map / Countries / Stats)

---

## Countries List
- [ ] Countries are grouped by continent
- [ ] Search filters results correctly
- [ ] Empty state appears when search returns no matches
- [ ] Visited countries display visual indicator

---

## Country Detail
- [ ] Opening a country shows detail screen
- [ ] "Visited" toggle works
- [ ] Custom visit date can be selected
- [ ] Notes can be edited
- [ ] Returning to list updates visited state immediately

---

## Stats
- [ ] Visited country count updates dynamically
- [ ] Screen renders without layout issues

---

## Map
- [ ] Placeholder screen renders correctly

---

## Stability Check
- [ ] No runtime crashes
- [ ] No console errors
- [ ] Clean build (⌘B succeeds)

---

Phase 1 verification complete when all items above pass.
