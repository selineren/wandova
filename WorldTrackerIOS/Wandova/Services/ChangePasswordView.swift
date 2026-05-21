//
//  ChangePasswordView.swift
//  Wandova
//
//  Created by seren on 9.03.2026.
//

import SwiftUI

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var showCurrent = false
    @State private var showNew = false
    @State private var showConfirm = false

    // MARK: - Validation

    private var isFormValid: Bool {
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        !confirmPassword.isEmpty &&
        newPassword == confirmPassword &&
        newPassword.count >= 6 &&
        currentPassword != newPassword &&
        !isSubmitting
    }

    private var passwordsMatch: Bool {
        !newPassword.isEmpty && !confirmPassword.isEmpty && newPassword == confirmPassword
    }

    private var validationHint: String? {
        guard !newPassword.isEmpty || !confirmPassword.isEmpty else { return nil }
        if newPassword.count > 0 && newPassword.count < 6 {
            return "Password must be at least 6 characters"
        }
        if !confirmPassword.isEmpty && newPassword != confirmPassword {
            return "Passwords do not match"
        }
        if !newPassword.isEmpty && !currentPassword.isEmpty && newPassword == currentPassword {
            return "New password must be different from current password"
        }
        return nil
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Change Password")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.appInk)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.appInk3)
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: Verify identity
                    VStack(alignment: .leading, spacing: 10) {
                        Text("VERIFY IDENTITY")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.appInk3)
                            .tracking(0.8)
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            passwordField(
                                placeholder: "Current Password",
                                text: $currentPassword,
                                show: $showCurrent
                            )
                        }
                        .background(Color.appCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)

                        Text("Enter your current password to continue")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.appInk3)
                            .padding(.horizontal, 4)
                    }

                    // MARK: New password
                    VStack(alignment: .leading, spacing: 10) {
                        Text("NEW PASSWORD")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.appInk3)
                            .tracking(0.8)
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            passwordField(
                                placeholder: "New Password",
                                text: $newPassword,
                                show: $showNew
                            )

                            Divider().padding(.horizontal, 16)

                            passwordField(
                                placeholder: "Confirm New Password",
                                text: $confirmPassword,
                                show: $showConfirm
                            )

                            if !newPassword.isEmpty || !confirmPassword.isEmpty {
                                Divider().padding(.horizontal, 16)

                                HStack(spacing: 8) {
                                    Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.system(size: 15))
                                        .foregroundStyle(passwordsMatch ? Color.appSuccess : Color.appInk3)
                                    Text(passwordsMatch ? "Passwords match" : (validationHint ?? "Passwords do not match"))
                                        .font(.system(size: 13))
                                        .foregroundStyle(passwordsMatch ? Color.appSuccess : Color.appInk3)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                        }
                        .background(Color.appCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)

                        Text("Password must be at least 6 characters")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.appInk3)
                            .padding(.horizontal, 4)
                    }

                    // MARK: Error
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 4)
                    }

                    // MARK: Actions
                    VStack(spacing: 14) {
                        Button {
                            Task { await changePassword() }
                        } label: {
                            HStack(spacing: 8) {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text(isSubmitting ? "Changing Password..." : "Change Password")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(isFormValid ? Color.appSurface : Color.appLine)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(!isFormValid)

                        Button { dismiss() } label: {
                            Text("Cancel")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.appInk3)
                        }
                        .buttonStyle(.plain)
                        .disabled(isSubmitting)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .background(Color.appPaper)
    }

    // MARK: - Password Field

    private func passwordField(placeholder: String, text: Binding<String>, show: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Group {
                if show.wrappedValue {
                    TextField(placeholder, text: text)
                } else {
                    SecureField(placeholder, text: text)
                }
            }
            .font(.system(size: 15))
            .foregroundStyle(Color.appInk)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            Button {
                show.wrappedValue.toggle()
            } label: {
                Image(systemName: show.wrappedValue ? "eye.fill" : "eye.slash.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(show.wrappedValue ? Color.appInk2 : Color.appInk3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    // MARK: - Password Change Logic

    private func changePassword() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await authService.reauthenticate(currentPassword: currentPassword)
            try await authService.updatePassword(newPassword: newPassword)
            try? await Task.sleep(for: .seconds(1.5))
            dismiss()
        } catch let error as NSError {
            errorMessage = friendlyErrorMessage(from: error)
        }
    }

    // MARK: - Error Handling

    private func friendlyErrorMessage(from error: NSError) -> String {
        if error.domain == "FIRAuthErrorDomain" {
            switch error.code {
            case 17009, 17004, 17999:
                return "Current password is incorrect"
            case 17026:
                return "New password is too weak. Please choose a stronger password"
            case 17020:
                return "Network error. Please check your connection and try again"
            case 17011:
                return "User session expired. Please sign in again"
            case 17014:
                return "Authentication error. Please try again"
            case 17995:
                return "Session expired. Please sign out and sign back in"
            default:
                let message = error.localizedDescription.lowercased()
                if message.contains("credential") && (message.contains("malformed") || message.contains("expired")) {
                    return "Current password is incorrect"
                } else if message.contains("password") && message.contains("weak") {
                    return "New password is too weak. Please choose a stronger password"
                } else if message.contains("network") || message.contains("connection") {
                    return "Network error. Please check your connection and try again"
                } else {
                    return "Unable to change password. Please try again or contact support"
                }
            }
        } else {
            return error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview {
    ChangePasswordView()
        .environmentObject(AuthService())
}
