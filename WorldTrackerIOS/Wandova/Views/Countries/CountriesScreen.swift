//
//  CountriesScreen.swift
//  Wandova
//
//  Created by seren on 25.02.2026.
//

import SwiftUI

// MARK: - Countries Screen

struct CountriesScreen: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = CountriesViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    continentChips
                        .padding(.top, 12)

                    if vm.isSearching {
                        searchResults
                            .padding(.top, 12)
                    } else {
                        summaryLabel
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 12)

                        continentGrid
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Color.appPaper)
            .navigationTitle("Countries")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { vm.load() }
        }
    }

    // MARK: Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(Color.appInk2)
            TextField("Search countries...", text: $vm.searchText)
                .font(.system(size: 16))
                .foregroundStyle(Color.appInk)
            if !vm.searchText.isEmpty {
                Button { vm.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.appInk3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Color.appPaper2)
        .clipShape(Capsule())
    }

    // MARK: Continent Chips

    private var continentChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                continentChip("All", isSelected: vm.selectedContinent == nil) {
                    vm.selectedContinent = nil
                }
                ForEach(Continent.allCases) { c in
                    continentChip(c.displayName, isSelected: vm.selectedContinent == c) {
                        vm.selectedContinent = c
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func continentChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : Color.appInk2)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(isSelected ? Color.appSurface : Color.appCard)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.clear : Color.appLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Summary Label

    private var summaryLabel: some View {
        let allCountries = vm.countries
        let totalVisited = allCountries.filter { appState.isVisited($0.id) }.count
        let continentsWithVisit = Set(
            allCountries.filter { appState.isVisited($0.id) }.map { $0.continent }
        ).count

        return Text("\(continentsWithVisit) CONTINENTS · \(totalVisited) COUNTRIES VISITED")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.appInk3)
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Continent Grid

    private var continentGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            ForEach(vm.groupedByContinent, id: \.continent.id) { section in
                NavigationLink {
                    ContinentCountriesView(
                        continent: section.continent,
                        countries: section.countries
                    )
                } label: {
                    ContinentCard(
                        continent: section.continent,
                        totalCount: section.countries.count,
                        visitedCount: section.countries.filter { appState.isVisited($0.id) }.count
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Search Results

    private var searchResults: some View {
        VStack(spacing: 8) {
            if vm.filteredCountries.isEmpty {
                Text("No countries match \"\(vm.searchText)\"")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appInk3)
                    .padding(.top, 40)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(vm.filteredCountries) { country in
                    NavigationLink {
                        CountryDetailScreen(country: country)
                    } label: {
                        CountryListRow(
                            country: country,
                            isVisited: appState.isVisited(country.id),
                            isWishlist: appState.wantToVisit(country.id)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Continent Card

private struct ContinentCard: View {
    let continent: Continent
    let totalCount: Int
    let visitedCount: Int

    private var percentage: Double {
        guard totalCount > 0 else { return 0 }
        return Double(visitedCount) / Double(totalCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(continent.displayName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.appInk)
                .tracking(-0.3)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.appLine)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(continentColor)
                        .frame(width: max(geo.size.width * percentage, percentage > 0 ? 6 : 0), height: 4)
                }
            }
            .frame(height: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(visitedCount) VISITED")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(continentColor)
                    .tracking(0.3)
                Text("of \(totalCount) \(totalCount == 1 ? "country" : "countries")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.appInk3)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    private var continentColor: Color {
        switch continent {
        case .europe:       return Color(hex: "#F9234D")
        case .asia:         return Color(hex: "#F1528A")
        case .africa:       return Color(hex: "#E6A817")
        case .oceania:      return Color(hex: "#1D8FC2")
        case .northAmerica: return Color(hex: "#4A90D9")
        case .southAmerica: return Color(hex: "#F37826")
        case .antarctica:   return Color(hex: "#9E9E9E")
        }
    }
}

// MARK: - Continent Countries View

struct ContinentCountriesView: View {
    @EnvironmentObject private var appState: AppState
    let continent: Continent
    let countries: [Country]

    @State private var searchText = ""
    @State private var filterMode: FilterMode = .all

    enum FilterMode: String, CaseIterable {
        case all = "All"
        case visited = "Visited"
        case notVisited = "Not Visited"
        case wishlist = "Wishlist"
    }

    private var filtered: [Country] {
        var result = countries.sorted { $0.name < $1.name }
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
        }
        switch filterMode {
        case .all:        break
        case .visited:    result = result.filter { appState.isVisited($0.id) }
        case .notVisited: result = result.filter { !appState.isVisited($0.id) }
        case .wishlist:   result = result.filter { appState.wantToVisit($0.id) }
        }
        return result
    }

    private var groupedAlphabetically: [(letter: String, countries: [Country])] {
        let grouped = Dictionary(grouping: filtered) { String($0.name.prefix(1)).uppercased() }
        return grouped.keys.sorted().map { key in (key, grouped[key]!.sorted { $0.name < $1.name }) }
    }

    private var visitedCount: Int {
        countries.filter { appState.isVisited($0.id) }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                filterChips
                    .padding(.top, 12)

                Text("\(visitedCount) of \(countries.count) countries visited in \(continent.displayName)")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appInk3)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                if filtered.isEmpty {
                    Text("No countries match your filter")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.appInk3)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(groupedAlphabetically, id: \.letter) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.letter)
                                    .font(.system(size: 17, weight: .black))
                                    .foregroundStyle(Color.appInk)
                                    .padding(.horizontal, 16)

                                VStack(spacing: 8) {
                                    ForEach(group.countries) { country in
                                        NavigationLink {
                                            CountryDetailScreen(country: country)
                                        } label: {
                                            CountryListRow(
                                                country: country,
                                                isVisited: appState.isVisited(country.id),
                                                isWishlist: appState.wantToVisit(country.id)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(Color.appPaper)
        .navigationTitle(continent.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(Color.appInk2)
            TextField("Search \(continent.displayName)...", text: $searchText)
                .font(.system(size: 16))
                .foregroundStyle(Color.appInk)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.appInk3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Color.appPaper2)
        .clipShape(Capsule())
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FilterMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.spring(response: 0.3)) { filterMode = mode }
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(filterMode == mode ? .white : Color.appInk)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(filterMode == mode ? Color.appSurface : Color.appCard)
                            .clipShape(Capsule())
                            .overlay(filterMode == mode ? nil : Capsule().stroke(Color.appLine, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Country List Row

struct CountryListRow: View {
    let country: Country
    let isVisited: Bool
    let isWishlist: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(country.flagEmoji)
                .font(.system(size: 28))
                .frame(width: 40, height: 36)

            Text(country.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.appInk)

            Spacer()

            if isVisited {
                Text("VISITED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(hex: "#1E7F4E"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#1E7F4E").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else if isWishlist {
                Image(systemName: "star.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(hex: "#4A90D9"))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.appInk3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 1)
    }
}
