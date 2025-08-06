//
//  UserManager.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/25.
//

import Foundation
import Combine
import FirebaseAuth

class UserManager: ObservableObject {
    static let shared = UserManager()

    // MARK: - Published Properties
    @Published var currentUser: UserProfile?
    @Published var currentOrganization: OrganizationProfile?
    @Published var isLoggedIn: Bool = false
    @Published var userRole: UserRole = .employee
    @Published var isGuest: Bool = false

    // MARK: - Private Properties
    private let authService = AuthManager.shared
    private let orgManager = OrganizationManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupAuthStateListener()
        loadLocalUserData()
    }

    // MARK: - Firebase Auth 整合
    private func setupAuthStateListener() {
        authService.$currentUser
            .sink { [weak self] firebaseUser in
                if let user = firebaseUser {
                    if user.isAnonymous {
                        self?.setupGuestMode()
                    } else {
                        self?.loadUserFromFirebase(userId: user.uid)
                    }
                } else {
                    self?.clearUserData()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - 註冊並創建組織（老闆）
    func signUpAsBoss(email: String, password: String, name: String, orgName: String) -> AnyPublisher<Void, Error> {
        return authService.signUp(email: email, password: password, displayName: name)
            .flatMap { [weak self] firebaseUser in
                guard let self = self else {
                    return Fail<String, Error>(error: AuthError.unknownError).eraseToAnyPublisher()
                }
                return self.orgManager.createOrganization(
                    name: orgName,
                    bossUserId: firebaseUser.uid,
                    bossName: name
                )
            }
            .flatMap { [weak self] inviteCode in
                guard let self = self, let userId = Auth.auth().currentUser?.uid else {
                    return Fail<Void, Error>(error: AuthError.unknownError).eraseToAnyPublisher()
                }
                return self.loadUserFromFirebase(userId: userId)
            }
            .eraseToAnyPublisher()
    }

    // MARK: - 註冊並加入組織（員工）
    func signUpAsEmployee(email: String, password: String, name: String, inviteCode: String) -> AnyPublisher<Void, Error> {
        return authService.signUp(email: email, password: password, displayName: name)
            .flatMap { [weak self] firebaseUser in
                guard let self = self else {
                    return Fail<FirestoreOrganization, Error>(error: AuthError.unknownError).eraseToAnyPublisher()
                }
                return self.orgManager.joinOrganization(
                    inviteCode: inviteCode,
                    employeeUserId: firebaseUser.uid,
                    employeeName: name
                )
            }
            .flatMap { [weak self] _ in
                guard let self = self, let userId = Auth.auth().currentUser?.uid else {
                    return Fail<Void, Error>(error: AuthError.unknownError).eraseToAnyPublisher()
                }
                return self.loadUserFromFirebase(userId: userId)
            }
            .eraseToAnyPublisher()
    }

    // MARK: - 登入
    func signIn(email: String, password: String) -> AnyPublisher<Void, Error> {
        return authService.signIn(email: email, password: password)
            .flatMap { [weak self] firebaseUser in
                guard let self = self else {
                    return Fail<Void, Error>(error: AuthError.unknownError).eraseToAnyPublisher()
                }
                return self.loadUserFromFirebase(userId: firebaseUser.uid)
            }
            .eraseToAnyPublisher()
    }

    // MARK: - 從 Firebase 載入用戶資料
    private func loadUserFromFirebase(userId: String) -> AnyPublisher<Void, Error> {
        return orgManager.loadUserOrganization(userId: userId)
            .handleEvents(receiveOutput: { [weak self] (organization, role) in
                DispatchQueue.main.async {
                    self?.updateUserProfile(
                        userId: userId,
                        organization: organization,
                        role: role
                    )
                }
            })
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    // MARK: - 更新用戶資料
    private func updateUserProfile(userId: String, organization: FirestoreOrganization?, role: UserRole) {
        guard let firebaseUser = Auth.auth().currentUser else { return }

        let userProfile = UserProfile(
            id: userId,
            name: firebaseUser.displayName ?? "用戶",
            role: role,
            orgId: organization?.id ?? "",
            employeeId: role == .employee ? userId : nil
        )

        let orgProfile: OrganizationProfile?
        if let org = organization {
            orgProfile = OrganizationProfile(
                id: org.id,
                name: org.name,
                bossId: role == .boss ? userId : nil,
                createdAt: org.createdAt ?? Date()
            )
        } else {
            orgProfile = nil
        }

        currentUser = userProfile
        currentOrganization = orgProfile
        userRole = role
        isLoggedIn = true
        isGuest = false

        saveUserToLocal()

        print("✅ 用戶資料更新: \(userProfile.name) (\(role.rawValue))")
    }

    // MARK: - 設定訪客模式
    private func setupGuestMode() {
        currentUser = UserProfile(
            id: "guest",
            name: "訪客",
            role: .employee,
            orgId: "demo_store_01",
            employeeId: "guest"
        )

        currentOrganization = OrganizationProfile(
            id: "demo_store_01",
            name: "體驗模式",
            bossId: nil,
            createdAt: Date()
        )

        userRole = .employee
        isLoggedIn = false
        isGuest = true

        print("👤 進入訪客模式")
    }

    // MARK: - 進入訪客模式
    func enterGuestMode() -> AnyPublisher<Void, Error> {
        return authService.signInAnonymously()
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    // MARK: - 登出
    func logout() -> AnyPublisher<Void, Error> {
        return authService.signOut()
            .handleEvents(receiveOutput: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.clearUserData()
                }
            })
            .eraseToAnyPublisher()
    }

    // MARK: - 清除用戶資料
    private func clearUserData() {
        currentUser = nil
        currentOrganization = nil
        isLoggedIn = false
        userRole = .employee
        isGuest = false

        clearLocalUserData()

        print("🗑️ 用戶資料已清除")
    }

    // MARK: - 舊版相容性方法（保留測試功能）
    func setCurrentBoss(orgId: String, bossName: String, orgName: String) {
        guard isGuest else { return }  // 只允許在訪客模式下使用

        let user = UserProfile(
            id: "demo_boss",
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

        print("👑 設定測試老闆身分: \(bossName)")
    }

    func setCurrentEmployee(employeeId: String, employeeName: String, orgId: String, orgName: String) {
        guard isGuest else { return }  // 只允許在訪客模式下使用

        let user = UserProfile(
            id: employeeId,
            name: employeeName,
            role: .employee,
            orgId: orgId,
            employeeId: employeeId
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

        print("👤 設定測試員工身分: \(employeeName)")
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
        currentUser?.employeeId ?? currentUser?.id ?? "emp_1"
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

    var authStatus: String {
        if isGuest {
            return "訪客模式"
        } else if isLoggedIn {
            return "已登入"
        } else {
            return "未登入"
        }
    }

    // MARK: - Local Storage (保持原有邏輯)
    private func saveUserToLocal() {
        // 實現本地存儲邏輯...
    }

    private func loadLocalUserData() {
        // 實現本地載入邏輯...
    }

    private func clearLocalUserData() {
        // 實現本地清除邏輯...
    }

    func switchRole() {
        guard isGuest else {
            print("⚠️ 切換身分僅在訪客模式下可用")
            return
        }

        guard let user = currentUser, let org = currentOrganization else {
            print("❌ 缺少用戶或組織資訊，無法切換身分")
            return
        }

        if userRole == .boss {
            // 切換到員工
            setCurrentEmployee(
                employeeId: "demo_employee",
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

        print("🔄 身分切換完成: \(userRole.rawValue)")
    }
}
