//
//  FirestoreModel.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/19.
//

import Foundation
import FirebaseFirestore

// MARK: - 🏢 organizations/{orgId}
public struct FirestoreOrganization: Codable, Identifiable {
    public let id: String
    public let name: String
    public let createdAt: Date?
    public let settings: [String: String]?

    public var docId: String { id }

    enum CodingKeys: String, CodingKey {
        case id, name, createdAt, settings
    }

    public init(id: String, name: String, createdAt: Date? = nil, settings: [String: String]? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.settings = settings
    }

    // 🛡️ 穩定的解碼器
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // 嘗試從多個來源解碼 ID
        if let explicitId = try? container.decode(String.self, forKey: .id) {
            self.id = explicitId
        } else {
            // 如果沒有明確的 ID，使用空字串（將由外部設定）
            self.id = ""
        }

        self.name = try container.decode(String.self, forKey: .name)

        // 安全解碼日期
        if let timestamp = try? container.decode(Timestamp.self, forKey: .createdAt) {
            self.createdAt = timestamp.dateValue()
        } else if let date = try? container.decode(Date.self, forKey: .createdAt) {
            self.createdAt = date
        } else {
            self.createdAt = nil
        }

        self.settings = try container.decodeIfPresent([String: String].self, forKey: .settings)
    }

    // 🛡️ 穩定的編碼器
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        if let createdAt = createdAt {
            try container.encode(Timestamp(date: createdAt), forKey: .createdAt)
        }
        try container.encodeIfPresent(settings, forKey: .settings)
    }
}

// MARK: - 👥 employees/{orgId}_{employeeId}
public struct FirestoreEmployee: Codable, Identifiable {
    public let id: String
    public let orgId: String
    public let employeeId: String
    public let name: String
    public let role: String
    public let createdAt: Date?
    public let updatedAt: Date?

    public var docId: String { id }

    enum CodingKeys: String, CodingKey {
        case id, orgId, employeeId, name, role, createdAt, updatedAt
    }

    public init(id: String, orgId: String, employeeId: String, name: String, role: String, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.orgId = orgId
        self.employeeId = employeeId
        self.name = name
        self.role = role
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // 🛡️ 穩定的解碼器
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // 嘗試解碼 ID 或從其他欄位構建
        if let explicitId = try? container.decode(String.self, forKey: .id) {
            self.id = explicitId
        } else {
            // 從 orgId 和 employeeId 構建 ID
            let orgId = try container.decode(String.self, forKey: .orgId)
            let employeeId = try container.decode(String.self, forKey: .employeeId)
            self.id = "\(orgId)_\(employeeId)"
        }

        self.orgId = try container.decode(String.self, forKey: .orgId)
        self.employeeId = try container.decode(String.self, forKey: .employeeId)
        self.name = try container.decode(String.self, forKey: .name)
        self.role = try container.decode(String.self, forKey: .role)

        // 安全解碼日期
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ??
                        (try? container.decodeIfPresent(Timestamp.self, forKey: .createdAt))?.dateValue()

        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ??
                        (try? container.decodeIfPresent(Timestamp.self, forKey: .updatedAt))?.dateValue()
    }
}

// MARK: - 🏖️ vacation_rules/{orgId}_{month}
public struct FirestoreVacationRule: Codable, Identifiable {
    public let id: String
    public let orgId: String
    public let month: String
    public let type: String
    public let monthlyLimit: Int?
    public let weeklyLimit: Int?
    public let published: Bool
    public let createdAt: Date
    public let updatedAt: Date?

    public var docId: String { id }

    enum CodingKeys: String, CodingKey {
        case id, orgId, month, type, monthlyLimit, weeklyLimit, published, createdAt, updatedAt
    }

