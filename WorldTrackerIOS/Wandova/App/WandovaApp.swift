//
//  WandovaApp.swift
//  Wandova
//
//  Created by seren on 24.02.2026.
//

import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import CoreText

@main
struct WandovaApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var achievementNotifier = AchievementNotifier()

    private let container: ModelContainer
    @StateObject private var appState: AppState
    private let storageError: Error?

    init() {
        Self.registerFonts()
        FirebaseApp.configure()

        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }

        let schema = Schema([VisitEntity.self])
        var resolvedContainer: ModelContainer
        var capturedError: Error? = nil

        do {
            resolvedContainer = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    allowsSave: true,
                    cloudKitDatabase: .none
                )]
            )
        } catch {
            capturedError = error
            #if DEBUG
            print("❌ SwiftData persistent store failed, falling back to in-memory: \(error)")
            #endif
            // Fall back to in-memory so the app can still launch
            do {
                resolvedContainer = try ModelContainer(
                    for: schema,
                    configurations: [ModelConfiguration(
                        schema: schema,
                        isStoredInMemoryOnly: true,
                        allowsSave: true,
                        cloudKitDatabase: .none
                    )]
                )
            } catch {
                // In-memory store also failed — truly unrecoverable
                fatalError("SwiftData failed for both persistent and in-memory stores: \(error)")
            }
        }

        container = resolvedContainer
        storageError = capturedError

        let context = ModelContext(resolvedContainer)
        let localRepo = SwiftDataVisitRepository(context: context)
        let cloudRepo = FirestoreVisitRepository()
        let syncService = SyncService(
            localRepository: localRepo,
            cloudRepository: cloudRepo
        )

        _appState = StateObject(
            wrappedValue: AppState(
                repository: localRepo,
                syncService: syncService
            )
        )
    }

    private static func registerFonts() {
        let fontFiles = [
            "Fraunces-Italic-VariableFont_SOFT,WONK,opsz,wght",
            "Inter-VariableFont_opsz,wght"
        ]
        for name in fontFiles {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                print("⚠️ Font file not found in bundle: \(name).ttf")
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            AuthGatedRootView()
                .environmentObject(appState)
                .environmentObject(authService)
                .environmentObject(achievementNotifier)
                .task(id: authService.authState) {
                    await handleAuthStateChange()
                }
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .alert("Storage Unavailable", isPresented: .constant(storageError != nil)) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Your data could not be loaded from storage. Changes made this session will not be saved. Please restart the app — if this keeps happening, try reinstalling.")
                }
        }
        .modelContainer(container)
    }

    @MainActor
    private func handleAuthStateChange() async {
        switch authService.authState {
        case .signedIn:
            if let userId = authService.user?.uid {
                achievementNotifier.configure(for: userId)
            }
            await appState.handleSignIn()
        case .signedOut:
            appState.handleSignOut()
            achievementNotifier.reset()
        case .unknown:
            break
        }
    }
}
// MARK: - Auth-Gated Root View

struct AuthGatedRootView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var achievementNotifier: AchievementNotifier

    var body: some View {
        ZStack {
            Group {
                switch authService.authState {
                case .signedIn:
                    RootTabView()
                        .id("signed-in-\(authService.signInCounter)")
                        .transition(.opacity)
                        .onAppear {
                            #if DEBUG
                            print("📱 Showing RootTabView (signed in)")
                            #endif
                        }

                case .signedOut:
                    AuthScreen()
                        .transition(.opacity)
                        .onAppear {
                            #if DEBUG
                            print("📱 Showing AuthScreen (signed out)")
                            #endif
                        }

                case .unknown:
                    LoadingView()
                        .transition(.opacity)
                        .onAppear {
                            #if DEBUG
                            print("📱 Showing LoadingView (unknown state)")
                            #endif
                        }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authService.authState)

            if let achievement = achievementNotifier.pendingAchievements.first {
                AchievementCelebrationOverlay(achievement: achievement) {
                    achievementNotifier.dismissCurrent()
                }
                .id(achievement.id)
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Loading View
private struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.appPaper
                .ignoresSafeArea()

            VStack(spacing: 32) {
                AppLogoView()

                Text("WANDOVA")
                    .font(.custom("Inter", size: 16))
                    .fontWeight(.black)
                    .tracking(4)
                    .foregroundStyle(Color.appInk)

                LoadingSpinner()
                    .padding(.top, 48)
            }

            VStack {
                Spacer()
                Text("YOUR WORLD, MAPPED.")
                    .font(.custom("Inter", size: 10))
                    .fontWeight(.medium)
                    .tracking(3)
                    .foregroundStyle(Color(.secondaryLabel))
                    .opacity(0.4)
                    .padding(.bottom, 48)
            }
        }
    }
}

private struct LoadingSpinner: View {
    @State private var rotation: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0.1, to: 0.9)
            .stroke(Color.appInk, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: 24, height: 24)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}
