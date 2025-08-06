//
//  FirebaseModels.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/8/6.
//

import Foundation

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

// MARK: - Firebase 組織數據模型
struct OrganizationData: Codable {
    let name: String
    let bossId: String
    let bossName: String
    let inviteCode: String
    let createdAt: Date?
    let memberCount: Int
    let settings: [String: String]?

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

// MARK: - Firebase 組織錯誤類型
enum OrgError: Error, LocalizedError {
    case invalidInviteCode
    case organizationNotFound
    case alreadyInOrganization
    case networkError
    case permissionDenied

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
        }
    }
}
