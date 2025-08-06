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

    // MARK: - 創建組織（老闆）
    func createOrganization(name: String, bossUserId: String, bossName: String) -> AnyPublisher<String, Error> {
        isLoading = true

        return Future<String, Error> { promise in
            let orgId = "org_\(Int(Date().timeIntervalSince1970))"
            let inviteCode = self.generateInviteCode()

            let orgData: [String: Any] = [
                "name": name,
                "bossId": bossUserId,
                "bossName": bossName,
                "inviteCode": inviteCode,
                "createdAt": FieldValue.serverTimestamp(),
                "memberCount": 1,
                "settings": [
                    "maxEmployees": 10,
                    "timezone": "Asia/Taipei"
                ]
            ]

            // 1. 創建組織
            self.firebaseService.setData(
                collection: "organizations",
                document: orgId,
                data: orgData
            )
            .flatMap { _ in
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
                        print("✅ 組織創建成功: \(orgId)")
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

        return Future<FirestoreOrganization, Error> { promise in
            // 1. 根據邀請碼查找組織
            Firestore.firestore().collection("organizations")
                .whereField("inviteCode", isEqualTo: inviteCode)
                .getDocuments { snapshot, error in
                    if let error = error {
                        DispatchQueue.main.async {
                            self.isLoading = false
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
                            promise(.failure(OrgError.invalidInviteCode))
                        }
                        return
                    }

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

                                let organization = FirestoreOrganization(
                                    id: orgId,
                                    name: orgData["name"] as? String ?? "",
                                    createdAt: (orgData["createdAt"] as? Timestamp)?.dateValue(),
                                    settings: orgData["settings"] as? [String: String]
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

    // MARK: - 載入用戶組織資訊
    func loadUserOrganization(userId: String) -> AnyPublisher<(FirestoreOrganization?, UserRole), Error> {
        return firebaseService.getDocument(
            collection: "users",
            document: userId,
            as: UserData.self
        )
        .flatMap { userData -> AnyPublisher<(FirestoreOrganization?, UserRole), Error> in
            guard let userData = userData else {
                return Just((nil, .employee))
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }

            let role = UserRole(rawValue: userData.role) ?? .employee

            if let orgId = userData.orgId {
                return self.firebaseService.getDocument(
                    collection: "organizations",
                    document: orgId,
                    as: OrganizationData.self
                )
                .map { orgData in
                    // 🔥 使用 Firebase 模型轉換為應用層模型
                    if let orgData = orgData {
                        let organization = FirestoreOrganization(
                            id: orgId,
                            name: orgData.name,
                            createdAt: orgData.createdAt,
                            settings: orgData.settings
                        )
                        return (organization, role)
                    } else {
                        return (nil, role)
                    }
                }
                .eraseToAnyPublisher()
            } else {
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
            }
        })
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
        return firebaseService.getDocument(
            collection: "organizations",
            document: orgId,
            as: OrganizationData.self
        )
        .map { orgData in
            return orgData?.inviteCode ?? ""
        }
        .eraseToAnyPublisher()
    }
}
