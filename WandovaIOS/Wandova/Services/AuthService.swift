//
//  AuthService.swift
//  Wandova
//
//  Created by seren on 9.03.2026.
//

import Foundation
import Combine
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit
import UIKit

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var user: User?
    @Published private(set) var authState: AuthState = .unknown
    
    /// Increments every time a user signs in
    /// Used to force UI refresh and reset navigation state
    @Published private(set) var signInCounter: Int = 0

    var userEmail: String {
        user?.email ?? "Unknown user"
    }

    var displayName: String {
        if let name = user?.displayName, !name.trimmingCharacters(in: .whitespaces).isEmpty {
            return name
        }
        return userEmail
    }
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    /// Set once per install, right after the fresh-install sign-out below. Unlike the
    /// Keychain (where Firebase persists the auth session), UserDefaults is wiped when
    /// the app is deleted — so its absence is how we detect a fresh install.
    private static let hasLaunchedBeforeKey = "com.wandova.hasLaunchedBefore"

    init() {
        // Always start with unknown state for consistent UX
        // This ensures LoadingView shows briefly on every cold launch
        authState = .unknown

        #if DEBUG
        print("🔐 AuthService init: state = .unknown")
        #endif

        // Firebase's auth session lives in the Keychain, which iOS does NOT clear on
        // uninstall. Without this, a fresh install silently inherits the previous
        // install's signed-in session, mounting the map (and kicking off Firestore
        // sync, network prompts included) before the user has ever authenticated on
        // this install. Force a sign-out exactly once per install to prevent that.
        if !UserDefaults.standard.bool(forKey: Self.hasLaunchedBeforeKey) {
            try? Auth.auth().signOut()
            UserDefaults.standard.set(true, forKey: Self.hasLaunchedBeforeKey)
            #if DEBUG
            print("🔐 Fresh install detected - cleared any leftover Keychain session")
            #endif
        }

        // Get current user synchronously
        user = Auth.auth().currentUser
        
        // If user exists on init, increment counter (app launch while already signed in)
        if user != nil {
            signInCounter = 1
            #if DEBUG
            print("🔐 User already signed in on init - counter set to \(signInCounter)")
            #endif
        }
        
        // Schedule immediate state resolution
        Task { @MainActor in
            // Small delay to ensure LoadingView is visible
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms minimum
            
            if let currentUser = self.user {
                // User exists - transition to signed in
                self.authState = .signedIn
                #if DEBUG
                print("🔐 Auth state resolved: .signedIn (existing user: \(currentUser.uid))")
                #endif
            } else {
                // No user yet - wait for Firebase callback or timeout
                #if DEBUG
                print("🔐 Auth state pending: waiting for Firebase callback...")
                #endif
                
                // Timeout fallback if Firebase doesn't respond
                try? await Task.sleep(nanoseconds: 400_000_000) // 400ms more (total 500ms)
                if self.authState == .unknown && self.user == nil {
                    self.authState = .signedOut
                    #if DEBUG
                    print("🔐 Auth state resolved: .signedOut (timeout)")
                    #endif
                }
            }
        }

        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            
            let wasSignedOut = self.user == nil
            self.user = user
            
            // Always update state based on user presence
            let newState: AuthState = user != nil ? .signedIn : .signedOut
            
            // Increment counter when transitioning from signed out to signed in
            if wasSignedOut && newState == .signedIn {
                self.signInCounter += 1
                #if DEBUG
                print("🔐 Sign-in detected - counter incremented to \(self.signInCounter)")
                #endif
            }
            
            // Only update if state actually changed
            if self.authState != newState {
                self.authState = newState
                #if DEBUG
                print("🔐 Auth state changed: \(newState) (listener callback, uid: \(user?.uid ?? "none"))")
                #endif
            }
        }
    }

    deinit {
        if let authStateHandle {
            Auth.auth().removeStateDidChangeListener(authStateHandle)
        }
    }

    var isSignedIn: Bool {
        user != nil
    }

    /// The provider the current user originally signed in with.
    /// Determines which re-authentication flow is required before sensitive
    /// operations (e.g. account deletion), since password re-auth doesn't
    /// apply to Google/Apple accounts that never set a password.
    enum SignInProvider {
        case password
        case google
        case apple
        case unknown
    }

    var signInProvider: SignInProvider {
        guard let providerID = user?.providerData.first?.providerID else { return .unknown }
        switch providerID {
        case EmailAuthProviderID: return .password
        case GoogleAuthProviderID: return .google
        case "apple.com": return .apple
        default: return .unknown
        }
    }

    func signUp(email: String, password: String, firstName: String, lastName: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)

        // Set Firebase Auth display name so it's available immediately without a Firestore fetch
        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        try? await changeRequest.commitChanges()

        // Persist name + email in Firestore profile
        let repo = FirestoreUserRepository()
        let profile = UserProfile(
            userId: result.user.uid,
            email: email.lowercased().trimmingCharacters(in: .whitespaces),
            firstName: firstName,
            lastName: lastName
        )
        try? await repo.createOrUpdateProfile(profile)
    }

    func signIn(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    // MARK: - Google Sign-In

    func signInWithGoogle() async throws {
        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            throw SocialAuthError.presentationError
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
        guard let idToken = result.user.idToken?.tokenString else {
            throw SocialAuthError.missingToken
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        let authResult = try await Auth.auth().signIn(with: credential)

        if authResult.additionalUserInfo?.isNewUser == true {
            let profile = UserProfile(
                userId: authResult.user.uid,
                email: authResult.user.email ?? "",
                firstName: result.user.profile?.givenName ?? "",
                lastName: result.user.profile?.familyName ?? ""
            )
            try? await FirestoreUserRepository().createOrUpdateProfile(profile)
        }
    }

    // MARK: - Apple Sign-In

    private let appleCoordinator = AppleSignInCoordinator()
    private var currentNonce: String?

    func signInWithApple() async throws {
        let nonce = randomNonceString()
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let authorization = try await appleCoordinator.signIn(with: request)

        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = appleCredential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              let nonce = currentNonce else {
            throw SocialAuthError.missingToken
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: appleCredential.fullName
        )
        let authResult = try await Auth.auth().signIn(with: credential)

        // Apple only provides name and email on the very first sign-in
        if authResult.additionalUserInfo?.isNewUser == true {
            let profile = UserProfile(
                userId: authResult.user.uid,
                email: appleCredential.email ?? authResult.user.email ?? "",
                firstName: appleCredential.fullName?.givenName ?? "",
                lastName: appleCredential.fullName?.familyName ?? ""
            )
            try? await FirestoreUserRepository().createOrUpdateProfile(profile)
        }
    }

    // MARK: - Nonce helpers (required by Apple Sign-In)

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    /// Reauthenticate the current user with their password
    /// Required by Firebase before sensitive operations like password changes
    func reauthenticate(currentPassword: String) async throws {
        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            throw NSError(
                domain: "AuthService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No user is currently signed in"]
            )
        }
        
        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
        try await user.reauthenticate(with: credential)
    }

    /// Reauthenticate the current user via Google Sign-In
    /// Required by Firebase before sensitive operations (e.g. account deletion)
    /// for accounts that originally signed in with Google
    func reauthenticateWithGoogle() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(
                domain: "AuthService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No user is currently signed in"]
            )
        }

        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            throw SocialAuthError.presentationError
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
        guard let idToken = result.user.idToken?.tokenString else {
            throw SocialAuthError.missingToken
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        try await user.reauthenticate(with: credential)
    }

    /// Reauthenticate the current user via Sign in with Apple
    /// Required by Firebase before sensitive operations (e.g. account deletion)
    /// for accounts that originally signed in with Apple
    func reauthenticateWithApple() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(
                domain: "AuthService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No user is currently signed in"]
            )
        }

        let nonce = randomNonceString()
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let authorization = try await appleCoordinator.signIn(with: request)

        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = appleCredential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw SocialAuthError.missingToken
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: appleCredential.fullName
        )
        try await user.reauthenticate(with: credential)
    }

    /// Update the current user's password to a new value
    /// Note: User must be recently authenticated (call reauthenticate first)
    func updatePassword(newPassword: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(
                domain: "AuthService",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "User session expired"]
            )
        }
        
        try await user.updatePassword(to: newPassword)
    }
    
    /// Permanently delete the current user's account and all associated data
    /// This is a destructive operation that cannot be undone
    ///
    /// The deletion process follows these steps:
    /// 1. Reauthenticate the user via whichever provider they originally signed in
    ///    with (required by Firebase). Password accounts reauth with `currentPassword`;
    ///    Google/Apple accounts reauth via their respective sign-in flow.
    /// 2. Delete all visit documents from Firestore
    /// 3. Delete the Firebase Authentication account
    ///
    /// - Parameter currentPassword: The user's current password, required only when
    ///   `signInProvider` is `.password`. Ignored for Google/Apple accounts.
    /// - Throws: Authentication errors, network errors, or Firestore errors
    /// - Note: If any step fails, the process stops and throws an error. The auth state listener
    ///         will automatically trigger sign-out cleanup if the account is successfully deleted.
    func deleteAccount(currentPassword: String? = nil) async throws {
        // Step 1: Reauthenticate user (required by Firebase for account deletion),
        // using whichever provider the account was created with.
        switch signInProvider {
        case .password:
            guard let currentPassword, !currentPassword.isEmpty else {
                throw NSError(
                    domain: "AuthService",
                    code: -4,
                    userInfo: [NSLocalizedDescriptionKey: "Password is required to delete this account"]
                )
            }
            try await reauthenticate(currentPassword: currentPassword)
        case .google:
            try await reauthenticateWithGoogle()
        case .apple:
            try await reauthenticateWithApple()
        case .unknown:
            throw NSError(
                domain: "AuthService",
                code: -5,
                userInfo: [NSLocalizedDescriptionKey: "Unable to verify your sign-in method. Please sign out and sign back in, then try again."]
            )
        }

        // Step 2: Delete all Firestore visit documents for this user
        // Do this before deleting the auth account so we still have valid credentials
        let firestoreRepository = FirestoreVisitRepository()
        try await firestoreRepository.deleteAllUserVisits()
        
        // Step 3: Delete the Firebase Auth account
        // This is the final, irreversible step
        guard let user = Auth.auth().currentUser else {
            throw NSError(
                domain: "AuthService",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "User session expired during account deletion"]
            )
        }
        
        try await user.delete()
        
        // Note: No need to call signOut() or clear local data here
        // The auth state listener will detect the account deletion and trigger
        // the sign-out flow automatically via authState change to .signedOut
    }
}
enum AuthState: Equatable, CustomStringConvertible {
    case unknown
    case signedIn
    case signedOut

    var description: String {
        switch self {
        case .unknown: return ".unknown"
        case .signedIn: return ".signedIn"
        case .signedOut: return ".signedOut"
        }
    }
}

enum SocialAuthError: LocalizedError {
    case missingToken
    case presentationError

    var errorDescription: String? {
        switch self {
        case .missingToken:       return "Sign-in failed. Please try again."
        case .presentationError:  return "Could not present the sign-in screen."
        }
    }
}

// MARK: - Apple Sign-In Coordinator

private final class AppleSignInCoordinator: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    private var continuation: CheckedContinuation<ASAuthorization, Error>?

    func signIn(with request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation?.resume(returning: authorization)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

