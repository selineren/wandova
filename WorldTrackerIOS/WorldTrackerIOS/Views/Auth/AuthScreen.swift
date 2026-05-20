//
//  AuthScreen.swift
//  WorldTrackerIOS
//
//  Created by seren on 9.03.2026.
//

import SwiftUI
import AuthenticationServices

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
                    .foregroundStyle(Color.appInk)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 64)

                // MARK: - Headline
                VStack(alignment: .leading, spacing: 8) {
                    Text(isCreatingAccount ? "Create your account." : "Track every place you've been.")
                        .font(.custom("Inter", size: 32))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.appInk)
                        .tracking(-0.5)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Your world, mapped.")
                        .font(.custom("Inter", size: 15))
                        .foregroundStyle(Color.appInk2)
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
                                .background(Color.appPaper2)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            TextField("Last Name", text: $lastName)
                                .font(.custom("Inter", size: 16))
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 16)
                                .frame(height: 52)
                                .background(Color.appPaper2)
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
                        .background(Color.appPaper2)
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
                                .foregroundStyle(Color.appInk2)
                        }
                        .padding(.trailing, 16)
                    }
                    .frame(height: 52)
                    .background(Color.appPaper2)
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
                    .background(Color.appSurface)
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
                                    .tint(Color.appInk2)
                            }
                            Text("Forgot password?")
                                .font(.custom("Inter", size: 14))
                                .fontWeight(.bold)
                                .foregroundStyle(Color.appInk2)
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
                        .fill(Color.appLine)
                        .frame(height: 1)
                    Text("OR")
                        .font(.custom("Inter", size: 12))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.appInk2)
                        .tracking(2)
                    Rectangle()
                        .fill(Color.appLine)
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
                                ProgressView().tint(Color.appInk)
                            } else {
                                GoogleLogoView()
                            }
                            Text("Continue with Google")
                                .font(.custom("Inter", size: 16))
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.appInk)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.appPaper2)
                        .clipShape(Capsule())
                    }
                    .disabled(isSocialSubmitting || isSubmitting)

                    // Apple
                    Button {
                        Task { await submitSocial { try await authService.signInWithApple() } }
                    } label: {
                        HStack(spacing: 12) {
                            if isSocialSubmitting {
                                ProgressView().tint(Color.appPaper)
                            } else {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.appPaper)
                            }
                            Text("Continue with Apple")
                                .font(.custom("Inter", size: 16))
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.appPaper)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.appInk)
                        .clipShape(Capsule())
                    }
                    .disabled(isSocialSubmitting || isSubmitting)
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
                            Text("Already have an account? ") + Text("Sign in").fontWeight(.semibold).foregroundColor(Color.appInk)
                        } else {
                            Text("Don't have an account? ") + Text("Sign up").fontWeight(.semibold).foregroundColor(Color.appInk)
                        }
                    }
                    .font(.custom("Inter", size: 15))
                    .foregroundStyle(Color.appInk2)
                }
                .disabled(isSubmitting)
                .padding(.top, 32)
                .padding(.bottom, 48)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.appPaper)
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
        } catch {
            withAnimation(.easeInOut(duration: 0.3)) {
                errorMessage = friendlyErrorMessage(from: error)
            }
        }
    }

    private func friendlyErrorMessage(from error: Error) -> String {
        let nsError = error as NSError

        if nsError.domain == "FIRAuthErrorDomain" {
            switch nsError.code {
            case 17008: return "Please enter a valid email address"
            case 17009: return "Incorrect password. Please try again"
            case 17011: return "No account found with this email"
            case 17012: return "This account has been disabled"
            case 17020: return "Network error. Please check your internet connection"
            case 17007: return "An account with this email already exists"
            case 17026: return "Password is too weak. Use at least 6 characters"
            case 17999: return "Invalid email or password"
            case 17010: return "Configuration error. Please contact support"
            case 17014: return "Authentication error. Please try again"
            default:
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

        let message = nsError.localizedDescription.lowercased()
        if message.contains("network") || message.contains("internet") || message.contains("connection") {
            return "Network error. Please check your internet connection"
        }

        return error.localizedDescription
    }
}

// MARK: - Google Logo View

private struct GoogleLogoView: View {
    var body: some View {
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
            Circle()
                .fill(Color.appPaper2)
                .frame(width: 12, height: 12)
            Text("G")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Color(red: 0.259, green: 0.522, blue: 0.957))
        }
        .frame(width: 20, height: 20)
    }

    private struct Segment { let start: Double; let end: Double; let color: Color }
    private var googleSegments: [Segment] { [
        Segment(start: -90, end:   0, color: Color(red: 0.259, green: 0.522, blue: 0.957)),
        Segment(start:   0, end:  90, color: Color(red: 0.204, green: 0.659, blue: 0.325)),
        Segment(start:  90, end: 180, color: Color(red: 0.984, green: 0.737, blue: 0.020)),
        Segment(start: 180, end: 270, color: Color(red: 0.918, green: 0.263, blue: 0.208)),
    ] }
}

// MARK: - App Logo View

struct AppLogoView: View {
    var body: some View {
        if let uiImage = UIImage(named: "AppLogo") {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 22.5, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        } else {
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