    public init(id: String, orgId: String, month: String, type: String, monthlyLimit: Int? = nil, weeklyLimit: Int? = nil, published: Bool = false, createdAt: Date = Date(), updatedAt: Date? = nil) {
        self.id = id
        self.orgId = orgId
        self.month = month
        self.type = type
        self.monthlyLimit = monthlyLimit
        self.weeklyLimit = weeklyLimit
        self.published = published
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // 🛡️ 穩定的解碼器
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // 構建或解碼 ID
        if let explicitId = try? container.decode(String.self, forKey: .id) {
            self.id = explicitId
        } else {
            let orgId = try container.decode(String.self, forKey: .orgId)
            let month = try container.decode(String.self, forKey: .month)
            self.id = "\(orgId)_\(month)"
        }

        self.orgId = try container.decode(String.self, forKey: .orgId)
        self.month = try container.decode(String.self, forKey: .month)
        self.type = try container.decode(String.self, forKey: .type)

        // 安全解碼可選整數（處理 NSNull）
        self.monthlyLimit = try container.decodeIfPresent(Int.self, forKey: .monthlyLimit)
        self.weeklyLimit = try container.decodeIfPresent(Int.self, forKey: .weeklyLimit)

        self.published = try container.decodeIfPresent(Bool.self, forKey: .published) ?? false

        // 必要的日期欄位，帶預設值
        if let timestamp = try? container.decode(Timestamp.self, forKey: .createdAt) {
            self.createdAt = timestamp.dateValue()
        } else if let date = try? container.decode(Date.self, forKey: .createdAt) {
            self.createdAt = date
        } else {
            self.createdAt = Date() // 預設為當前時間
        }

        // 可選的更新日期
        if let timestamp = try? container.decodeIfPresent(Timestamp.self, forKey: .updatedAt) {
            self.updatedAt = timestamp.dateValue()
        } else {
            self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        }
    }
}

// MARK: - 📅 employee_schedules/{orgId}_{employeeId}_{month}
public struct FirestoreEmployeeSchedule: Codable, Identifiable {
    public let id: String
    public let orgId: String
    public let employeeId: String
    public let month: String
    public let selectedDates: [String]
    public let isSubmitted: Bool
    public let createdAt: Date
    public let updatedAt: Date?

    public var docId: String { id }

    enum CodingKeys: String, CodingKey {
        case id, orgId, employeeId, month, selectedDates, isSubmitted, createdAt, updatedAt
    }

    public init(id: String, orgId: String, employeeId: String, month: String, selectedDates: [String], isSubmitted: Bool = false, createdAt: Date = Date(), updatedAt: Date? = nil) {
        self.id = id
        self.orgId = orgId
        self.employeeId = employeeId
        self.month = month
        self.selectedDates = selectedDates
        self.isSubmitted = isSubmitted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // 🛡️ 穩定的解碼器
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // 構建或解碼 ID
        if let explicitId = try? container.decode(String.self, forKey: .id) {
            self.id = explicitId
        } else {
            let orgId = try container.decode(String.self, forKey: .orgId)
            let employeeId = try container.decode(String.self, forKey: .employeeId)
            let month = try container.decode(String.self, forKey: .month)
            self.id = "\(orgId)_\(employeeId)_\(month)"
        }

        self.orgId = try container.decode(String.self, forKey: .orgId)
        self.employeeId = try container.decode(String.self, forKey: .employeeId)
        self.month = try container.decode(String.self, forKey: .month)

        // 安全解碼陣列（可能為空）
        self.selectedDates = try container.decodeIfPresent([String].self, forKey: .selectedDates) ?? []

        self.isSubmitted = try container.decodeIfPresent(Bool.self, forKey: .isSubmitted) ?? false

        // 安全解碼必要日期
        if let timestamp = try? container.decode(Timestamp.self, forKey: .createdAt) {
            self.createdAt = timestamp.dateValue()
        } else if let date = try? container.decode(Date.self, forKey: .createdAt) {
            self.createdAt = date
        } else {
            self.createdAt = Date()
        }

        // 可選更新日期
        if let timestamp = try? container.decodeIfPresent(Timestamp.self, forKey: .updatedAt) {
            self.updatedAt = timestamp.dateValue()
        } else {
            self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        }
    }
}

// MARK: - 🔧 輔助擴展
extension FirestoreOrganization {
    /// 安全的設定取得方法
    func getSetting(_ key: String, defaultValue: String = "") -> String {
        return settings?[key] ?? defaultValue
    }
}

extension FirestoreVacationRule {
    /// 檢查規則是否有效
    var isValid: Bool {
        return !orgId.isEmpty && !month.isEmpty && !type.isEmpty
    }

    /// 取得實際的限制值
    var effectiveMonthlyLimit: Int {
        return monthlyLimit ?? 8
    }

    var effectiveWeeklyLimit: Int {
        return weeklyLimit ?? 2
    }
}

extension FirestoreEmployeeSchedule {
    /// 檢查是否有選擇的日期
    var hasSelectedDates: Bool {
        return !selectedDates.isEmpty
    }

    /// 取得選擇的日期數量
    var selectedCount: Int {
        return selectedDates.count
    }
}
