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
    public let id: String                     // 直接使用 orgId 作為 id
    public let name: String
    public let createdAt: Date?
    public let settings: [String: String]?   // 可選的設定字典

    public var docId: String { id }

    enum CodingKeys: String, CodingKey {
        case name, createdAt, settings
    }

    public init(id: String, name: String, createdAt: Date? = nil, settings: [String: String]? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.settings = settings
    }

    // 自定義解碼器
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        self.settings = try container.decodeIfPresent([String: String].self, forKey: .settings)

        // id 將在 Firebase 讀取時由文檔 ID 設定
        self.id = ""
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
