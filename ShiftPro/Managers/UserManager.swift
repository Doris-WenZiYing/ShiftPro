//
//  UserManager.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/25.
//

import Foundation
import Combine

class UserManager: ObservableObject {
    static let shared = UserManager()

    // MARK: - Published Properties
    @Published var currentUser: UserProfile?
    @Published var currentOrganization: OrganizationProfile?
    @Published var isLoggedIn: Bool = false
    @Published var userRole: UserRole = .employee

    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    // 🔥 修復：統一的員工ID計數器
    private static var employeeIdCounter: Int {
        get {
            UserDefaults.standard.integer(forKey: "employeeIdCounter")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "employeeIdCounter")
        }
    }

    private init() {
        loadUserFromLocal()

        // 🔥 修復：初始化計數器
        if Self.employeeIdCounter == 0 {
            Self.employeeIdCounter = 1
        }
    }

    // MARK: - User Profile Management

    /// 設定當前用戶（老闆）
    func setCurrentBoss(orgId: String, bossName: String, orgName: String) {
        let user = UserProfile(
            id: "boss_\(orgId)",
            name: bossName,
            role: .boss,
            orgId: orgId,
            employeeId: nil
        )

        let org = OrganizationProfile(
            id: orgId,
            name: orgName,
            bossId: user.id,
            createdAt: Date()
        )

        currentUser = user
        currentOrganization = org
        userRole = .boss
        isLoggedIn = true

        saveUserToLocal()

        print("👑 設定老闆身分: \(bossName) - 組織: \(orgName)")
    }

    /// 🔥 修復：設定當前用戶（員工）- 使用簡潔的ID
    func setCurrentEmployee(employeeId: String, employeeName: String, orgId: String, orgName: String) {
        // 🔥 如果傳入的是亂碼ID，生成新的簡潔ID
        let cleanEmployeeId: String
        if employeeId.contains(".") || employeeId.count > 10 {
            cleanEmployeeId = "emp_\(Self.employeeIdCounter)"
            Self.employeeIdCounter += 1
            print("🔧 轉換亂碼ID \(employeeId) -> \(cleanEmployeeId)")
        } else {
            cleanEmployeeId = employeeId
        }

        let user = UserProfile(
            id: cleanEmployeeId,
            name: employeeName,
            role: .employee,
            orgId: orgId,
            employeeId: cleanEmployeeId
        )

        let org = OrganizationProfile(
            id: orgId,
            name: orgName,
            bossId: nil,
            createdAt: Date()
        )

        currentUser = user
        currentOrganization = org
        userRole = .employee
        isLoggedIn = true

        saveUserToLocal()

        print("👤 設定員工身分: \(employeeName) - ID: \(cleanEmployeeId) - 組織: \(orgName)")
    }

    /// 切換身分（在同一組織內）
    func switchRole() {
        guard let user = currentUser, let org = currentOrganization else { return }

        if userRole == .boss {
            // 切換到員工
            let employeeId = "emp_\(Self.employeeIdCounter)"
            Self.employeeIdCounter += 1
            setCurrentEmployee(
                employeeId: employeeId,
                employeeName: user.name,
                orgId: org.id,
                orgName: org.name
            )
        } else {
            // 切換到老闆
            setCurrentBoss(
                orgId: org.id,
                bossName: user.name,
                orgName: org.name
            )
        }
    }

    /// 登出
    func logout() {
        currentUser = nil
        currentOrganization = nil
        isLoggedIn = false
        userRole = .employee

        // 清除本地資料
        userDefaults.removeObject(forKey: "CurrentUser")
        userDefaults.removeObject(forKey: "CurrentOrganization")
        userDefaults.removeObject(forKey: "UserRole")

        print("👋 用戶已登出")
    }

    // MARK: - Computed Properties

    var displayName: String {
        currentUser?.name ?? "訪客"
    }

    var organizationName: String {
        currentOrganization?.name ?? "未加入組織"
    }

    var currentOrgId: String {
        currentOrganization?.id ?? "demo_store_01"
    }

    var currentEmployeeId: String {
        currentUser?.employeeId ?? "emp_1"
    }

    var roleDisplayText: String {
        switch userRole {
        case .boss: return "管理者"
        case .employee: return "員工"
        }
    }

    var roleIcon: String {
        switch userRole {
        case .boss: return "crown.fill"
        case .employee: return "person.fill"
        }
    }

    // MARK: - Local Storage

    private func saveUserToLocal() {
        if let user = currentUser,
           let userData = try? JSONEncoder().encode(user) {
            userDefaults.set(userData, forKey: "CurrentUser")
        }

        if let org = currentOrganization,
           let orgData = try? JSONEncoder().encode(org) {
            userDefaults.set(orgData, forKey: "CurrentOrganization")
        }

        userDefaults.set(userRole.rawValue, forKey: "UserRole")
        userDefaults.set(isLoggedIn, forKey: "IsLoggedIn")
    }

    private func loadUserFromLocal() {
        // 載入用戶資料
        if let userData = userDefaults.data(forKey: "CurrentUser"),
           let user = try? JSONDecoder().decode(UserProfile.self, from: userData) {

            // 🔥 修復：檢查並修復亂碼員工ID
            if user.role == .employee,
               let empId = user.employeeId,
               (empId.contains(".") || empId.count > 10) {

                let newEmployeeId = "emp_\(Self.employeeIdCounter)"
                Self.employeeIdCounter += 1

                let fixedUser = UserProfile(
                    id: newEmployeeId,
                    name: user.name,
                    role: user.role,
                    orgId: user.orgId,
                    employeeId: newEmployeeId
                )

                currentUser = fixedUser
                print("🔧 修復亂碼員工ID: \(empId) -> \(newEmployeeId)")

                // 重新保存修復後的資料
                saveUserToLocal()
            } else {
                currentUser = user
            }
        }

        // 載入組織資料
        if let orgData = userDefaults.data(forKey: "CurrentOrganization"),
           let org = try? JSONDecoder().decode(OrganizationProfile.self, from: orgData) {
            currentOrganization = org
        }

        // 載入身分和登入狀態
        if let roleString = userDefaults.string(forKey: "UserRole"),
           let role = UserRole(rawValue: roleString) {
            userRole = role
        }

        isLoggedIn = userDefaults.bool(forKey: "IsLoggedIn")

        if isLoggedIn {
            print("📱 從本地載入用戶: \(displayName) (\(roleDisplayText)) ID: \(currentEmployeeId)")
        }
    }
}

// MARK: - Supporting Models

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
