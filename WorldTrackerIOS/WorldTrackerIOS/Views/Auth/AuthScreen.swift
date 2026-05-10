//
//  AuthScreen.swift
//  WorldTrackerIOS
//
//  Created by seren on 9.03.2026.
//

import SwiftUI

struct AuthScreen: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var appState: AppState

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isCreatingAccount = false
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var isSocialSubmitting = false
    @State private var showPassword = false
    @State private var showResetConfirmation = false
    @State private var isSendingReset = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // MARK: - Wordmark
                Text("WORLDTRACKER")
                    .font(.custom("Inter", size: 12))
                    .fontWeight(.bold)
                    .tracking(3.5)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 64)

                // MARK: - Headline
                VStack(alignment: .leading, spacing: 8) {
                    Text(isCreatingAccount ? "Create your account." : "Track every place you've been.")
                        .font(.custom("Inter", size: 32))
                        .fontWeight(.bold)
                        .foregroundStyle(.black)
                        .tracking(-0.5)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Your world, mapped.")
                        .font(.custom("Inter", size: 15))
                        .foregroundStyle(Color(hex: "#6B6B6B"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 48)
                .padding(.bottom, 32)

                // MARK: - Input Fields
                VStack(spacing: 12) {
                    // Name fields (sign up only)
                    if isCreatingAccount {
                        HStack(spacing: 12) {
                            TextField("First Name", text: $firstName)
                                .font(.custom("Inter", size: 16))
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 16)
                                .frame(height: 52)
                                .background(Color(hex: "#F3F3F3"))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            TextField("Last Name", text: $lastName)
                                .font(.custom("Inter", size: 16))
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 16)
                                .frame(height: 52)
                                .background(Color(hex: "#F3F3F3"))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    // Email
                    TextField("Email", text: $email)
                        .font(.custom("Inter", size: 16))
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color(hex: "#F3F3F3"))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Password
                    ZStack(alignment: .trailing) {
                        Group {
                            if showPassword {
                                TextField("Password", text: $password)
                            } else {
                                SecureField("Password", text: $password)
                            }
                        }
                        .font(.custom("Inter", size: 16))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 16)
                        .padding(.trailing, 44)
                        .frame(height: 52)

                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye" : "eye.slash")
                                .font(.system(size: 16))
                                .foregroundStyle(Color(hex: "#6B6B6B"))
                        }
                        .padding(.trailing, 16)
                    }
                    .frame(height: 52)
                    .background(Color(hex: "#F3F3F3"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 24)

                // MARK: - Error Message
                if let errorMessage {
                    Text(errorMessage)
                        .font(.custom("Inter", size: 13))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .transition(.opacity)
                }

                // MARK: - Continue Button
                Button {
                    Task { await submit() }
                } label: {
                    HStack(spacing: 8) {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        }
                        Text(isCreatingAccount ? "Create Account" : "Continue")
                            .font(.custom("Inter", size: 16))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.black)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(!isFormReady)
                .opacity(isFormReady ? 1.0 : 0.5)
                .padding(.horizontal, 24)
                .padding(.top, 12)

                // MARK: - Forgot Password
                if !isCreatingAccount {
                    Button {
                        Task { await sendPasswordReset() }
                    } label: {
                        HStack(spacing: 6) {
                            if isSendingReset {
                                ProgressView()
                                    .scaleEffect(0.75)
                                    .tint(Color(hex: "#6B6B6B"))
                            }
                            Text("Forgot password?")
                                .font(.custom("Inter", size: 14))
                                .fontWeight(.bold)
                                .foregroundStyle(Color(hex: "#6B6B6B"))
                        }
                    }
                    .disabled(isSendingReset || isSubmitting)
                    .padding(.top, 20)
                    .alert("Check your inbox", isPresented: $showResetConfirmation) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text("We sent a password reset link to \(email).")
                    }
                }

                // MARK: - OR Divider
                HStack(spacing: 16) {
                    Rectangle()
                        .fill(Color(hex: "#EEEEEE"))
                        .frame(height: 1)
                    Text("OR")
                        .font(.custom("Inter", size: 12))
                        .fontWeight(.bold)
                        .foregroundStyle(Color(hex: "#6B6B6B"))
                        .tracking(2)
                    Rectangle()
                        .fill(Color(hex: "#EEEEEE"))
                        .frame(height: 1)
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)

                // MARK: - Social Buttons
                VStack(spacing: 12) {
                    // Google
                    Button {
                        Task { await submitSocial { try await authService.signInWithGoogle() } }
                    } label: {
                        HStack(spacing: 12) {
                            if isSocialSubmitting {
                                ProgressView().tint(.black)
                            } else {
                                GoogleLogoView()
                            }
                            Text("Continue with Google")
                                .font(.custom("Inter", size: 16))
                                .fontWeight(.semibold)
                                .foregroundStyle(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(hex: "#F5F5F5"))
                        .clipShape(Capsule())
                    }
                    .disabled(isSocialSubmitting || isSubmitting)

                    // Apple (requires paid Apple Developer account — hidden until enrolled)
                    // Button {
                    //     Task { await submitSocial { try await authService.signInWithApple() } }
                    // } label: { ... }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // MARK: - Sign Up / Sign In Toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCreatingAccount.toggle()
                        errorMessage = nil
                        firstName = ""
                        lastName = ""
                    }
                } label: {
                    Group {
                        if isCreatingAccount {
                            Text("Already have an account? ") + Text("Sign in").fontWeight(.semibold).foregroundColor(.black)
                        } else {
                            Text("Don't have an account? ") + Text("Sign up").fontWeight(.semibold).foregroundColor(.black)
                        }
                    }
                    .font(.custom("Inter", size: 15))
                    .foregroundStyle(Color(hex: "#6B6B6B"))
                }
                .disabled(isSubmitting)
                .padding(.top, 32)
                .padding(.bottom, 48)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.white)
    }

    private var isFormReady: Bool {
        let base = !email.isEmpty && !password.isEmpty && !isSubmitting
        if isCreatingAccount {
            return base && !firstName.isEmpty && !lastName.isEmpty
        }
        return base
    }

    private func submitSocial(_ action: () async throws -> Void) async {
        errorMessage = nil
        isSocialSubmitting = true
        defer { isSocialSubmitting = false }
        do {
            try await action()
        } catch {
            withAnimation(.easeInOut(duration: 0.3)) {
                errorMessage = friendlyErrorMessage(from: error)
            }
        }
    }

    private func sendPasswordReset() async {
        guard !email.isEmpty else {
            withAnimation(.easeInOut(duration: 0.3)) {
                errorMessage = "Enter your email address above to reset your password"
            }
            return
        }
        isSendingReset = true
        defer { isSendingReset = false }
        do {
            try await authService.sendPasswordReset(email: email)
            showResetConfirmation = true
        } catch {
            withAnimation(.easeInOut(duration: 0.3)) {
                errorMessage = "Couldn't send reset email. Check the address and try again."
            }
        }
    }

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        
        defer {
            isSubmitting = false
        }

        do {
            if isCreatingAccount {
                try await authService.signUp(email: email, password: password, firstName: firstName, lastName: lastName)
            } else {
                try await authService.signIn(email: email, password: password)
            }
            
            // No need to manually call sync here - WorldTrackerIOSApp.handleAuthStateChange()
            // will automatically trigger appState.handleSignIn() which includes sync
        } catch {
            withAnimation(.easeInOut(duration: 0.3)) {
                errorMessage = friendlyErrorMessage(from: error)
            }
        }
    }
    
    /// Convert Firebase authentication errors to user-friendly messages
    /// - Parameter error: The error from Firebase Auth
    /// - Returns: A clear, actionable error message for the user
    private func friendlyErrorMessage(from error: Error) -> String {
        let nsError = error as NSError
        
        // Firebase Auth errors use domain "FIRAuthErrorDomain"
        if nsError.domain == "FIRAuthErrorDomain" {
            switch nsError.code {
            // Sign In Errors
            case 17008: // ERROR_INVALID_EMAIL
                return "Please enter a valid email address"
            case 17009: // ERROR_WRONG_PASSWORD
                return "Incorrect password. Please try again"
            case 17011: // ERROR_USER_NOT_FOUND
                return "No account found with this email"
            case 17012: // ERROR_USER_DISABLED
                return "This account has been disabled"
            case 17020: // ERROR_NETWORK_REQUEST_FAILED
                return "Network error. Please check your internet connection"
            
            // Sign Up Errors
            case 17007: // ERROR_EMAIL_ALREADY_IN_USE
                return "An account with this email already exists"
            case 17026: // ERROR_WEAK_PASSWORD
                return "Password is too weak. Use at least 6 characters"
            
            // General Errors
            case 17999: // ERROR_INVALID_CREDENTIAL
                return "Invalid email or password"
            case 17010: // ERROR_INVALID_API_KEY
                return "Configuration error. Please contact support"
            case 17014: // ERROR_USER_MISMATCH
                return "Authentication error. Please try again"
                
            default:
                // Check error message for common patterns
                let message = nsError.localizedDescription.lowercased()
                
                if message.contains("malformed") || message.contains("credential") {
                    return "Invalid email or password format"
                } else if message.contains("expired") {
                    return "Session expired. Please try again"
                } else if message.contains("network") || message.contains("connection") {
                    return "Network error. Please check your internet connection"
                } else if message.contains("too many requests") {
                    return "Too many attempts. Please wait a moment and try again"
                } else {
                    return "Authentication failed. Please check your credentials"
                }
            }
        }
        
        // For non-Firebase errors
        let message = nsError.localizedDescription.lowercased()
        if message.contains("network") || message.contains("internet") || message.contains("connection") {
            return "Network error. Please check your internet connection"
        }
        
        // Fallback to original error message
        return error.localizedDescription
    }
}

