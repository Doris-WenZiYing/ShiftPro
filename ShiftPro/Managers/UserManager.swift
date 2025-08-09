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
    @Published var lastError: ShiftProError?

    // MARK: - Private Properties
    private let authService = AuthManager.shared
    private let orgManager = OrganizationManager.shared
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard

    private init() {
        setupAuthStateListener()
        loadLocalUserData()
    }

    deinit {
        cancellables.forEach { $0.cancel() }
    }

    // MARK: - 🔧 Firebase Auth 整合

    private func setupAuthStateListener() {
        authService.$currentUser
            .sink { [weak self] firebaseUser in
                self?.handleAuthStateChange(firebaseUser)
            }
            .store(in: &cancellables)

        authService.$lastError
            .sink { [weak self] error in
                self?.lastError = error
            }
            .store(in: &cancellables)
    }

    private func handleAuthStateChange(_ firebaseUser: User?) {
        guard let user = firebaseUser else {
            clearUserData()
            return
        }

        if user.isAnonymous {
            setupGuestMode()
        } else {
            loadUserFromFirebase(userId: user.uid)
        }
    }

    // MARK: - 🛡️ 註冊並創建組織（老闆）

    func signUpAsBoss(email: String, password: String, name: String, orgName: String) -> AnyPublisher<Void, Error> {
        clearError()

        return authService.signUp(email: email, password: password, displayName: name)
            .flatMap { [weak self] firebaseUser -> AnyPublisher<String, Error> in
                guard let self = self else {
                    return Fail<String, Error>(error: ShiftProError.unknown("UserManager unavailable")).eraseToAnyPublisher()
                }
                return self.orgManager.createOrganization(
                    name: orgName,
                    bossUserId: firebaseUser.uid,
                    bossName: name
                )
            }
            .flatMap { [weak self] inviteCode -> AnyPublisher<Void, Error> in
                guard let self = self, let userId = Auth.auth().currentUser?.uid else {
                    return Fail<Void, Error>(error: ShiftProError.authenticationFailed).eraseToAnyPublisher()
                }
                return self.loadUserFromFirebase(userId: userId)
            }
            .handleEvents(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.handleError(error, context: "Boss SignUp")
                    }
                }
            )
            .eraseToAnyPublisher()
    }

    // MARK: - 🛡️ 註冊並加入組織（員工）

    func signUpAsEmployee(email: String, password: String, name: String, inviteCode: String) -> AnyPublisher<Void, Error> {
        clearError()

        return authService.signUp(email: email, password: password, displayName: name)
            .flatMap { [weak self] firebaseUser -> AnyPublisher<FirestoreOrganization, Error> in
                guard let self = self else {
                    return Fail<FirestoreOrganization, Error>(error: ShiftProError.unknown("UserManager unavailable")).eraseToAnyPublisher()
                }
                return self.orgManager.joinOrganization(
                    inviteCode: inviteCode,
                    employeeUserId: firebaseUser.uid,
                    employeeName: name
                )
            }
            .flatMap { [weak self] _ -> AnyPublisher<Void, Error> in
                guard let self = self, let userId = Auth.auth().currentUser?.uid else {
                    return Fail<Void, Error>(error: ShiftProError.authenticationFailed).eraseToAnyPublisher()
                }
                return self.loadUserFromFirebase(userId: userId)
            }
            .handleEvents(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.handleError(error, context: "Employee SignUp")
                    }
                }
            )
            .eraseToAnyPublisher()
    }

    // MARK: - 🔑 登入

    func signIn(email: String, password: String) -> AnyPublisher<Void, Error> {
        clearError()

        return authService.signIn(email: email, password: password)
            .flatMap { [weak self] firebaseUser -> AnyPublisher<Void, Error> in
                guard let self = self else {
                    return Fail<Void, Error>(error: ShiftProError.unknown("UserManager unavailable")).eraseToAnyPublisher()
                }
                return self.loadUserFromFirebase(userId: firebaseUser.uid)
            }
            .handleEvents(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.handleError(error, context: "Sign In")
                    }
                }
            )
            .eraseToAnyPublisher()
    }

    // MARK: - 🔄 從 Firebase 載入用戶資料

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
            .catch { [weak self] error -> AnyPublisher<Void, Error> in
                self?.handleError(error, context: "Load User from Firebase")
                return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    // MARK: - 🔄 更新用戶資料

    private func updateUserProfile(userId: String, organization: FirestoreOrganization?, role: UserRole) {
        guard let firebaseUser = Auth.auth().currentUser else {
            handleError(ShiftProError.authenticationFailed, context: "Update User Profile")
            return
        }

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

    // MARK: - 👤 設定訪客模式

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

        saveUserToLocal()

        print("👤 進入訪客模式")
    }

    // MARK: - 🚪 進入訪客模式

    func enterGuestMode() -> AnyPublisher<Void, Error> {
        clearError()

        return authService.signInAnonymously()
            .map { _ in () }
            .handleEvents(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.handleError(error, context: "Enter Guest Mode")
                    }
                }
            )
            .eraseToAnyPublisher()
    }

    // MARK: - 🚪 登出

    func logout() -> AnyPublisher<Void, Error> {
        clearError()

        return authService.signOut()
            .handleEvents(receiveOutput: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.clearUserData()
                }
            })
            .handleEvents(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.handleError(error, context: "Logout")
                    }
                }
            )
            .eraseToAnyPublisher()
    }

    // MARK: - 🗑️ 清除用戶資料

    private func clearUserData() {
        currentUser = nil
        currentOrganization = nil
        isLoggedIn = false
        userRole = .employee
        isGuest = false

        clearLocalUserData()

        print("🗑️ 用戶資料已清除")
    }

    // MARK: - 🔧 舊版相容性方法（測試用）

    func setCurrentBoss(orgId: String, bossName: String, orgName: String) {
        guard isGuest else {
            print("⚠️ 設定測試老闆僅在訪客模式下可用")
            return
        }

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

        saveUserToLocal()

        print("👑 設定測試老闆身分: \(bossName)")
    }

    func setCurrentEmployee(employeeId: String, employeeName: String, orgId: String, orgName: String) {
        guard isGuest else {
            print("⚠️ 設定測試員工僅在訪客模式下可用")
            return
        }

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

        saveUserToLocal()

        print("👤 設定測試員工身分: \(employeeName)")
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
            setCurrentEmployee(
                employeeId: "demo_employee",
                employeeName: user.name,
                orgId: org.id,
                orgName: org.name
            )
        } else {
            setCurrentBoss(
                orgId: org.id,
                bossName: user.name,
                orgName: org.name
            )
        }

        print("🔄 身分切換完成: \(userRole.rawValue)")
    }

    // MARK: - 📊 Computed Properties

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

    // MARK: - 💾 本地存儲

    private func saveUserToLocal() {
        do {
            if let user = currentUser {
                let userData = try JSONEncoder().encode(user)
                userDefaults.set(userData, forKey: "currentUser")
            }

            if let org = currentOrganization {
                let orgData = try JSONEncoder().encode(org)
                userDefaults.set(orgData, forKey: "currentOrganization")
            }

            userDefaults.set(userRole.rawValue, forKey: "userRole")
            userDefaults.set(isGuest, forKey: "isGuest")
            userDefaults.set(isLoggedIn, forKey: "isLoggedIn")

            print("💾 用戶資料已保存到本地")
        } catch {
            print("❌ 保存用戶資料失敗: \(error)")
        }
    }

    private func loadLocalUserData() {
        do {
            if let userData = userDefaults.data(forKey: "currentUser") {
                currentUser = try JSONDecoder().decode(UserProfile.self, from: userData)
            }

            if let orgData = userDefaults.data(forKey: "currentOrganization") {
                currentOrganization = try JSONDecoder().decode(OrganizationProfile.self, from: orgData)
            }

            if let roleString = userDefaults.string(forKey: "userRole") {
                userRole = UserRole(rawValue: roleString) ?? .employee
            }

            isGuest = userDefaults.bool(forKey: "isGuest")
            isLoggedIn = userDefaults.bool(forKey: "isLoggedIn")

            print("📱 本地用戶資料已載入")
        } catch {
            print("❌ 載入本地用戶資料失敗: \(error)")
            clearLocalUserData()
        }
    }

    private func clearLocalUserData() {
        let keys = ["currentUser", "currentOrganization", "userRole", "isGuest", "isLoggedIn"]
        keys.forEach { userDefaults.removeObject(forKey: $0) }
        print("🗑️ 本地用戶資料已清除")
    }

    // MARK: - 🚨 錯誤處理

    private func handleError(_ error: Error, context: String) {
        let shiftProError: ShiftProError

        if let spError = error as? ShiftProError {
            shiftProError = spError
        } else {
            shiftProError = ShiftProError.unknown("\(context): \(error.localizedDescription)")
        }

        lastError = shiftProError
        print("❌ UserManager Error [\(context)]: \(shiftProError.errorDescription ?? "Unknown")")
    }

    private func clearError() {
        lastError = nil
    }
}
