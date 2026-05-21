//
//  AchievementNotifier.swift
//  Wandova
//
//  Created by seren on 13.05.2026.
//

import Foundation
import Combine

@MainActor
final class AchievementNotifier: ObservableObject {
    @Published var pendingAchievements: [Achievement] = []

    private var seenKey = "seenUnlockedAchievementIDs"

    private var seenIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: seenKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: seenKey) }
    }

    /// Call once per sign-in so each account tracks its own seen achievements.
    func configure(for userId: String) {
        seenKey = "seenUnlockedAchievementIDs_\(userId)"
    }

    func seed(visits: [String: Visit], countries: [Country]) {
        let achievements = AchievementEngine.calculateAchievements(visits: visits, countries: countries)
        let ids = Set(achievements.filter { $0.isUnlocked }.map { $0.id })
        seenIDs = seenIDs.union(ids)
    }

    func check(visits: [String: Visit], countries: [Country]) {
        let achievements = AchievementEngine.calculateAchievements(visits: visits, countries: countries)
        let unlocked = achievements.filter { $0.isUnlocked }
        let seen = seenIDs
        let newlyUnlocked = unlocked.filter { !seen.contains($0.id) }
        guard !newlyUnlocked.isEmpty else { return }
        seenIDs = seen.union(Set(newlyUnlocked.map { $0.id }))
        pendingAchievements.append(contentsOf: newlyUnlocked)
    }

    func dismissCurrent() {
        guard !pendingAchievements.isEmpty else { return }
        pendingAchievements.removeFirst()
    }

    /// Called on sign-out: clears pending queue and resets the key so
    /// the next sign-in picks up the correct per-account store.
    func reset() {
        pendingAchievements.removeAll()
        seenKey = "seenUnlockedAchievementIDs"
    }
}
