//
//  OrganizationManager.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/8/3.
//

import Foundation
import FirebaseAuth
import Combine
import FirebaseFirestore

class OrganizationManager: ObservableObject {
    static let shared = OrganizationManager()

    @Published var currentOrganization: FirestoreOrganization?
    @Published var userRole: UserRole = .employee
    @Published var isLoading = false

    private let firebaseService = FirebaseService.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    func createOrganization(name: String, bossUserId: String, bossName: String) -> AnyPublisher<String, Error> {
        isLoading = true
        print("🏢 創建組織: \(name)")

        return Future<String, Error> { promise in
            let orgId = "org_\(Int(Date().timeIntervalSince1970))"
            let inviteCode = self.generateInviteCode()

            // 🔥 修復：使用正確的資料結構
            let orgData: [String: Any] = [
                "name": name,
                "bossId": bossUserId,
                "bossName": bossName,
                "inviteCode": inviteCode,
                "createdAt": FieldValue.serverTimestamp(),
                "memberCount": 1,
                "settings": [
                    "maxEmployees": 10,  // 🔥 修復：直接使用數字
                    "timezone": "Asia/Taipei",
                    "currency": "TWD",
                    "workDays": "1,2,3,4,5"
                ]
            ]

            print("📝 組織資料: \(orgData)")

            // 1. 創建組織
            self.firebaseService.setData(
                collection: "organizations",
                document: orgId,
                data: orgData
            )
            .flatMap { _ in
                print("✅ 組織創建成功，創建老闆用戶記錄")
                // 2. 創建老闆的用戶記錄
                let bossData: [String: Any] = [
                    "userId": bossUserId,
                    "email": Auth.auth().currentUser?.email ?? "",
                    "displayName": bossName,
                    "role": UserRole.boss.rawValue,
                    "orgId": orgId,
                    "orgName": name,
                    "joinedAt": FieldValue.serverTimestamp()
                ]

                return self.firebaseService.setData(
                    collection: "users",
                    document: bossUserId,
                    data: bossData
                )
            }
            .sink(
                receiveCompletion: { completion in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        switch completion {
                        case .failure(let error):
                            print("❌ 創建組織失敗: \(error)")
                            promise(.failure(error))
                        case .finished:
                            break
                        }
                    }
                },
                receiveValue: { _ in
                    DispatchQueue.main.async {
                        print("✅ 組織創建完成: \(orgId), 邀請碼: \(inviteCode)")
                        promise(.success(inviteCode))
                    }
                }
            )
            .store(in: &self.cancellables)
        }
        .eraseToAnyPublisher()
    }

    // MARK: - 加入組織（員工）
    func joinOrganization(inviteCode: String, employeeUserId: String, employeeName: String) -> AnyPublisher<FirestoreOrganization, Error> {
        isLoading = true
        print("🚪 加入組織: \(inviteCode)")

        return Future<FirestoreOrganization, Error> { promise in
            // 1. 根據邀請碼查找組織
            Firestore.firestore().collection("organizations")
                .whereField("inviteCode", isEqualTo: inviteCode)
                .getDocuments { snapshot, error in
                    if let error = error {
                        DispatchQueue.main.async {
                            self.isLoading = false
                            print("❌ 查找組織失敗: \(error)")
                            promise(.failure(error))
                        }
                        return
                    }

                    guard let documents = snapshot?.documents,
                          !documents.isEmpty,
                          let orgData = documents.first?.data(),
                          let orgId = documents.first?.documentID else {
                        DispatchQueue.main.async {
                            self.isLoading = false
                            print("❌ 無效的邀請碼: \(inviteCode)")
                            promise(.failure(OrgError.invalidInviteCode))
                        }
                        return
                    }

                    print("✅ 找到組織: \(orgId)")

                    // 2. 創建員工記錄
                    let employeeData: [String: Any] = [
                        "userId": employeeUserId,
                        "email": Auth.auth().currentUser?.email ?? "",
                        "displayName": employeeName,
                        "role": UserRole.employee.rawValue,
                        "orgId": orgId,
                        "orgName": orgData["name"] as? String ?? "",
                        "joinedAt": FieldValue.serverTimestamp()
                    ]

                    self.firebaseService.setData(
                        collection: "users",
                        document: employeeUserId,
                        data: employeeData
                    )
                    .sink(
                        receiveCompletion: { completion in
                            DispatchQueue.main.async {
                                self.isLoading = false
                                switch completion {
                                case .failure(let error):
                                    print("❌ 加入組織失敗: \(error)")
                                    promise(.failure(error))
                                case .finished:
                                    break
                                }
                            }
                        },
                        receiveValue: { _ in
                            DispatchQueue.main.async {
                                // 3. 更新組織成員數量
                                Firestore.firestore().collection("organizations").document(orgId)
                                    .updateData(["memberCount": FieldValue.increment(Int64(1))])

                                // 🔥 修復：創建正確的組織物件
                                let organization = FirestoreOrganization(
                                    id: orgId,
                                    name: orgData["name"] as? String ?? "",
                                    createdAt: (orgData["createdAt"] as? Timestamp)?.dateValue(),
                                    settings: nil  // 這裡可以為空，後續會載入
                                )

                                print("✅ 加入組織成功: \(orgId)")
                                promise(.success(organization))
                            }
                        }
                    )
                    .store(in: &self.cancellables)
                }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - 載入用戶組織資訊 - 🔥 修復解碼問題
    func loadUserOrganization(userId: String) -> AnyPublisher<(FirestoreOrganization?, UserRole), Error> {
        print("📱 載入用戶組織資訊: \(userId)")

        return firebaseService.getDocument(
            collection: "users",
            document: userId,
            as: UserData.self
        )
        .flatMap { userData -> AnyPublisher<(FirestoreOrganization?, UserRole), Error> in
            guard let userData = userData else {
                print("⚠️ 找不到用戶資料: \(userId)")
                return Just((nil, .employee))
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }

            let role = UserRole(rawValue: userData.role) ?? .employee
            print("📊 用戶角色: \(role), 組織ID: \(userData.orgId ?? "nil")")

            if let orgId = userData.orgId, !orgId.isEmpty {
                return self.loadOrganizationData(orgId: orgId)
                    .map { organization in
                        return (organization, role)
                    }
                    .eraseToAnyPublisher()
            } else {
                print("⚠️ 用戶沒有組織ID")
                return Just((nil, role))
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
        }
        .receive(on: DispatchQueue.main)
        .handleEvents(receiveOutput: { [weak self] (org, role) in
            self?.currentOrganization = org
            self?.userRole = role
            if let org = org {
                print("✅ 載入組織成功: \(org.name)")
            } else {
                print("⚠️ 沒有組織資料")
            }
        })
        .eraseToAnyPublisher()
    }

    // 🔥 新增：專門載入組織資料的方法，處理解碼問題
    private func loadOrganizationData(orgId: String) -> AnyPublisher<FirestoreOrganization?, Error> {
        return Future<FirestoreOrganization?, Error> { promise in
            Firestore.firestore().collection("organizations").document(orgId)
                .getDocument { snapshot, error in
                    if let error = error {
                        print("❌ 載入組織資料失敗: \(error)")
                        promise(.failure(error))
                        return
                    }

                    guard let snapshot = snapshot, snapshot.exists,
                          let data = snapshot.data() else {
                        print("⚠️ 組織不存在: \(orgId)")
                        promise(.success(nil))
                        return
                    }

                    do {
                        // 🔥 手動解析，避免解碼錯誤
                        let name = data["name"] as? String ?? ""
                        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()

                        // 🔥 安全處理 settings
                        var settings: [String: String]? = nil
                        if let settingsData = data["settings"] as? [String: Any] {
                            var settingsDict: [String: String] = [:]

                            // 安全轉換每個設定值
                            for (key, value) in settingsData {
                                if let stringValue = value as? String {
                                    settingsDict[key] = stringValue
                                } else if let intValue = value as? Int {
                                    settingsDict[key] = String(intValue)
                                } else if let doubleValue = value as? Double {
                                    settingsDict[key] = String(Int(doubleValue))
                                } else {
                                    settingsDict[key] = String(describing: value)
                                }
                            }
                            settings = settingsDict
                        }

                        let organization = FirestoreOrganization(
                            id: orgId,
                            name: name,
                            createdAt: createdAt,
                            settings: settings
                        )

                        print("✅ 組織資料解析成功: \(name)")
                        promise(.success(organization))
                    } catch {
                        print("❌ 組織資料解析失敗: \(error)")
                        promise(.failure(OrgError.dataDecodingError(error.localizedDescription)))
                    }
                }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - 生成邀請碼
    private func generateInviteCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let length = 8
        return String((0..<length).map { _ in characters.randomElement()! })
    }

    // MARK: - 獲取組織邀請碼（老闆專用）
    func getOrganizationInviteCode(orgId: String) -> AnyPublisher<String, Error> {
        print("🔑 獲取組織邀請碼: \(orgId)")

        return Future<String, Error> { promise in
            Firestore.firestore().collection("organizations").document(orgId)
                .getDocument { snapshot, error in
                    if let error = error {
                        print("❌ 獲取邀請碼失敗: \(error)")
                        promise(.failure(error))
                        return
                    }

                    guard let data = snapshot?.data(),
                          let inviteCode = data["inviteCode"] as? String else {
                        print("❌ 找不到邀請碼")
                        promise(.failure(OrgError.organizationNotFound))
                        return
                    }

                    print("✅ 獲取邀請碼成功: \(inviteCode)")
                    promise(.success(inviteCode))
                }
        }
        .eraseToAnyPublisher()
    }
}
