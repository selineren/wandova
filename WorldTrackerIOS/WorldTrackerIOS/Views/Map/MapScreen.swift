//
//  MapScreen.swift
//  WorldTrackerIOS
//
//  Created by seren on 25.02.2026.
//

import SwiftUI
import FirebaseAuth
import MapKit

struct MapScreen: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authService: AuthService

    var onNavigateToStats: () -> Void = {}
    var onNavigateToCountries: () -> Void = {}

    @State private var showSyncStatus = true
    @State private var selectedCountryForSheet: SelectedCountry?
    @State private var selectedCountryForDetail: Country?
    @State private var mapZoomLevel: MapZoomLevel = .continent
    @State private var showingMapUI = true
    @State private var filterMode: FilterMode = .all
    @State private var totalCountries: Int = 0
    @State private var allCountries: [Country] = []
    @State private var isPopupExpanded = false
    @State private var showingMemoriesSheet = false

    enum FilterMode: String, CaseIterable {
        case all = "All"
        case visited = "Visited"
        case wishlist = "Wishlist"
    }

    private var filteredVisitedCountryIDs: Set<String> {
        switch filterMode {
        case .all, .visited: return appState.visitedCountryIDs
        case .wishlist:      return []
        }
    }

    private var filteredWantToVisitCountryIDs: Set<String> {
        switch filterMode {
        case .all:     return appState.wantToVisitCountryIDs
        case .visited: return []
        case .wishlist: return appState.wantToVisitCountryIDs
        }
    }

    private var isSyncError: Bool {
        if case .error = appState.syncStatus { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                MapContainerView(
                    visitedCountryIDs: filteredVisitedCountryIDs,
                    wantToVisitCountryIDs: filteredWantToVisitCountryIDs,
                    zoomLevel: $mapZoomLevel,
                    bitmojiAnnotations: getBitmojiAnnotations(),
                    onCountryTapped: { countryID in
                        handleCountryTap(countryID: countryID)
                    },
                    onBitmojiTapped: nil
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack(alignment: .center, spacing: 12) {
                        eyeButton
                        Spacer()
                        if showingMapUI {
                            statsCard
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    if showSyncStatus && (showingMapUI || isSyncError) {
                        SyncStatusView(
                            status: appState.syncStatus,
                            onRetry: {
                                Task { await appState.retrySyncIfNeeded() }
                            },
                            onDismiss: {
                                withAnimation { showSyncStatus = false }
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Spacer()

                    if showingMapUI {
                        VStack(spacing: 12) {
                            HStack(alignment: .bottom) {
                                legendCard
                                Spacer()
                                zoomControls
                                    .fixedSize()
                            }
                            .padding(.horizontal, 16)

                            filterPicker
                                .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    if showingMapUI {
                        whereHaveYouBeenPopup
                            .padding(.bottom, 36)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

            }
            .toolbar(.hidden, for: .navigationBar)
            .task(id: authService.user?.uid) {
                await handleAuthStateChange()
            }
            .onChange(of: appState.syncStatus) { oldValue, newValue in
                if case .idle = oldValue, case .idle = newValue {
                } else {
                    withAnimation { showSyncStatus = true }
                    if case .success = newValue {
                        Task {
                            try? await Task.sleep(for: .seconds(3))
                            withAnimation { showSyncStatus = false }
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task { await refreshMapData() }
            }
            .sheet(isPresented: $showingMemoriesSheet) {
                MapMemoriesSheet(visits: appState.visits, countries: allCountries)
            }
            .sheet(item: $selectedCountryForSheet) { selectedCountry in
                CountryQuickActionSheet(
                    countryID: selectedCountry.id,
                    appState: appState,
                    onViewDetails: { country in
                        selectedCountryForDetail = country
                        selectedCountryForSheet = nil
                    }
                )
                .presentationDetents([.height(340), .medium])
                .presentationDragIndicator(.visible)
            }
            .navigationDestination(item: $selectedCountryForDetail) { country in
                CountryDetailScreen(country: country)
            }
            .task {
                let countries = CountryDataService.shared.loadCountries()
                totalCountries = countries.count
                allCountries = countries
            }
        }
    }

    // MARK: - Eye Button

    private var eyeButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                showingMapUI.toggle()
            }
        } label: {
            Image(systemName: showingMapUI ? "eye" : "eye.slash")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.appInk)
                .frame(width: 40, height: 40)
                .background(Color.appCard)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Zoom Controls

    private var zoomControls: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { zoomIn() }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(canZoomIn ? Color.appInk : Color.appInk3)
                    .frame(width: 40, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canZoomIn)

            Rectangle()
                .fill(Color.appLine)
                .frame(width: 28, height: 1)

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { zoomOut() }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(canZoomOut ? Color.appInk : Color.appInk3)
                    .frame(width: 40, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canZoomOut)
        }
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
    }

    private var canZoomIn: Bool { mapZoomLevel != .max }
    private var canZoomOut: Bool { mapZoomLevel != .world }

    private func zoomIn() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        switch mapZoomLevel {
        case .world:     mapZoomLevel = .continent
        case .continent: mapZoomLevel = .country
        case .country:   mapZoomLevel = .city
        case .city:      mapZoomLevel = .max
        case .max:       break
        }
    }

    private func zoomOut() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        switch mapZoomLevel {
        case .max:       mapZoomLevel = .city
        case .city:      mapZoomLevel = .country
        case .country:   mapZoomLevel = .continent
        case .continent: mapZoomLevel = .world
        case .world:     break
        }
    }

    // MARK: - Filter Picker

    private var filterPicker: some View {
        HStack(spacing: 8) {
            ForEach(FilterMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        filterMode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(filterMode == mode ? Color.white : Color.appInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(filterMode == mode ? Color.appSurface : Color.appCard)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appInk3)
                Text("VISITED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.appInk3)
                    .tracking(0.5)
            }

            Rectangle()
                .fill(Color.appLine)
                .frame(width: 1, height: 16)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(appState.visitedCountryIDs.count)")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Color.appInk)
                Text("/ \(totalCountries)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.appInk3)
            }

            if totalCountries > 0 {
                Rectangle()
                    .fill(Color.appLine)
                    .frame(width: 1, height: 16)

                let pct = Double(appState.visitedCountryIDs.count) / Double(totalCountries) * 100
                Text(String(format: "%.1f%% WORLD", pct))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.appInk3)
                    .tracking(0.5)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
    }

    // MARK: - Legend Card

    private var legendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MAP LEGEND")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.appInk3)
                .tracking(1.2)

            VStack(alignment: .leading, spacing: 8) {
                if filterMode == .all || filterMode == .visited {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.appVisited)
                            .frame(width: 10, height: 10)
                        Text("VISITED")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(Color.appInk)
                            .tracking(0.5)
                    }
                }

                if filterMode == .all || filterMode == .wishlist {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.appWishlist)
                            .frame(width: 10, height: 10)
                        Text("WISHLIST")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(Color.appInk)
                            .tracking(0.5)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.appCard.opacity(0.92))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }

    // MARK: - Where Have You Been Popup

    private var recentVisits: [(country: Country, visit: Visit)] {
        allCountries.compactMap { country in
            guard let visit = appState.visits[country.id], visit.isVisited else { return nil }
            return (country, visit)
        }
        .sorted {
            let a = $0.visit.visitedDate ?? $0.visit.updatedAt
            let b = $1.visit.visitedDate ?? $1.visit.updatedAt
            return a > b
        }
        .prefix(3)
        .map { $0 }
    }

    private func visitSubtitle(_ visit: Visit) -> String {
        let notes = visit.notes.trimmingCharacters(in: .whitespaces)
        if let date = visit.visitedDate {
            let formatted = date.formatted(.dateTime.month(.abbreviated).year())
            return notes.isEmpty ? formatted : "\(notes) · \(formatted)"
        }
        return notes.isEmpty ? "" : notes
    }

    private var whereHaveYouBeenPopup: some View {
        VStack(spacing: 0) {

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.appInk3)
                    .frame(width: 36, height: 5)
                    .padding(.top, 14)
                    .padding(.bottom, 16)

                HStack {
                    Text("Where have you been?")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.appInk)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, isPopupExpanded ? 20 : 18)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isPopupExpanded.toggle()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        let dy = value.translation.height
                        if dy < -30 && !isPopupExpanded {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isPopupExpanded = true }
                        } else if dy > 30 && isPopupExpanded {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isPopupExpanded = false }
                        }
                    }
            )

            if isPopupExpanded {

                HStack(spacing: 12) {
                    quickActionButton(icon: "photo.stack.fill", label: "Memories") {
                        showingMemoriesSheet = true
                    }
                    quickActionButton(icon: "chart.bar.fill", label: "Stats") {
                        onNavigateToStats()
                        withAnimation(.spring(response: 0.3)) { isPopupExpanded = false }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                HStack {
                    Text("Recent visits")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.appInk)
                    Spacer()
                    Button {
                        onNavigateToCountries()
                        withAnimation(.spring(response: 0.3)) { isPopupExpanded = false }
                    } label: {
                        HStack(spacing: 4) {
                            Text("See all")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.appInk)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.appInk)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                let recent = recentVisits
                if recent.isEmpty {
                    Text("Mark countries as visited to see them here")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.appInk3)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                } else {
                    VStack(spacing: 0) {
                        ForEach(recent, id: \.country.id) { item in
                            Button {
                                selectedCountryForDetail = item.country
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isPopupExpanded = false
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.appPaper2)
                                            .frame(width: 48, height: 48)
                                        Text(item.country.flagEmoji)
                                            .font(.system(size: 24))
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.country.name)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Color.appInk)
                                        let subtitle = visitSubtitle(item.visit)
                                        if !subtitle.isEmpty {
                                            Text(subtitle)
                                                .font(.system(size: 13))
                                                .foregroundStyle(Color.appInk3)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.appInk3)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)

                            if item.country.id != recent.last?.country.id {
                                Divider().padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: -4)
        .padding(.horizontal, 16)
    }

    private func quickActionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.appSurface)
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                }
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appInk)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(Color.appPaper2)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data Management

    private func handleCountryTap(countryID: String) {
        selectedCountryForSheet = SelectedCountry(id: countryID)
    }

    private func getBitmojiAnnotations() -> [CountryBitmojiAnnotation] {
        guard mapZoomLevel != .world else { return [] }
        guard filterMode == .all || filterMode == .visited else { return [] }

        let countries = CountryDataService.shared.loadCountries()

        let annotations: [CountryBitmojiAnnotation] = appState.visitedCountryIDs.compactMap { countryID -> CountryBitmojiAnnotation? in
            guard let country = countries.first(where: { $0.id == countryID }) else { return nil }
            let visit = appState.visit(for: countryID)
            return CountryBitmojiAnnotation(country: country, visit: visit)
        }

        return annotations
    }

    private func handleAuthStateChange() async {
        guard authService.isSignedIn else { return }
        await refreshMapData()
    }

    private func refreshMapData() async {
        guard authService.isSignedIn else { return }
        appState.refreshFromPersistence()
        await appState.syncWithCloud()
    }
}

