//
//  UserProfile.swift
//  Wandova
//
//  Created by seren on 14.04.2026.
//

import Foundation

struct UserProfile: Codable, Identifiable, Equatable {
    let id: String
    let email: String
    var firstName: String
    var lastName: String
    var allowComparison: Bool
    let createdAt: Date
    var updatedAt: Date

    var displayName: String {
        let name = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? email : name
    }

    var initials: String {
        let f = String(firstName.prefix(1)).uppercased()
        let l = String(lastName.prefix(1)).uppercased()
        if !f.isEmpty && !l.isEmpty { return f + l }
        if !f.isEmpty { return f }
        return emailInitials(email)
    }

    init(userId: String, email: String, firstName: String = "", lastName: String = "", allowComparison: Bool = false) {
        self.id = userId
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.allowComparison = allowComparison
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }

    init(userId: String, email: String, firstName: String, lastName: String, allowComparison: Bool, createdAt: Date, updatedAt: Date) {
        self.id = userId
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.allowComparison = allowComparison
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private func emailInitials(_ email: String) -> String {
        let parts = email.components(separatedBy: "@").first?
            .components(separatedBy: CharacterSet(charactersIn: "._-"))
            .filter { !$0.isEmpty } ?? []
        if parts.count >= 2 {
            return (parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String((parts.first ?? "?").prefix(1)).uppercased()
    }
}
