//
//  FirestoreModel.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/19.
//

import Foundation
import FirebaseFirestore

// MARK: - organizations/{orgId}
public struct FirestoreOrganization: Codable, Identifiable {
    public var id: String { "\(orgId)" }
    public let orgId: String
    public let name: String
    public let createdAt: Date?
    public let settings: [String: String]?   // 可選的設定字典

    public var docId: String { id }
    enum CodingKeys: String, CodingKey {
        case name, createdAt, settings
    }

    public init(name: String, createdAt: Date? = nil, settings: [String: String]? = nil) {
        self.name = name
        self.createdAt = createdAt
        self.settings = settings
    }
}

// MARK: - employees/{orgId}_{employeeId}
public struct FirestoreEmployee: Codable, Identifiable {
    public var id: String { "\(orgId)_\(employeeId)" }
    public let orgId: String
    public let employeeId: String
    public let name: String
    public let role: String
    public let createdAt: Date?
    public let updatedAt: Date?

    public var docId: String { id }
}

// MARK: - vacation_rules/{orgId}_{month}
public struct FirestoreVacationRule: Codable, Identifiable {
    public var id: String { "\(orgId)_\(month)" }
    public let orgId: String
    public let month: String                  // "2025-08"
    public let type: String                   // "monthly"/"weekly"/"flexible"
    public let monthlyLimit: Int?             // 當 type=="monthly" 或 flexible
    public let weeklyLimit: Int?              // 當 type=="weekly"
    public let published: Bool
    public let createdAt: Date
    public let updatedAt: Date?
}

// MARK: - employee_schedules/{orgId}_{employeeId}_{month}
public struct FirestoreEmployeeSchedule: Codable, Identifiable {
    public var id: String { "\(orgId)_\(employeeId)_\(month)" }
    public let orgId: String
    public let employeeId: String
    public let month: String                  // "2025-08"
    public let selectedDates: [String]        // ["2025-08-05", "2025-08-12"]
    public let isSubmitted: Bool
    public let createdAt: Date
    public let updatedAt: Date?
}
