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

    private var cancellables = Set<AnyCancellable>()

    init() {
        // 監聽 Firebase Auth 狀態變化
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                print("🔐 Auth 狀態變化: \(user?.email ?? "未登入")")
            }
        }
    }

    // MARK: - 註冊
    func signUp(email: String, password: String, displayName: String) -> AnyPublisher<User, Error> {
        isLoading = true

        return Future<User, Error> { promise in
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error = error {
                        print("❌ 註冊失敗: \(error.localizedDescription)")
                        promise(.failure(error))
                        return
                    }

                    guard let user = result?.user else {
                        promise(.failure(AuthError.unknownError))
                        return
                    }

                    // 更新顯示名稱
                    let changeRequest = user.createProfileChangeRequest()
                    changeRequest.displayName = displayName
                    changeRequest.commitChanges { error in
                        if let error = error {
                            print("⚠️ 更新顯示名稱失敗: \(error)")
                        }
                    }

                    print("✅ 註冊成功: \(user.email ?? "")")
                    promise(.success(user))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - 登入
    func signIn(email: String, password: String) -> AnyPublisher<User, Error> {
        isLoading = true

        return Future<User, Error> { promise in
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error = error {
                        print("❌ 登入失敗: \(error.localizedDescription)")
                        promise(.failure(error))
                        return
                    }

                    guard let user = result?.user else {
                        promise(.failure(AuthError.unknownError))
                        return
                    }

                    print("✅ 登入成功: \(user.email ?? "")")
                    promise(.success(user))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - 登出
    func signOut() -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            do {
                try Auth.auth().signOut()
                print("✅ 登出成功")
                promise(.success(()))
            } catch {
                print("❌ 登出失敗: \(error)")
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - 匿名登入（訪客模式）
    func signInAnonymously() -> AnyPublisher<User, Error> {
        isLoading = true

        return Future<User, Error> { promise in
            Auth.auth().signInAnonymously { result, error in
                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error = error {
                        promise(.failure(error))
                        return
                    }

                    guard let user = result?.user else {
                        promise(.failure(AuthError.unknownError))
                        return
                    }

                    print("✅ 匿名登入成功")
                    promise(.success(user))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - 錯誤類型
enum AuthError: Error, LocalizedError {
    case unknownError
    case userNotFound
    case invalidCredentials

    var errorDescription: String? {
        switch self {
        case .unknownError:
            return "未知錯誤"
        case .userNotFound:
            return "用戶不存在"
        case .invalidCredentials:
            return "登入資訊錯誤"
        }
    }
}
