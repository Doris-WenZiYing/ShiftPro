//
//  AuthManager.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/8/3.
//

import Foundation
import Firebase
import FirebaseAuth
import Combine

class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var lastError: ShiftProError?

    private var cancellables = Set<AnyCancellable>()
    private var authStateListener: AuthStateDidChangeListenerHandle?

    // MARK: - 🔧 Configuration
    private struct Config {
        static let forceLogoutOnInit = true
        static let userDefaultsKeys = [
            "currentUser", "currentOrganization", "userRole",
            "isGuest", "isLoggedIn", "orgId"
        ]
        static let dataKeyPrefixes = ["VacationData_", "VacationLimits_"]
    }

    init() {
        if Config.forceLogoutOnInit {
            performForceLogout(clearUserDefaults: true)
        }
        setupAuthStateListener()
    }

    deinit {
        cleanup()
    }

    // MARK: - 🔧 初始化和狀態管理

    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.handleAuthStateChange(user: user)
            }
        }
    }

    private func handleAuthStateChange(user: User?) {
        currentUser = user
        isAuthenticated = user != nil

        logAuthState(user: user)
    }

    private func logAuthState(user: User?) {
        if let user = user {
            print("✅ 用戶已登入: \(user.email ?? "匿名用戶")")
        } else {
            print("🔓 用戶已登出")
        }
    }

    // MARK: - 🔄 登出系統

    func signOut() -> AnyPublisher<Void, Error> {
        clearError()

        return Future<Void, Error> { [weak self] promise in
            do {
                try Auth.auth().signOut()
                print("✅ Firebase Auth 登出成功")

                self?.clearAuthState()
                promise(.success(()))
            } catch {
                let shiftProError = self?.mapAuthError(error) ?? ShiftProError.unknown("登出失敗")
                self?.lastError = shiftProError
                print("❌ 登出失敗: \(error)")
                promise(.failure(shiftProError))
            }
        }
        .eraseToAnyPublisher()
    }

    // 🔥 統一的強制登出方法
    private func performForceLogout(clearUserDefaults: Bool = false) {
        do {
            try Auth.auth().signOut()
            print("🔥 強制登出成功")
        } catch {
            print("⚠️ 強制登出失敗: \(error)")
        }

        clearAuthState()

        if clearUserDefaults {
            clearAllUserData()
        }
    }

    // 🔥 統一的認證狀態清除
    private func clearAuthState() {
        currentUser = nil
        isAuthenticated = false
        lastError = nil

        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    // 🔥 統一的用戶資料清除
    private func clearAllUserData() {
        let userDefaults = UserDefaults.standard

        // 清除指定的 keys
        Config.userDefaultsKeys.forEach { key in
            userDefaults.removeObject(forKey: key)
        }

        // 清除帶前綴的資料
        let allKeys = Array(userDefaults.dictionaryRepresentation().keys)
        allKeys.forEach { key in
            if Config.dataKeyPrefixes.contains(where: { key.hasPrefix($0) }) {
                userDefaults.removeObject(forKey: key)
            }
        }

        print("🗑️ 清除所有本地用戶資料")
    }

    // 🔥 開發用方法（簡化）
    func forceSignOutForDevelopment() {
        performForceLogout(clearUserDefaults: true)
        print("🔧 開發模式：強制重置認證狀態")
    }

    // MARK: - 🛡️ 註冊

    func signUp(email: String, password: String, displayName: String) -> AnyPublisher<User, Error> {
        // 🔥 統一的驗證邏輯
        if let validationError = validateSignUpInput(email: email, password: password, displayName: displayName) {
            return Fail(error: validationError).eraseToAnyPublisher()
        }

        return performSignUp(email: email, password: password, displayName: displayName)
    }

    private func validateSignUpInput(email: String, password: String, displayName: String) -> ShiftProError? {
        if !isValidEmail(email) {
            return .validationFailed("電子郵件格式不正確")
        }
        if !isValidPassword(password) {
            return .validationFailed("密碼必須至少6個字符")
        }
        if displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .validationFailed("請輸入顯示名稱")
        }
        return nil
    }

    private func performSignUp(email: String, password: String, displayName: String) -> AnyPublisher<User, Error> {
        isLoading = true
        clearError()

        return Future<User, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(ShiftProError.unknown("AuthManager unavailable")))
                return
            }

            Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.handleSignUpResult(result: result, error: error, displayName: displayName, promise: promise)
                }
            }
        }
        .eraseToAnyPublisher()
    }

    private func handleSignUpResult(
        result: AuthDataResult?,
        error: Error?,
        displayName: String,
        promise: @escaping (Result<User, Error>) -> Void
    ) {
        if let error = error {
            let shiftProError = mapAuthError(error)
            lastError = shiftProError
            print("❌ 註冊失敗: \(error.localizedDescription)")
            promise(.failure(shiftProError))
            return
        }

        guard let user = result?.user else {
            let unknownError = ShiftProError.unknown("註冊後無法取得用戶資訊")
            lastError = unknownError
            promise(.failure(unknownError))
            return
        }

        updateUserDisplayName(user: user, displayName: displayName)
        print("✅ 註冊成功: \(user.email ?? "")")
        promise(.success(user))
    }

    private func updateUserDisplayName(user: User, displayName: String) {
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        changeRequest.commitChanges { error in
            if let error = error {
                print("⚠️ 更新顯示名稱失敗: \(error)")
            } else {
                print("✅ 顯示名稱更新成功")
            }
        }
    }

    // MARK: - 🔑 登入

    func signIn(email: String, password: String) -> AnyPublisher<User, Error> {
        // 🔥 統一的驗證邏輯
        if let validationError = validateSignInInput(email: email, password: password) {
            return Fail(error: validationError).eraseToAnyPublisher()
        }

        return performSignIn(email: email, password: password)
    }

    private func validateSignInInput(email: String, password: String) -> ShiftProError? {
        if !isValidEmail(email) {
            return .validationFailed("電子郵件格式不正確")
        }
        if password.isEmpty {
            return .validationFailed("請輸入密碼")
        }
        return nil
    }

    private func performSignIn(email: String, password: String) -> AnyPublisher<User, Error> {
        isLoading = true
        clearError()

        return Future<User, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(ShiftProError.unknown("AuthManager unavailable")))
                return
            }

            Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.handleSignInResult(result: result, error: error, promise: promise)
                }
            }
        }
        .eraseToAnyPublisher()
    }

    private func handleSignInResult(
        result: AuthDataResult?,
        error: Error?,
        promise: @escaping (Result<User, Error>) -> Void
    ) {
        if let error = error {
            let shiftProError = mapAuthError(error)
            lastError = shiftProError
            print("❌ 登入失敗: \(error.localizedDescription)")
            promise(.failure(shiftProError))
            return
        }

        guard let user = result?.user else {
            let unknownError = ShiftProError.unknown("登入後無法取得用戶資訊")
            lastError = unknownError
            promise(.failure(unknownError))
            return
        }

        print("✅ 登入成功: \(user.email ?? "")")
        promise(.success(user))
    }

    // MARK: - 👤 匿名登入

    func signInAnonymously() -> AnyPublisher<User, Error> {
        isLoading = true
        clearError()

        return Future<User, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(ShiftProError.unknown("AuthManager unavailable")))
                return
            }

            Auth.auth().signInAnonymously { [weak self] result, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.handleAnonymousSignInResult(result: result, error: error, promise: promise)
                }
            }
        }
        .eraseToAnyPublisher()
    }

    private func handleAnonymousSignInResult(
        result: AuthDataResult?,
        error: Error?,
        promise: @escaping (Result<User, Error>) -> Void
    ) {
        if let error = error {
            let shiftProError = mapAuthError(error)
            lastError = shiftProError
            print("❌ 匿名登入失敗: \(error.localizedDescription)")
            promise(.failure(shiftProError))
            return
        }

        guard let user = result?.user else {
            let unknownError = ShiftProError.unknown("匿名登入後無法取得用戶資訊")
            lastError = unknownError
            promise(.failure(unknownError))
            return
        }

        print("✅ 匿名登入成功")
        promise(.success(user))
    }

    // MARK: - 🔄 密碼重設

    func resetPassword(email: String) -> AnyPublisher<Void, Error> {
        guard isValidEmail(email) else {
            return Fail(error: ShiftProError.validationFailed("電子郵件格式不正確"))
                .eraseToAnyPublisher()
        }

        isLoading = true
        clearError()

        return Future<Void, Error> { [weak self] promise in
            Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
                DispatchQueue.main.async {
                    self?.isLoading = false

                    if let error = error {
                        let shiftProError = self?.mapAuthError(error) ?? ShiftProError.unknown("密碼重設失敗")
                        self?.lastError = shiftProError
                        promise(.failure(shiftProError))
                    } else {
                        print("✅ 密碼重設郵件已發送")
                        promise(.success(()))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - 🔧 輔助方法

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }

    private func isValidPassword(_ password: String) -> Bool {
        return password.count >= 6
    }

    private func clearError() {
        lastError = nil
    }

    private func cleanup() {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
        cancellables.forEach { $0.cancel() }
    }

    /// 將 Firebase Auth 錯誤映射為 ShiftProError
    private func mapAuthError(_ error: Error) -> ShiftProError {
        let nsError = error as NSError

        switch nsError.code {
        case AuthErrorCode.networkError.rawValue:
            return .networkConnection
        case AuthErrorCode.userNotFound.rawValue:
            return .validationFailed("找不到此電子郵件對應的帳號")
        case AuthErrorCode.wrongPassword.rawValue:
            return .validationFailed("密碼錯誤")
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return .validationFailed("此電子郵件已被使用")
        case AuthErrorCode.invalidEmail.rawValue:
            return .validationFailed("電子郵件格式不正確")
        case AuthErrorCode.weakPassword.rawValue:
            return .validationFailed("密碼強度不足，請使用至少6個字符")
        case AuthErrorCode.userDisabled.rawValue:
            return .noPermission
        case AuthErrorCode.tooManyRequests.rawValue:
            return .validationFailed("嘗試次數過多，請稍後再試")
        default:
            return .authenticationFailed
        }
    }

    // MARK: - 📊 狀態查詢

    var isAnonymousUser: Bool {
        return currentUser?.isAnonymous ?? false
    }

    var currentUserEmail: String? {
        return currentUser?.email
    }

    var currentUserDisplayName: String? {
        return currentUser?.displayName
    }

    var currentUserId: String? {
        return currentUser?.uid
    }
}