// MARK: - Map Zoom Level

struct SelectedCountry: Identifiable {
    let id: String
}

enum MapZoomLevel: Equatable {
    case world
    case continent
    case country
    case city
    case max

    var latitudeDelta: CLLocationDegrees {
        switch self {
        case .world:     return 120
        case .continent: return 60
        case .country:   return 20
        case .city:      return 5
        case .max:       return 1
        }
    }

    var longitudeDelta: CLLocationDegrees { latitudeDelta }
}

// MARK: - Country Quick Action Sheet

struct CountryQuickActionSheet: View {
    let countryID: String
    @ObservedObject var appState: AppState
    let onViewDetails: (Country) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var country: Country?
    @State private var isLoading = true

    private var isVisited: Bool { appState.isVisited(countryID) }
    private var wantToVisit: Bool { appState.wantToVisit(countryID) }

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.appInk3)
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if let country = country {
                VStack(spacing: 10) {
                    Text(country.flagEmoji)
                        .font(.system(size: 60))

                    Text(country.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.appInk)

                    HStack(spacing: 8) {
                        Text(country.continent.displayName)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.appInk3)

                        if isVisited {
                            statusPill("Visited", fg: Color(hex: "#2E9E5B"), bg: Color.appSuccess.opacity(0.12))
                        } else if wantToVisit {
                            statusPill("Wishlist", fg: Color(hex: "#1D8FC2"), bg: Color(hex: "#4A90D9").opacity(0.12))
                        }
                    }
                }
                .padding(.bottom, 24)

                VStack(spacing: 0) {
                    actionRow(
                        icon: "checkmark.circle.fill",
                        iconBg: isVisited ? Color.appSuccess.opacity(0.12) : Color.appInk.opacity(0.06),
                        iconFg: isVisited ? Color.appSuccess : Color.appInk3,
                        title: isVisited ? "Mark as Not Visited" : "Mark as Visited",
                        chevron: false,
                        disabled: false
                    ) { toggleVisited() }

                    Divider().padding(.horizontal, 16)

                    actionRow(
                        icon: wantToVisit ? "star.fill" : "star",
                        iconBg: wantToVisit ? Color(hex: "#4A90D9").opacity(0.12) : Color.appInk.opacity(0.06),
                        iconFg: wantToVisit ? Color(hex: "#4A90D9") : Color.appInk3,
                        title: wantToVisit ? "Remove from Wishlist" : "Add to Wishlist",
                        chevron: false,
                        disabled: isVisited
                    ) { toggleWantToVisit() }

                    Divider().padding(.horizontal, 16)

                    actionRow(
                        icon: "arrow.right.circle.fill",
                        iconBg: Color(hex: "#4A90D9").opacity(0.12),
                        iconFg: Color(hex: "#4A90D9"),
                        title: "View Details",
                        chevron: true,
                        disabled: false
                    ) { onViewDetails(country) }
                }
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
                .padding(.horizontal, 16)

                Spacer()
            } else {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.appInk3)
                    Text("Country not found")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.appInk3)
                }
                Spacer()
            }
        }
        .background(Color.appPaper)
        .task { await loadCountry() }
    }

    private func statusPill(_ label: String, fg: Color, bg: Color) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(bg)
            .clipShape(Capsule())
    }

    private func actionRow(icon: String, iconBg: Color, iconFg: Color, title: String, chevron: Bool, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(iconBg).frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(iconFg)
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(disabled ? Color.appInk3 : Color.appInk)
                Spacer()
                if chevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.appInk3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled || country == nil)
    }

    private func loadCountry() async {
        let countries = CountryDataService.shared.loadCountries()
        country = countries.first { $0.id == countryID }
        isLoading = false
    }

    private func toggleVisited() {
        appState.setVisited(countryID, isVisited: !isVisited)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { dismiss() }
    }

    private func toggleWantToVisit() {
        appState.setWantToVisit(countryID, wantToVisit: !wantToVisit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { dismiss() }
    }
}

