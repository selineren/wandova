//
//  StatsScreen.swift
//  Wandova
//
//  Created by seren on 25.02.2026.
//

import SwiftUI
import Combine

struct StatsScreen: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = StatsViewModel()
    @State private var selectedAchievement: Achievement?

    // MARK: - Computed properties

    private var visitedVisits: [Visit] {
        appState.visits.values.filter { $0.isVisited }
    }

    private var wantToVisitVisits: [Visit] {
        appState.visits.values.filter { $0.wantToVisit }
    }

    private var totalCountriesCount: Int { vm.countries.count }
    private var visitedCountriesCount: Int { visitedVisits.count }
    private var wantToVisitCount: Int { wantToVisitVisits.count }

    private var totalPhotosCount: Int {
        visitedVisits.reduce(0) { $0 + $1.photos.count }
    }

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    private var visitedPercentage: Double {
        guard totalCountriesCount > 0 else { return 0 }
        return Double(visitedCountriesCount) / Double(totalCountriesCount) * 100
    }

    private var achievements: [Achievement] {
        vm.achievements(from: appState.visits)
    }

    private var visitedCountries: [Country] {
        let ids = Set(visitedVisits.map { $0.countryId })
        return vm.countries.filter { ids.contains($0.id) }
    }

    private var wantToVisitCountries: [Country] {
        let ids = Set(wantToVisitVisits.map { $0.countryId })
        return vm.countries.filter { ids.contains($0.id) }
    }

    private var visitedThisYear: [(country: Country, date: Date)] {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        let byId = Dictionary(uniqueKeysWithValues: vm.countries.map { ($0.id, $0) })
        return visitedVisits
            .compactMap { visit -> (country: Country, date: Date)? in
                guard let country = byId[visit.countryId] else { return nil }
                guard let date = visit.visitedDate ?? (visit.isVisited ? visit.updatedAt : nil) else { return nil }
                guard calendar.component(.year, from: date) == year else { return nil }
                return (country: country, date: date)
            }
            .sorted { $0.date > $1.date }
    }

    private var visitedByContinent: [(continent: Continent, visited: Int, total: Int, percentage: Double)] {
        let grouped = Dictionary(grouping: vm.countries, by: { $0.continent })
        let visitedIDs = Set(visitedVisits.map { $0.countryId })
        return Continent.allCases.compactMap { continent in
            let all = grouped[continent] ?? []
            guard !all.isEmpty else { return nil }
            let visited = all.filter { visitedIDs.contains($0.id) }.count
            let pct = Double(visited) / Double(all.count) * 100
            return (continent: continent, visited: visited, total: all.count, percentage: pct)
        }
        .sorted { $0.percentage > $1.percentage }
    }

    private var recentVisits: [(country: Country, date: Date?)] {
        let byId = Dictionary(uniqueKeysWithValues: vm.countries.map { ($0.id, $0) })
        return visitedVisits
            .compactMap { visit in
                guard let country = byId[visit.countryId] else { return nil }
                return (country: country, date: visit.visitedDate)
            }
            .sorted {
                switch ($0.date, $1.date) {
                case let (d0?, d1?): return d0 > d1
                case (nil, _?): return false
                case (_?, nil): return true
                case (nil, nil): return $0.country.name < $1.country.name
                }
            }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    overviewSection
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                    summarySection
                        .padding(.horizontal, 16)
                        .padding(.top, 24)

                    if !wantToVisitCountries.isEmpty {
                        wishlistSection
                            .padding(.top, 24)
                    }

                    if !visitedCountries.isEmpty {
                        visitedCountriesSection
                            .padding(.top, 24)
                    }

                    continentProgressSection
                        .padding(.horizontal, 16)
                        .padding(.top, 24)

                    badgesSection
                        .padding(.top, 24)

                    if !recentVisits.isEmpty {
                        recentMemoriesSection
                            .padding(.horizontal, 16)
                            .padding(.top, 24)
                    }

                    Spacer().frame(height: 32)
                }
            }
            .background(Color.appPaper)
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedAchievement) { achievement in
                BadgeDetailSheet(achievement: achievement)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(24)
            }
        }
    }

    // MARK: - Overview

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Overview")
            VStack(alignment: .leading, spacing: 10) {
                Text("\(visitedCountriesCount) / \(totalCountriesCount) Countries")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.appInk)
                    .tracking(-0.5)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.appLine)
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.appInk)
                            .frame(
                                width: max(geo.size.width * (visitedPercentage / 100), visitedCountriesCount > 0 ? 6 : 0),
                                height: 4
                            )
                    }
                }
                .frame(height: 4)

                Text(String(format: "%.1f%% of the world", visitedPercentage))
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appInk3)
            }
            .padding(16)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Summary")
            HStack(spacing: 12) {
                summaryCard(
                    value: "\(visitedThisYear.count)",
                    label: "Visited this year",
                    sublabel: "Countries"
                )
                summaryCard(
                    value: "\(wantToVisitCount)",
                    label: "On Wishlist",
                    sublabel: "Planning"
                )
            }
        }
    }

    private func summaryCard(value: String, label: String, sublabel: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Color.appInk)
                .tracking(-0.5)
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.appInk)
                .padding(.top, 2)
            Text(sublabel)
                .font(.system(size: 12))
                .foregroundStyle(Color.appInk3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    // MARK: - Wishlist

    private var wishlistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Wishlist")
                .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(wantToVisitCountries) { country in
                        NavigationLink {
                            CountryDetailScreen(country: country)
                        } label: {
                            VStack(spacing: 6) {
                                ZStack(alignment: .topTrailing) {
                                    Text(country.flagEmoji)
                                        .font(.system(size: 34))
                                        .frame(width: 50, height: 50)
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color(hex: "#4A90D9"))
                                        .offset(x: 2, y: -2)
                                }
                                .padding(10)
                                .background(Color.appCard)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)

                                Text(country.name)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.appInk)
                                    .lineLimit(1)
                            }
                            .frame(width: 70)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Visited Countries

    private var visitedCountriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("All visited countries")
                .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(visitedCountries) { country in
                        NavigationLink {
                            CountryDetailScreen(country: country)
                        } label: {
                            VStack(spacing: 6) {
                                Text(country.flagEmoji)
                                    .font(.system(size: 34))
                                    .frame(width: 50, height: 50)
                                    .padding(10)
                                    .background(Color.appCard)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)

                                Text(country.name)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.appInk)
                                    .lineLimit(1)
                            }
                            .frame(width: 70)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Continent Progress

    private var continentProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Continent progress")
            VStack(spacing: 0) {
                ForEach(Array(visitedByContinent.enumerated()), id: \.element.continent.id) { index, item in
                    if index > 0 {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                    HStack(spacing: 12) {
                        Text(continentShortName(item.continent))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.appInk)
                            .frame(width: 84, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.appLine)
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.appInk)
                                    .frame(
                                        width: max(geo.size.width * (item.percentage / 100), item.visited > 0 ? 6 : 0),
                                        height: 6
                                    )
                            }
                        }
                        .frame(height: 6)

                        Text("\(item.visited)/\(item.total)")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.appInk3)
                            .frame(width: 38, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        }
    }

    // MARK: - Badges

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Badges")
                .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(achievements) { achievement in
                        AchievementCard(achievement: achievement) {
                            selectedAchievement = achievement
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Recent Memories

    private var recentMemoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Recent memories")
            ForEach(Array(recentVisits.prefix(5)), id: \.country.id) { item in
                NavigationLink {
                    CountryDetailScreen(country: item.country)
                } label: {
                    memoryCard(country: item.country, date: item.date)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func memoryCard(country: Country, date: Date?) -> some View {
        let visit = visitedVisits.first { $0.countryId == country.id }
        let firstPhoto = visit?.photos.first
        let notes = visit?.notes ?? ""

        return VStack(alignment: .leading, spacing: 0) {
            if let photo = firstPhoto, let uiImage = UIImage(data: photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
            } else {
                Text(country.flagEmoji)
                    .font(.system(size: 64))
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .background(Color.appPaper2)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(country.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.appInk)
                if !notes.isEmpty {
                    Text("\"\(notes)\"")
                        .font(.system(size: 13))
                        .italic()
                        .foregroundStyle(Color.appInk2)
                        .lineLimit(2)
                }
                if let date {
                    Text(date.formatted(date: .abbreviated, time: .omitted).uppercased())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.appInk3)
                        .tracking(0.5)
                        .padding(.top, 2)
                }
            }
            .padding(16)
        }
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Color.appInk)
    }

    private func continentShortName(_ continent: Continent) -> String {
        switch continent {
        case .northAmerica: return "N. America"
        case .southAmerica: return "S. America"
        default: return continent.displayName
        }
    }

    // MARK: - ViewModel

    @MainActor
    final class StatsViewModel: ObservableObject {
        @Published private(set) var countries: [Country] = []
        @Published private(set) var isLoading = false

        private let service = CountryDataService.shared

        init() { load() }

        func load() {
            isLoading = true
            Task(priority: .userInitiated) {
                let loaded = service.loadCountries()
                self.countries = loaded
                self.isLoading = false
            }
        }

        func achievements(from visits: [String: Visit]) -> [Achievement] {
            AchievementEngine.calculateAchievements(visits: visits, countries: countries)
        }
    }

    // MARK: - Achievement Card

    private struct AchievementCard: View {
        let achievement: Achievement
        let onTap: () -> Void

        private var label: String { achievement.badgeLabel }

        var body: some View {
            Button(action: onTap) {
                VStack(spacing: 8) {
                    Text(achievement.isUnlocked ? "🏆" : "🔒")
                        .font(.system(size: 30))
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.appInk)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .frame(width: 90, height: 90)
                .background(achievement.isUnlocked ? Color.appGoldBg : Color.appPaper2)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
                .opacity(achievement.isUnlocked ? 1.0 : 0.6)
            }
            .buttonStyle(.plain)
        }
    }

    private struct BadgeDetailSheet: View {
        let achievement: Achievement
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Text(achievement.isUnlocked ? "🏆" : "🔒")
                        .font(.system(size: 56))
                        .padding(.top, 32)

                    Text(achievement.badgeLabel)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.appInk)

                    Text(achievement.isUnlocked ? "UNLOCKED" : "LOCKED")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(achievement.isUnlocked ? Color(hex: "#1E7F4E") : Color.appInk3)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(achievement.isUnlocked ? Color(hex: "#1E7F4E").opacity(0.1) : Color.appPaper2)
                        .clipShape(Capsule())
                }

                VStack(alignment: .leading, spacing: 16) {
                    infoRow(title: "ABOUT", body: achievement.badgeDescription)
                    if !achievement.isUnlocked {
                        Divider()
                        infoRow(title: "HOW TO UNLOCK", body: achievement.unlockRequirement)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.appPaper)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 24)
                .padding(.top, 24)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color.appCard)
        }

        private func infoRow(title: String, body: String) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.appInk3)
                    .tracking(0.8)
                Text(body)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.appInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Achievement display helpers