// MARK: - Google Logo View

private struct GoogleLogoView: View {
    var body: some View {
        // Standard 4-color Google "G" rendered as colored arc segments
        ZStack {
            ForEach(Array(googleSegments.enumerated()), id: \.offset) { _, seg in
                Path { path in
                    path.move(to: CGPoint(x: 10, y: 10))
                    path.addArc(center: CGPoint(x: 10, y: 10),
                                radius: 10,
                                startAngle: .degrees(seg.start),
                                endAngle: .degrees(seg.end),
                                clockwise: false)
                    path.closeSubpath()
                }
                .fill(seg.color)
            }
            // White inner circle to create ring effect
            Circle()
                .fill(Color(hex: "#F5F5F5"))
                .frame(width: 12, height: 12)
            Text("G")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Color(red: 0.259, green: 0.522, blue: 0.957))
        }
        .frame(width: 20, height: 20)
    }

    private struct Segment { let start: Double; let end: Double; let color: Color }
    private var googleSegments: [Segment] { [
        Segment(start: -90, end:   0, color: Color(red: 0.259, green: 0.522, blue: 0.957)), // Blue
        Segment(start:   0, end:  90, color: Color(red: 0.204, green: 0.659, blue: 0.325)), // Green
        Segment(start:  90, end: 180, color: Color(red: 0.984, green: 0.737, blue: 0.020)), // Yellow
        Segment(start: 180, end: 270, color: Color(red: 0.918, green: 0.263, blue: 0.208)), // Red
    ] }
}

// MARK: - App Logo View

/// Displays the app logo with a fallback to a globe icon
struct AppLogoView: View {
    var body: some View {
        // Try to load the logo from Assets
        // If "AppLogo" asset doesn't exist, show gradient globe fallback
        if let uiImage = UIImage(named: "AppLogo") {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 22.5, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        } else {
            // Fallback: gradient globe icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.white)
            }
        }
    }
}