// MARK: - Map Container (Optimization)
struct MapContainerView: View {
    let visitedCountryIDs: Set<String>
    let wantToVisitCountryIDs: Set<String>
    @Binding var zoomLevel: MapZoomLevel
    let bitmojiAnnotations: [CountryBitmojiAnnotation]
    let onCountryTapped: ((String) -> Void)?
    let onBitmojiTapped: ((String) -> Void)?

    var body: some View {
        VisitedCountriesMapView(
            visitedCountryIDs: visitedCountryIDs,
            wantToVisitCountryIDs: wantToVisitCountryIDs,
            zoomLevel: $zoomLevel,
            onCountryTapped: onCountryTapped,
            bitmojiAnnotations: bitmojiAnnotations,
            onBitmojiTapped: onBitmojiTapped
        )
    }
}

// MARK: - Memories Sheet

struct MapMemoriesSheet: View {
    @Environment(\.dismiss) private var dismiss
    let visits: [String: Visit]
    let countries: [Country]

    private struct PhotoEntry: Identifiable {
        let id: UUID
        let photo: VisitPhoto
        let country: Country
    }

    private var allPhotos: [PhotoEntry] {
        countries.flatMap { country -> [PhotoEntry] in
            guard let visit = visits[country.id], visit.isVisited else { return [] }
            return visit.photos.map { PhotoEntry(id: $0.id, photo: $0, country: country) }
        }
        .sorted { $0.photo.createdAt > $1.photo.createdAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Memories")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.appInk)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.appInk3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)

            if allPhotos.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.appInk3)
                    Text("No memories yet")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                    Text("Add photos when marking countries\nas visited to see them here")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.appInk3)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3)],
                        spacing: 3
                    ) {
                        ForEach(allPhotos) { entry in
                            GeometryReader { geo in
                                ZStack(alignment: .bottomLeading) {
                                    if let uiImage = UIImage(data: entry.photo.imageData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: geo.size.width, height: geo.size.width)
                                            .clipped()
                                    } else {
                                        Rectangle()
                                            .fill(Color.appPaper2)
                                            .frame(width: geo.size.width, height: geo.size.width)
                                    }

                                    LinearGradient(
                                        colors: [.clear, .black.opacity(0.55)],
                                        startPoint: .center,
                                        endPoint: .bottom
                                    )

                                    HStack(spacing: 4) {
                                        Text(entry.country.flagEmoji)
                                            .font(.system(size: 13))
                                        Text(entry.country.name)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.bottom, 8)
                                }
                            }
                            .aspectRatio(1, contentMode: .fill)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .background(Color.appPaper)
    }
}
