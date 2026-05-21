//
//  DeleteAccountView.swift
//  Wandova
//
//  Created by seren on 9.03.2026.
//

import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService

    @State private var password = ""
    @State private var confirmationText = ""
    @State private var errorMessage: String?
    @State private var isDeleting = false
    @State private var showPassword = false

    // MARK: - Validation

    private var isFormValid: Bool {
        !password.isEmpty &&
        confirmationText == "DELETE" &&
        !isDeleting
    }

    private var confirmationValid: Bool { confirmationText == "DELETE" }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Delete Account")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.appInk)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.appInk3)
                }
                .buttonStyle(.plain)
                .disabled(isDeleting)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: Warning
                    VStack(alignment: .leading, spacing: 10) {
                        Text("THIS ACTION IS PERMANENT")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.appInk3)
                            .tracking(0.8)
                            .padding(.horizontal, 4)

                        VStack(alignment: .leading, spacing: 0) {
                            Text("Deleting your account will:")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.appInk)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                .padding(.bottom, 12)

                            Divider().padding(.horizontal, 16)

                            warningRow(
                                icon: "xmark.circle.fill",
                                iconColor: Color(hex: "#F9234D"),
                                iconBg: Color(hex: "#F9234D").opacity(0.12),
                                text: "Remove all your travel data"
                            )

                            Divider().padding(.horizontal, 16)

                            warningRow(
                                icon: "trash.fill",
                                iconColor: Color(hex: "#F9234D"),
                                iconBg: Color(hex: "#F9234D").opacity(0.12),
                                text: "Delete your account permanently"
                            )

                            Divider().padding(.horizontal, 16)

                            warningRow(
                                icon: "exclamationmark.triangle.fill",
                                iconColor: Color.appGold,
                                iconBg: Color.appGold.opacity(0.12),
                                text: "Cannot be recovered or undone"
                            )

                            Spacer(minLength: 4)
                        }
                        .background(Color.appCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
                    }

                    // MARK: Verify identity
                    VStack(alignment: .leading, spacing: 10) {
                        Text("VERIFY IDENTITY")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.appInk3)
                            .tracking(0.8)
                            .padding(.horizontal, 4)

                        HStack(spacing: 12) {
                            Group {
                                if showPassword {
                                    TextField("Password", text: $password)
                                } else {
                                    SecureField("Password", text: $password)
                                }
                            }
                            .font(.system(size: 15))
                            .foregroundStyle(Color.appInk)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.fill" : "eye.slash.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(showPassword ? Color.appInk2 : Color.appInk3)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(Color.appCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)

                        Text("Enter your password to continue")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.appInk3)
                            .padding(.horizontal, 4)
                    }

                    // MARK: Confirm deletion
                    VStack(alignment: .leading, spacing: 10) {
                        Text("CONFIRM DELETION")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.appInk3)
                            .tracking(0.8)
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            TextField("Type DELETE to confirm", text: $confirmationText)
                                .font(.system(size: 15))
                                .foregroundStyle(Color.appInk)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.characters)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)

                            Divider().padding(.horizontal, 16)

                            HStack(spacing: 8) {
                                Image(systemName: confirmationValid ? "checkmark.circle.fill" : "info.circle.fill")
                                    .font(.system(size: 15))
                                    .foregroundStyle(confirmationValid ? Color.appSuccess : Color.appInk3)
                                Text(confirmationValid ? "Confirmed" : "Type exactly: DELETE")
                                    .font(.system(size: 13))
                                    .foregroundStyle(confirmationValid ? Color.appSuccess : Color.appInk3)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .background(Color.appCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
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
                            Task { await deleteAccount() }
                        } label: {
                            HStack(spacing: 8) {
                                if isDeleting {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text(isDeleting ? "Deleting Account..." : "Delete My Account")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(isFormValid ? Color(hex: "#F9234D") : Color.appLine)
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
                        .disabled(isDeleting)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .background(Color.appPaper)
    }

    // MARK: - Warning Row

    private func warningRow(icon: String, iconColor: Color, iconBg: Color, text: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(iconBg).frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(iconColor)
            }
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Color.appInk)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Deletion Logic

    private func deleteAccount() async {
        errorMessage = nil
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await authService.deleteAccount(currentPassword: password)
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
                return "Password is incorrect. Please try again"
            case 17020:
                return "Network error. Please check your connection and try again"
            case 17011:
                return "User session expired. Please sign in again"
            case 17014:
                return "Authentication error. Please try again"
            case 17995:
                return "Session expired. Please sign out and sign back in to delete your account"
            default:
                let message = error.localizedDescription.lowercased()
                if message.contains("credential") && (message.contains("malformed") || message.contains("expired")) {
                    return "Password is incorrect. Please try again"
                } else if message.contains("network") || message.contains("connection") {
                    return "Network error. Please check your connection and try again"
                } else if message.contains("recent") && message.contains("login") {
                    return "Session expired. Please sign out and sign back in to delete your account"
                } else {
                    return "Unable to delete account. Please try again or contact support"
                }
            }
        } else if error.domain == "FIRFirestoreErrorDomain" {
            switch error.code {
            case 7:  return "Permission error. Please try signing out and back in"
            case 14: return "Network error. Please check your connection and try again"
            default:
                let message = error.localizedDescription.lowercased()
                if message.contains("network") || message.contains("offline") || message.contains("connection") {
                    return "Network error. Please check your connection and try again"
                } else {
                    return "Unable to delete account data. Please try again or contact support"
                }
            }
        } else {
            let message = error.localizedDescription.lowercased()
            if message.contains("network") || message.contains("internet") || message.contains("connection") {
                return "Network error. Please check your connection and try again"
            } else {
                return error.localizedDescription
            }
        }
    }
}

// MARK: - Preview

#Preview {
    DeleteAccountView()
        .environmentObject(AuthService())
}
