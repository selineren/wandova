//
//  AccountScreen.swift
//  Wandova
//
//  Created by seren on 9.03.2026.
//

import SwiftUI
import FirebaseAuth

struct AccountScreen: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var appState: AppState
    @State private var errorMessage: String?
    @State private var totalCountries: Int = 0
    @State private var countries: [Country] = []
    @State private var showingChangePassword = false
    @State private var showingDeleteAccount = false

    // MARK: - Privacy State

    @State private var userProfile: UserProfile?
    @State private var isLoadingProfile = true
    @State private var allowComparison = false
    @State private var isSavingComparison = false
    @State private var pendingComparisonValue: Bool?

    private let profileRepository = FirestoreUserRepository()

    // MARK: - Computed Properties

    private var visitedCount: Int { appState.visitedCountryIDs.count }
    private var wishlistCount: Int { appState.wantToVisitCountryIDs.count }

    private var visitedPercentage: Double {
        guard totalCountries > 0 else { return 0 }
        return Double(visitedCount) / Double(totalCountries) * 100
    }

    private var visitedThisYear: Int {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        return appState.visits.values
            .filter { $0.isVisited }
            .filter { visit in
                guard let date = visit.visitedDate else { return false }
                return calendar.component(.year, from: date) == currentYear
            }
            .count
    }

    private var achievementSummary: (total: Int, unlocked: Int) {
        guard !countries.isEmpty else { return (0, 0) }
        let achievements = AchievementEngine.calculateAchievements(visits: appState.visits, countries: countries)
        return AchievementEngine.achievementSummary(achievements)
    }

    private func initials(from email: String) -> String {
        let components = email.components(separatedBy: "@")
        guard let namePart = components.first, !namePart.isEmpty else { return "?" }
        let nameComponents = namePart.components(separatedBy: CharacterSet(charactersIn: "._-")).filter { !$0.isEmpty }
        if nameComponents.count >= 2 {
            return nameComponents[0].prefix(1).uppercased() + nameComponents[1].prefix(1).uppercased()
        }
        return String((nameComponents.first ?? "?").prefix(1).uppercased())
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    profileSection
                        .padding(.horizontal, 16)
                        .padding(.top, 28)

                    overviewCard
                        .padding(.horizontal, 16)
                        .padding(.top, 24)

                    highlightsCard
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    privacyCard
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    settingsCard
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    signOutCard
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    Button {
                        showingDeleteAccount = true
                    } label: {
                        Text("DELETE ACCOUNT")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.appInk3)
                            .tracking(1.2)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 32)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 16)
                    }
                }
            }
            .background(Color.appPaper)
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingChangePassword) { ChangePasswordView() }
            .sheet(isPresented: $showingDeleteAccount) { DeleteAccountView() }
            .task {
                let loaded = CountryDataService.shared.loadCountries()
                countries = loaded
                totalCountries = loaded.count
                await loadProfile()
            }
        }
    }

    // MARK: - Profile Section

    private var profileInitials: String {
        if let profile = userProfile, !profile.firstName.isEmpty {
            return profile.initials
        }
        if let name = authService.user?.displayName, !name.trimmingCharacters(in: .whitespaces).isEmpty {
            let parts = name.components(separatedBy: " ").filter { !$0.isEmpty }
            if parts.count >= 2 {
                return (parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
            }
            return String(parts[0].prefix(1)).uppercased()
        }
        return initials(from: authService.userEmail)
    }

    private var profileSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.appSurface)
                    .frame(width: 80, height: 80)
                Text(profileInitials)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Text(authService.displayName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.appInk)

                if authService.displayName != authService.userEmail {
                    Text(authService.userEmail)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.appInk3)
                }
            }

            HStack(spacing: 8) {
                statPill("\(visitedCount) Countries")
                statPill(String(format: "%.1f%%", visitedPercentage))
                statPill("\(wishlistCount) Wishlist")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func statPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.appInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.appCard)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    // MARK: - Travel Overview Card

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Travel overview")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.appInk)

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        iconCircle("scope", bg: Color(hex: "#F9234D").opacity(0.12), fg: Color(hex: "#F9234D"))
                        Text("\(visitedCount) Countries Visited")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.appInk)
                        Spacer()
                        Text(String(format: "%.1f%%", visitedPercentage))
                            .font(.system(size: 13))
                            .foregroundStyle(Color.appInk3)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.appLine)
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: "#F9234D"))
                                .frame(width: max(geo.size.width * (visitedPercentage / 100), visitedCount > 0 ? 4 : 0), height: 4)
                        }
                    }
                    .frame(height: 4)
                }

                Divider()

                HStack(spacing: 12) {
                    iconCircle("star.fill", bg: Color(hex: "#4A90D9").opacity(0.12), fg: Color(hex: "#4A90D9"))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(wishlistCount) on Wishlist")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.appInk)
                        Text("Your next destinations")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.appInk3)
                    }
                    Spacer()
                }
            }
            .padding(16)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        }
    }

    // MARK: - Travel Highlights Card

    private var highlightsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Travel highlights")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.appInk)

            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    iconCircle("calendar", bg: Color.appSuccess.opacity(0.12), fg: Color.appSuccess)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(visitedThisYear) Visited This Year")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.appInk)
                        Text(visitedThisYear > 0 ? "Active traveler" : "Start your \(Calendar.current.component(.year, from: Date())) travels")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.appInk3)
                    }
                    Spacer()
                }

                Divider()

                HStack(spacing: 12) {
                    iconCircle("trophy.fill", bg: Color.appGold.opacity(0.12), fg: Color.appGold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(achievementSummary.unlocked)/\(achievementSummary.total) Achievements")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.appInk)
                        Text(achievementSummary.unlocked > 0 ? "Nomad status" : "Unlock your first achievement")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.appInk3)
                    }
                    Spacer()
                }
            }
            .padding(16)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        }
    }

    // MARK: - Privacy Card

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Privacy")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.appInk)

            HStack(spacing: 12) {
                iconCircle("person.2.fill", bg: Color.appInk.opacity(0.06), fg: Color.appInk2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Travel Comparison")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.appInk)
                    Text(allowComparison ? "Others can compare with you" : "Your travel data is private")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.appInk3)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { pendingComparisonValue ?? allowComparison },
                    set: { newValue in
                        guard !isSavingComparison else { return }
                        pendingComparisonValue = newValue
                        Task { await updateComparisonSetting(newValue) }
                    }
                ))
                .labelsHidden()
                .disabled(isLoadingProfile || isSavingComparison)
            }
            .padding(16)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        }
    }

    // MARK: - Settings Card

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Settings")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.appInk)

            Button { showingChangePassword = true } label: {
                HStack(spacing: 12) {
                    iconCircle("key.fill", bg: Color.appInk.opacity(0.06), fg: Color.appInk2)
                    Text("Change Password")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.appInk)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.appInk3)
                }
                .padding(16)
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Sign Out Card

    private var signOutCard: some View {
        Button {
            do {
                try authService.signOut()
                appState.clearLocalDataAfterSignOut()
            } catch {
                errorMessage = error.localizedDescription
            }
        } label: {
            Text("Sign Out")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.appInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Icon Circle

    private func iconCircle(_ systemImage: String, bg: Color, fg: Color) -> some View {
        ZStack {
            Circle().fill(bg).frame(width: 40, height: 40)
            Image(systemName: systemImage)
                .font(.system(size: 16))
                .foregroundStyle(fg)
        }
    }

    // MARK: - Profile Management

    private func loadProfile() async {
        isLoadingProfile = true
        defer { isLoadingProfile = false }
        do {
            userProfile = try await profileRepository.getCurrentUserProfile()
            allowComparison = userProfile?.allowComparison ?? false
        } catch {
            userProfile = nil
            allowComparison = false
        }
    }

    private func updateComparisonSetting(_ newValue: Bool) async {
        isSavingComparison = true
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            if isSavingComparison {
                pendingComparisonValue = nil
                errorMessage = "Request timed out. Please check your connection and try again."
                isSavingComparison = false
            }
        }
        do {
            if let existingProfile = userProfile {
                try await profileRepository.updateComparisonSetting(allowComparison: newValue)
                timeoutTask.cancel()
                var updated = existingProfile
                updated.allowComparison = newValue
                updated.updatedAt = Date()
                userProfile = updated
                allowComparison = newValue
                pendingComparisonValue = nil
                errorMessage = nil
                isSavingComparison = false
            } else {
                guard let user = authService.user else {
                    timeoutTask.cancel()
                    pendingComparisonValue = nil
                    isSavingComparison = false
                    errorMessage = "User not authenticated"
                    return
                }
                let newProfile = UserProfile(userId: user.uid, email: authService.userEmail, allowComparison: newValue)
                try await profileRepository.createOrUpdateProfile(newProfile)
                timeoutTask.cancel()
                userProfile = newProfile
                allowComparison = newValue
                pendingComparisonValue = nil
                errorMessage = nil
                isSavingComparison = false
            }
        } catch {
            timeoutTask.cancel()
            pendingComparisonValue = nil
            errorMessage = "Failed to update privacy setting: \(error.localizedDescription)"
            isSavingComparison = false
        }
    }
}
