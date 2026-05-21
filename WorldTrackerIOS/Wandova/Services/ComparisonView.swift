//
//  ComparisonView.swift
//  Wandova
//
//  Created by seren on 13.04.2026.
//

import SwiftUI
import Combine
import FirebaseAuth

struct ComparisonView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authService: AuthService
    @StateObject private var viewModel = ComparisonViewModel()
    @State private var lastUserId: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appPaper.ignoresSafeArea()
                switch viewModel.state {
                case .idle:
                    searchView
                case .loading:
                    loadingView
                case .loaded:
                    resultsView
                case .error(let message):
                    errorView(message: message)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if case .loaded = viewModel.state {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button { viewModel.resetToIdle() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.appInk)
                        }
                    }
                }
            }
            .onAppear {
                let currentUserId = authService.user?.uid
                if lastUserId != currentUserId {
                    lastUserId = currentUserId
                    viewModel.resetToIdle()
                }
            }
            .onChange(of: appState.visits) { _, newVisits in
                if case .loaded = viewModel.state {
                    viewModel.reloadComparison(yourVisits: newVisits)
                }
            }
        }
    }

    private var navigationTitle: String {
        if case .loaded = viewModel.state { return "Travel comparison" }
        return "Compare"
    }

    // MARK: - Search (Idle) View

    private var searchView: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroEntryCard
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                VStack(alignment: .leading, spacing: 12) {
                    Text("FRIEND'S EMAIL")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.appInk3)
                        .tracking(0.8)

                    HStack(spacing: 12) {
                        Image(systemName: "envelope")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.appInk3)
                        TextField("friend@example.com", text: $viewModel.emailToCompare)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.appInk)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .onSubmit {
                                Task { await viewModel.searchUser(yourVisits: appState.visits) }
                            }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(Color.appPaper2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button {
                        Task { await viewModel.searchUser(yourVisits: appState.visits) }
                    } label: {
                        Text("Compare travels")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.appSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(viewModel.emailToCompare.isEmpty)
                    .opacity(viewModel.emailToCompare.isEmpty ? 0.5 : 1)
                }
                .padding(16)
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
                .padding(.horizontal, 16)

                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                    Text("Only works with users who have enabled comparison in their privacy settings")
                        .font(.system(size: 12))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Color.appInk3)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    private var heroEntryCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: -12) {
                avatarCircle(initials: myInitials, bg: Color.appSurface.opacity(0.7))
                avatarCircle(initials: "?", bg: Color.appSurface)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Compare your travels\nwith anyone")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                Text("See countries you've both been to, where you'd love to go together, and trips worth planning.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.3)
            Text("Loading comparison...")
                .font(.system(size: 14))
                .foregroundStyle(Color.appInk3)
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 16) {
                    Text("😕")
                        .font(.system(size: 48))
                    Text("Something went wrong")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 16)
                .padding(.top, 20)

                Button { viewModel.resetToIdle() } label: {
                    Text("Try Again")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Results View

    private var resultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let profile = viewModel.comparedUserProfile {
                    heroResultsCard(profile: profile)
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                }

                let wishlistShared = viewModel.wishlistComparison.shared.count
                if wishlistShared > 0 {
                    planTripCard(matchCount: wishlistShared)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                }

                HStack(spacing: 8) {
                    modeChip("Visited", mode: .visited)
                    modeChip("Wishlist", mode: .wishlist)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)

                if viewModel.currentComparison.totalUnique == 0 {
                    Text("No \(viewModel.selectedMode == .visited ? "visited" : "wishlisted") countries to compare")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.appInk3)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 32)
                        .padding(.horizontal, 32)
                        .multilineTextAlignment(.center)
                } else {
                    if !viewModel.sharedCountries.isEmpty {
                        countrySection(label: "BOTH", countries: viewModel.sharedCountries, badge: .shared)
                            .padding(.top, 20)
                    }
                    if !viewModel.yourCountries.isEmpty {
                        countrySection(label: "ONLY YOU", countries: viewModel.yourCountries, badge: .yours)
                            .padding(.top, 20)
                    }
                    if !viewModel.theirCountries.isEmpty {
                        let friendName = viewModel.comparedUserProfile.map { friendShortName(from: $0) } ?? "THEM"
                        countrySection(
                            label: "ONLY \(friendName.uppercased())",
                            countries: viewModel.theirCountries,
                            badge: .theirs
                        )
                        .padding(.top, 20)
                    }
                }

                Spacer().frame(height: 32)
            }
        }
    }

    private func heroResultsCard(profile: UserProfile) -> some View {
        let sharedCount = viewModel.visitedComparison.shared.count
        let yourCount = viewModel.visitedComparison.yours.count
        let theirCount = viewModel.visitedComparison.theirs.count
        let friendName = friendShortName(from: profile)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                HStack(spacing: -14) {
                    Text(myInitials)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.appInk)
                        .frame(width: 44, height: 44)
                        .background(Color.appCard)
                        .clipShape(Circle())
                    Text(friendInitials(from: profile))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color(hex: "#6C8EFF"))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.appSurface, lineWidth: 2))
                }

                Spacer()

                Text(profile.email)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("YOU & \(friendName.uppercased())")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .tracking(0.5)

                Text("\(sharedCount) countries in common")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .tracking(-0.3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 1)

            HStack(spacing: 0) {
                statColumn(value: "\(sharedCount)", label: "Together")
                Rectangle().fill(Color.white.opacity(0.15)).frame(width: 1, height: 44)
                statColumn(value: "\(yourCount)", label: "Only you")
                Rectangle().fill(Color.white.opacity(0.15)).frame(width: 1, height: 44)
                statColumn(value: "\(theirCount)", label: "Only \(friendName)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func planTripCard(matchCount: Int) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.appInk.opacity(0.06))
                    .frame(width: 44, height: 44)
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.appInk)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Plan a trip together")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.appInk)
                Text("\(matchCount) wishlist \(matchCount == 1 ? "match" : "matches")")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appInk3)
            }
            Spacer()
            Button {
                viewModel.selectedMode = .wishlist
            } label: {
                Text("Plan")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(Color.appSurface)
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    private func modeChip(_ title: String, mode: ComparisonMode) -> some View {
        Button { viewModel.selectedMode = mode } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(viewModel.selectedMode == mode ? .white : Color.appInk2)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(viewModel.selectedMode == mode ? Color.appSurface : Color.appCard)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(viewModel.selectedMode == mode ? Color.clear : Color.appLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func countrySection(label: String, countries: [Country], badge: ComparisonBadge) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.appInk3)
                .tracking(0.8)
                .padding(.horizontal, 16)

            VStack(spacing: 8) {
                ForEach(countries) { country in
                    NavigationLink {
                        CountryDetailScreen(country: country)
                    } label: {
                        HStack(spacing: 12) {
                            Text(country.flagEmoji)
                                .font(.system(size: 28))
                                .frame(width: 40, height: 36)
                            Text(country.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.appInk)
                            Spacer()
                            Text(badge.label)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(badge.pillForeground)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(badge.pillBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
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
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Helpers

    private func avatarCircle(initials: String, bg: Color) -> some View {
        Text(initials)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(bg)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.appSurface, lineWidth: 2))
    }

    private var myInitials: String {
        if let name = authService.user?.displayName, !name.trimmingCharacters(in: .whitespaces).isEmpty {
            let parts = name.components(separatedBy: " ").filter { !$0.isEmpty }
            if parts.count >= 2 {
                return (parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
            }
            return String(parts[0].prefix(2)).uppercased()
        }
        guard let email = authService.user?.email else { return "ME" }
        return emailInitials(email)
    }

    private func friendInitials(from profile: UserProfile) -> String {
        if !profile.firstName.isEmpty {
            let f = String(profile.firstName.prefix(1)).uppercased()
            let l = String(profile.lastName.prefix(1)).uppercased()
            return l.isEmpty ? f : f + l
        }
        return emailInitials(profile.email)
    }

    private func emailInitials(_ email: String) -> String {
        let username = String(email.split(separator: "@").first ?? "?")
        let parts = username.split(separator: ".")
        if parts.count >= 2 {
            return (String(parts[0].prefix(1)) + String(parts[1].prefix(1))).uppercased()
        }
        return String(username.prefix(2)).uppercased()
    }

    private func friendShortName(from profile: UserProfile) -> String {
        if !profile.firstName.isEmpty {
            return String(profile.firstName.prefix(10))
        }
        let username = String(profile.email.split(separator: "@").first ?? Substring(profile.email))
        let first = String(username.split(separator: ".").first ?? Substring(username))
        return first.prefix(10).capitalized
    }
}

// MARK: - Comparison Badge

enum ComparisonBadge {
    case yours
    case shared
    case theirs

    var label: String {
        switch self {
        case .yours:   return "Only You"
        case .shared:  return "Both"
        case .theirs:  return "Only Them"
        }
    }

    var pillForeground: Color {
        switch self {
        case .yours:   return Color(hex: "#1E7F4E")
        case .shared:  return Color.appInk
        case .theirs:  return Color(hex: "#9E4E00")
        }
    }

    var pillBackground: Color {
        switch self {
        case .yours:   return Color(hex: "#1E7F4E").opacity(0.1)
        case .shared:  return Color.appInk.opacity(0.08)
        case .theirs:  return Color(hex: "#F37826").opacity(0.15)
        }
    }
}

// MARK: - ViewModel

@MainActor
final class ComparisonViewModel: ObservableObject {
    enum ViewState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    @Published var state: ViewState = .idle
    @Published var selectedMode: ComparisonMode = .visited
    @Published var emailToCompare: String = ""
    @Published private(set) var comparedUserProfile: UserProfile?

    @Published private(set) var visitedComparison: TravelComparisonResult
    @Published private(set) var wishlistComparison: TravelComparisonResult

    private let countryService = CountryDataService.shared
    private let profileRepository = FirestoreUserRepository()
    private let visitRepository = FirestoreVisitRepository()
    private var allCountries: [Country] = []

    var currentComparison: TravelComparisonResult {
        selectedMode == .visited ? visitedComparison : wishlistComparison
    }

    var yourCountries: [Country] { getCountries(for: Array(currentComparison.yours)) }
    var sharedCountries: [Country] { getCountries(for: Array(currentComparison.shared)) }
    var theirCountries: [Country] { getCountries(for: Array(currentComparison.theirs)) }

    init() {
        self.visitedComparison = TravelComparisonResult(yours: [], shared: [], theirs: [], mode: .visited)
        self.wishlistComparison = TravelComparisonResult(yours: [], shared: [], theirs: [], mode: .wishlist)
        self.allCountries = countryService.loadCountries()
    }

    func searchUser(yourVisits: [String: Visit]) async {
        state = .loading

        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            if case .loading = state {
                state = .error("Request timed out. Please check your internet connection and try again.")
            }
        }
        defer { timeoutTask.cancel() }

        do {
            let profile: UserProfile?
            do {
                profile = try await profileRepository.findProfileByEmail(emailToCompare)
            } catch {
                timeoutTask.cancel()
                state = .error(userFriendlyErrorMessage(from: error))
                return
            }

            guard let profile else {
                timeoutTask.cancel()
                state = .error("User not found or they have disabled comparison in their privacy settings")
                return
            }

            let theirVisitsArray = try await visitRepository.allVisits(forUserId: profile.id)
            let theirVisitsDict = Dictionary(uniqueKeysWithValues: theirVisitsArray.map { ($0.countryId, $0) })

            visitedComparison = TravelComparisonEngine.compare(yourVisits: yourVisits, theirVisits: theirVisitsDict, mode: .visited)
            wishlistComparison = TravelComparisonEngine.compare(yourVisits: yourVisits, theirVisits: theirVisitsDict, mode: .wishlist)

            comparedUserProfile = profile
            state = .loaded
            timeoutTask.cancel()
        } catch {
            timeoutTask.cancel()
            state = .error(userFriendlyErrorMessage(from: error))
        }
    }

    func reloadComparison(yourVisits: [String: Visit]) {
        guard case .loaded = state, let profile = comparedUserProfile else { return }
        Task {
            do {
                let theirVisitsArray = try await visitRepository.allVisits(forUserId: profile.id)
                let theirVisitsDict = Dictionary(uniqueKeysWithValues: theirVisitsArray.map { ($0.countryId, $0) })
                visitedComparison = TravelComparisonEngine.compare(yourVisits: yourVisits, theirVisits: theirVisitsDict, mode: .visited)
                wishlistComparison = TravelComparisonEngine.compare(yourVisits: yourVisits, theirVisits: theirVisitsDict, mode: .wishlist)
            } catch {
                #if DEBUG
                print("⚠️ Failed to reload comparison: \(error)")
                #endif
            }
        }
    }

    func resetToIdle() {
        state = .idle
        emailToCompare = ""
        comparedUserProfile = nil
        visitedComparison = TravelComparisonResult(yours: [], shared: [], theirs: [], mode: .visited)
        wishlistComparison = TravelComparisonResult(yours: [], shared: [], theirs: [], mode: .wishlist)
    }

    private func userFriendlyErrorMessage(from error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:  return "No internet connection. Please check your network and try again."
            case NSURLErrorNetworkConnectionLost:   return "Network connection was lost. Please try again."
            case NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost:
                return "Unable to connect to server. Please check your internet connection."
            case NSURLErrorTimedOut:                return "Connection timed out. Please try again."
            default:                                return "Network error. Please check your connection and try again."
            }
        }
        if nsError.domain == "FIRFirestoreErrorDomain" {
            switch nsError.code {
            case 14: return "Unable to connect to the server. Please check your internet connection and try again."
            case 4:  return "Request timed out. Please check your connection and try again."
            case 7:  return "Permission denied. The user may have changed their privacy settings."
            default: break
            }
        }
        return "Failed to load user: \(error.localizedDescription)"
    }

    private func getCountries(for countryIds: [String]) -> [Country] {
        let countryDict = Dictionary(uniqueKeysWithValues: allCountries.map { ($0.id, $0) })
        return countryIds.compactMap { countryDict[$0] }.sorted { $0.name < $1.name }
    }
}