private extension Achievement {
    var badgeLabel: String {
        switch type {
        case .firstCountry:     return "Nomad"
        case .firstNote:        return "Journalist"
        case .firstPhoto:       return "Photographer"
        case .countries(let n): return "\(n) Countries"
        case .continents(let n):return "\(n) Continents"
        case .allContinents:    return "Jetsetter"
        }
    }

    var badgeDescription: String {
        switch type {
        case .firstCountry:
            return "Awarded to explorers who have visited their first country. Every great journey starts with a single step."
        case .firstNote:
            return "Awarded to travellers who have written their first memory. Words keep the spirit of a journey alive."
        case .firstPhoto:
            return "Awarded to those who captured their first travel photo. A picture is worth a thousand memories."
        case .countries(let n):
            return "Awarded for visiting \(n) countries. The world is vast, and you are making your mark on it."
        case .continents(let n):
            return "Awarded for setting foot on \(n) different continents. You are a true multi-continental explorer."
        case .allContinents:
            return "Awarded to the rare few who have visited all 7 continents. The world is your home."
        }
    }

    var unlockRequirement: String {
        switch type {
        case .firstCountry:
            return "Mark any country as visited."
        case .firstNote:
            return "Add a note to any visited country."
        case .firstPhoto:
            return "Add a photo to any visited country."
        case .countries(let n):
            return "Visit \(n) countries in total."
        case .continents(let n):
            return "Visit at least one country on \(n) different continents."
        case .allContinents:
            return "Visit at least one country on every continent."
        }
    }
}

// MARK: - Visited This Year List View

struct VisitedThisYearListView: View {
    let visits: [(country: Country, date: Date)]

    var body: some View {
        List {
            ForEach(visits, id: \.country.id) { item in
                NavigationLink {
                    CountryDetailScreen(country: item.country)
                } label: {
                    HStack(spacing: 12) {
                        Text(item.country.flagEmoji)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.country.name)
                                .font(.body)
                            Text(item.country.continent.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Visited This Year")
        .navigationBarTitleDisplayMode(.inline)
    }
}
