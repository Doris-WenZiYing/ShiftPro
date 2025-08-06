//
//  UserModels.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/8/3.
//

import Foundation

enum UserRole: String, CaseIterable, Codable {
    case boss = "boss"
    case employee = "employee"
}

struct UserProfile: Codable {
    let id: String
    let name: String
    let role: UserRole
    let orgId: String
    let employeeId: String?

    init(id: String, name: String, role: UserRole, orgId: String, employeeId: String?) {
        self.id = id
        self.name = name
        self.role = role
        self.orgId = orgId
        self.employeeId = employeeId
    }
}

struct OrganizationProfile: Codable {
    let id: String
    let name: String
    let bossId: String?
    let createdAt: Date

    init(id: String, name: String, bossId: String?, createdAt: Date) {
        self.id = id
        self.name = name
        self.bossId = bossId
        self.createdAt = createdAt
    }
}
