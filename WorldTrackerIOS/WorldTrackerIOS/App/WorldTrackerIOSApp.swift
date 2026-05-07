//
//  WorldTrackerIOSApp.swift
//  WorldTrackerIOS
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
struct WorldTrackerIOSApp: App {
    @StateObject private var authService = AuthService()

    private let container: ModelContainer
    @StateObject private var appState: AppState

    init() {
        Self.registerFonts()
        FirebaseApp.configure()

        do {
            // Create model configuration with migration options
            let schema = Schema([VisitEntity.self])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            
            container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            let context = ModelContext(container)
            
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
        } catch {
            // Print detailed error information
            print("❌ SwiftData container creation failed: \(error)")
            if let swiftDataError = error as? SwiftData.SwiftDataError {
                print("❌ SwiftData error details: \(swiftDataError)")
            }
            fatalError("Failed to create SwiftData container: \(error)")
        }
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
                .task(id: authService.authState) {
                    await handleAuthStateChange()
                }
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(container)
    }
    
    @MainActor
    private func handleAuthStateChange() async {
        switch authService.authState {
        case .signedIn:
            // User signed in - load data and sync
            await appState.handleSignIn()
        case .signedOut:
            // User signed out - clear data
            appState.handleSignOut()
        case .unknown:
            // Initial state - do nothing
            break
        }
    }
}
// MARK: - Auth-Gated Root View

/// Root view that conditionally shows authentication or main app content
/// based on the user's sign-in status.
struct AuthGatedRootView: View {
    @EnvironmentObject private var authService: AuthService
    
    var body: some View {
        Group {
            switch authService.authState {
            case .signedIn:
                // User is authenticated - show main app
                // Use signInCounter to force recreation on each sign-in
                // This ensures tab selection is reset to Map every time
                RootTabView()
                    .id("signed-in-\(authService.signInCounter)")
                    .transition(.opacity)
                    .onAppear {
                        #if DEBUG
                        print("📱 Showing RootTabView (signed in)")
                        #endif
                    }
                
            case .signedOut:
                // User is not authenticated - show auth screen
                AuthScreen()
                    .transition(.opacity)
                    .onAppear {
                        #if DEBUG
                        print("📱 Showing AuthScreen (signed out)")
                        #endif
                    }
                
            case .unknown:
                // Initial state - show loading screen while Firebase checks session
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
    }
}

// MARK: - Loading View
/// Displayed during initial app launch while Firebase checks authentication status
private struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 32) {
                AppLogoView()

                Text("WORLDTRACKER")
                    .font(.custom("Inter", size: 16))
                    .fontWeight(.black)
                    .tracking(4)
                    .foregroundStyle(.black)

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
            .stroke(Color.black, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: 24, height: 24)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}


