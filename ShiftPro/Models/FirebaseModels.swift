//
//  FirebaseModels.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/8/6.
//

import Foundation
import Firebase

// MARK: - Firebase 用戶數據模型
struct UserData: Codable {
    let userId: String
    let email: String
    let displayName: String
    let role: String
    let orgId: String?
    let orgName: String?
    let joinedAt: Date?

    // MARK: - 轉換方法
    /// 從應用層模型轉換為 Firebase 模型
    static func from(userProfile: UserProfile, email: String) -> UserData {
        return UserData(
            userId: userProfile.id,
            email: email,
            displayName: userProfile.name,
            role: userProfile.role.rawValue,
            orgId: userProfile.orgId,
            orgName: nil, // 這個會在組織查詢時填充
            joinedAt: Date()
        )
    }

    /// 轉換為應用層模型
    func toUserProfile() -> UserProfile {
        return UserProfile(
            id: userId,
            name: displayName,
            role: UserRole(rawValue: role) ?? .employee,
            orgId: orgId ?? "",
            employeeId: role == UserRole.employee.rawValue ? userId : nil
        )
    }
}

// MARK: - Firebase 組織數據模型 - 🔥 修復數據類型問題
struct OrganizationData: Codable {
    let name: String
    let bossId: String
    let bossName: String
    let inviteCode: String
    let createdAt: Date?
    let memberCount: Int
    let settings: OrganizationSettings?

    // 🔥 新增：組織設定結構，解決數據類型不匹配問題
    struct OrganizationSettings: Codable {
        let maxEmployees: Int  // 🔥 修復：改為 Int 類型
        let timezone: String
        let currency: String?
        let workDays: String?

        enum CodingKeys: String, CodingKey {
            case maxEmployees, timezone, currency, workDays
        }

        // 🔥 自定義初始化器處理類型轉換
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            // 處理 maxEmployees 可能是 String 或 Int 的情況
            if let maxEmployeesInt = try? container.decode(Int.self, forKey: .maxEmployees) {
                self.maxEmployees = maxEmployeesInt
            } else if let maxEmployeesString = try? container.decode(String.self, forKey: .maxEmployees),
                      let maxEmployeesInt = Int(maxEmployeesString) {
                self.maxEmployees = maxEmployeesInt
            } else {
                self.maxEmployees = 10 // 預設值
            }

            self.timezone = try container.decodeIfPresent(String.self, forKey: .timezone) ?? "Asia/Taipei"
            self.currency = try container.decodeIfPresent(String.self, forKey: .currency)
            self.workDays = try container.decodeIfPresent(String.self, forKey: .workDays)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(maxEmployees, forKey: .maxEmployees)
            try container.encode(timezone, forKey: .timezone)
            try container.encodeIfPresent(currency, forKey: .currency)
            try container.encodeIfPresent(workDays, forKey: .workDays)
        }
    }

    // MARK: - 初始化器
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.name = try container.decode(String.self, forKey: .name)
        self.bossId = try container.decode(String.self, forKey: .bossId)
        self.bossName = try container.decode(String.self, forKey: .bossName)
        self.inviteCode = try container.decode(String.self, forKey: .inviteCode)
        self.memberCount = try container.decodeIfPresent(Int.self, forKey: .memberCount) ?? 1

        // 安全解碼日期
        if let timestamp = try? container.decode(Timestamp.self, forKey: .createdAt) {
            self.createdAt = timestamp.dateValue()
        } else if let date = try? container.decode(Date.self, forKey: .createdAt) {
            self.createdAt = date
        } else {
            self.createdAt = nil
        }

        // 🔥 修復：安全解碼 settings
        if let settingsData = try? container.decode(OrganizationSettings.self, forKey: .settings) {
            self.settings = settingsData
        }
//        } else if let settingsDict = try? container.decode([String.self], forKey: .settings) {
//            // 嘗試從舊格式轉換
//            self.settings = try? OrganizationSettings.fromDictionary(settingsDict)
//        }
        else {
            self.settings = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case name, bossId, bossName, inviteCode, createdAt, memberCount, settings
    }

    // MARK: - 轉換方法
    /// 轉換為應用層模型
    func toOrganizationProfile(id: String) -> OrganizationProfile {
        return OrganizationProfile(
            id: id,
            name: name,
            bossId: bossId,
            createdAt: createdAt ?? Date()
        )
    }
}

// 🔥 新增：OrganizationSettings 的字典轉換擴展
extension OrganizationData.OrganizationSettings {
    static func fromDictionary(_ dict: [String: Any]) throws -> OrganizationData.OrganizationSettings {
        var maxEmployees = 10

        // 處理 maxEmployees 的各種可能類型
        if let maxEmpInt = dict["maxEmployees"] as? Int {
            maxEmployees = maxEmpInt
        } else if let maxEmpString = dict["maxEmployees"] as? String,
                  let maxEmpInt = Int(maxEmpString) {
            maxEmployees = maxEmpInt
        } else if let maxEmpDouble = dict["maxEmployees"] as? Double {
            maxEmployees = Int(maxEmpDouble)
        }

        let timezone = dict["timezone"] as? String ?? "Asia/Taipei"
        let currency = dict["currency"] as? String
        let workDays = dict["workDays"] as? String

        return OrganizationData.OrganizationSettings(
            maxEmployees: maxEmployees,
            timezone: timezone,
            currency: currency,
            workDays: workDays
        )
    }

    // 手動初始化器
    init(maxEmployees: Int, timezone: String, currency: String? = nil, workDays: String? = nil) {
        self.maxEmployees = maxEmployees
        self.timezone = timezone
        self.currency = currency
        self.workDays = workDays
    }
}

// MARK: - Firebase 組織錯誤類型
enum OrgError: Error, LocalizedError {
    case invalidInviteCode
    case organizationNotFound
    case alreadyInOrganization
    case networkError
    case permissionDenied
    case dataDecodingError(String)

    var errorDescription: String? {
        switch self {
        case .invalidInviteCode:
            return "邀請碼無效或已過期"
        case .organizationNotFound:
            return "找不到指定的組織"
        case .alreadyInOrganization:
            return "您已經是該組織的成員"
        case .networkError:
            return "網絡連接錯誤，請稍後重試"
        case .permissionDenied:
            return "權限不足，無法執行此操作"
        case .dataDecodingError(let details):
            return "資料格式錯誤：\(details)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidInviteCode:
            return "請向組織管理者索取有效的邀請碼"
        case .organizationNotFound:
            return "請確認組織是否存在或聯繫管理者"
        case .alreadyInOrganization:
            return "您可以直接使用現有的組織功能"
        case .networkError:
            return "請檢查網絡連接後重試"
        case .permissionDenied:
            return "請聯繫組織管理者獲取相應權限"
        case .dataDecodingError:
            return "請聯繫技術支援或重新設定組織資料"
        }
    }
}
