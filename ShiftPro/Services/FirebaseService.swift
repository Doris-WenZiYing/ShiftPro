//
//  FirebaseService.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/17.
//

import FirebaseFirestore
import Combine
import FirebaseAuth

final class FirebaseService {
    static let shared = FirebaseService()
    let firestore = Firestore.firestore()

    private init() {
        configureFirestore()
    }

    // MARK: - 🔧 基本配置
    private func configureFirestore() {
        let settings = FirestoreSettings()
        settings.cacheSettings = MemoryCacheSettings()
        firestore.settings = settings

        // 基本網路監聽
        setupNetworkMonitoring()
    }

    private func setupNetworkMonitoring() {
        // 簡單的網路狀態監聽
        firestore.enableNetwork { [weak self] error in
            if let error = error {
                print("❌ Firebase 網路連線失敗: \(error)")
                ErrorHandler.shared.handle(ShiftProError.networkConnection)
            } else {
                print("✅ Firebase 網路連線正常")
            }
        }
    }

    // MARK: - 🛡️ 安全的通用 CRUD 操作

    /// 取得單一文檔（帶錯誤處理）
    func getDocument<T: Decodable>(
        collection: String,
        document: String,
        as type: T.Type
    ) -> AnyPublisher<T?, Error> {
        return Future<T?, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(ShiftProError.unknown("Service unavailable")))
                return
            }

            self.firestore.collection(collection).document(document).getDocument { snapshot, error in
                if let error = error {
                    print("❌ Firebase 讀取失敗 [\(collection)/\(document)]: \(error)")
                    promise(.failure(self.mapFirebaseError(error)))
                    return
                }

                guard let snapshot = snapshot else {
                    promise(.failure(ShiftProError.dataNotFound))
                    return
                }

                if !snapshot.exists {
                    promise(.success(nil))
                    return
                }

                do {
                    let decoder = Firestore.Decoder()
                    var data = snapshot.data() ?? [:]

                    // 確保 ID 存在於數據中
                    if !data.keys.contains("id") {
                        data["id"] = document
                    }

                    let decodedObject = try decoder.decode(type, from: data)
                    promise(.success(decodedObject))
                } catch {
                    print("❌ Firebase 解碼錯誤 [\(collection)/\(document)]: \(error)")
                    promise(.failure(ShiftProError.invalidData))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    /// 設定文檔資料（帶錯誤處理）
    func setData(
        collection: String,
        document: String,
        data: [String: Any]
    ) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(ShiftProError.unknown("Service unavailable")))
                return
            }

            print("📤 Firebase 寫入: \(collection)/\(document)")

            // 添加基本元數據
            var enrichedData = data
            enrichedData["lastModified"] = FieldValue.serverTimestamp()

            self.firestore.collection(collection).document(document).setData(enrichedData) { error in
                if let error = error {
                    print("❌ Firebase 寫入失敗 [\(collection)/\(document)]: \(error)")
                    promise(.failure(self.mapFirebaseError(error)))
                } else {
                    print("✅ Firebase 寫入成功: \(collection)/\(document)")
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    /// 更新文檔資料（帶錯誤處理）
    func updateData(
        collection: String,
        document: String,
        data: [String: Any]
    ) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(ShiftProError.unknown("Service unavailable")))
                return
            }

            print("🔄 Firebase 更新: \(collection)/\(document)")

            // 添加更新時間戳
            var enrichedData = data
            enrichedData["lastModified"] = FieldValue.serverTimestamp()

            self.firestore.collection(collection).document(document).updateData(enrichedData) { error in
                if let error = error {
                    print("❌ Firebase 更新失敗 [\(collection)/\(document)]: \(error)")
                    promise(.failure(self.mapFirebaseError(error)))
                } else {
                    print("✅ Firebase 更新成功: \(collection)/\(document)")
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    /// 刪除文檔（帶錯誤處理）
    func deleteDocument(
        collection: String,
        document: String
    ) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(ShiftProError.unknown("Service unavailable")))
                return
            }

            print("🗑️ Firebase 刪除: \(collection)/\(document)")

            self.firestore.collection(collection).document(document).delete { error in
                if let error = error {
                    print("❌ Firebase 刪除失敗 [\(collection)/\(document)]: \(error)")
                    promise(.failure(self.mapFirebaseError(error)))
                } else {
                    print("✅ Firebase 刪除成功: \(collection)/\(document)")
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - 🎯 專業功能方法（穩定版）

    /// 更新休假規則（穩定版）
    func updateVacationRule(
        orgId: String,
        month: String,
        type: String,
        monthlyLimit: Int? = nil,
        weeklyLimit: Int? = nil,
        published: Bool = false
    ) -> AnyPublisher<Void, Error> {
        let docId = "\(orgId)_\(month)"
        let now = Date()

        let payload: [String: Any] = [
            "orgId": orgId,
            "month": month,
            "type": type,
            "monthlyLimit": monthlyLimit ?? NSNull(),
            "weeklyLimit": weeklyLimit ?? NSNull(),
            "published": published,
            "createdAt": now,
            "updatedAt": now
        ]

        return setData(
            collection: "vacation_rules",
            document: docId,
            data: payload
        )
    }

    /// 取得休假規則（穩定版）
    func fetchVacationRule(orgId: String, month: String) -> AnyPublisher<FirestoreVacationRule?, Error> {
        let docId = "\(orgId)_\(month)"
        return getDocument(
            collection: "vacation_rules",
            document: docId,
            as: FirestoreVacationRule.self
        )
    }

    /// 刪除休假規則（穩定版）
    func deleteVacationRule(orgId: String, month: String) -> AnyPublisher<Void, Error> {
        let docId = "\(orgId)_\(month)"
        return deleteDocument(
            collection: "vacation_rules",
            document: docId
        )
    }

    /// 更新員工排班（穩定版）
    func updateEmployeeSchedule(
        orgId: String? = nil,
        employeeId: String? = nil,
        month: String,
        dates: [Date]
    ) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(ShiftProError.unknown("Service unavailable")))
                return
            }

            let actualEmployeeId = employeeId ?? Auth.auth().currentUser?.uid
            let actualOrgId = orgId ?? self.getDefaultOrgId()

            guard let empId = actualEmployeeId else {
                promise(.failure(ShiftProError.authenticationFailed))
                return
            }

            let docId = "\(actualOrgId)_\(empId)_\(month)"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateStrings = dates.map { dateFormatter.string(from: $0) }
            let now = Date()

            let payload: [String: Any] = [
                "orgId": actualOrgId,
                "employeeId": empId,
                "month": month,
                "selectedDates": dateStrings,
                "isSubmitted": false,
                "createdAt": now,
                "updatedAt": now
            ]

            self.setData(
                collection: "employee_schedules",
                document: docId,
                data: payload
            )
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        promise(.failure(error))
                    case .finished:
                        break
                    }
                },
                receiveValue: { _ in
                    promise(.success(()))
                }
            )
            .store(in: &self.cancellables)
        }
        .eraseToAnyPublisher()
    }

    /// 提交員工排班（穩定版）
    func submitEmployeeSchedule(
        orgId: String? = nil,
        employeeId: String? = nil,
        month: String
    ) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(ShiftProError.unknown("Service unavailable")))
                return
            }

            let actualEmployeeId = employeeId ?? Auth.auth().currentUser?.uid
            let actualOrgId = orgId ?? self.getDefaultOrgId()

            guard let empId = actualEmployeeId else {
                promise(.failure(ShiftProError.authenticationFailed))
                return
            }

            let docId = "\(actualOrgId)_\(empId)_\(month)"
            let payload: [String: Any] = [
                "isSubmitted": true,
                "updatedAt": Date()
            ]

            self.updateData(
                collection: "employee_schedules",
                document: docId,
                data: payload
            )
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        promise(.failure(error))
                    case .finished:
                        break
                    }
                },
                receiveValue: { _ in
                    promise(.success(()))
                }
            )
            .store(in: &self.cancellables)
        }
        .eraseToAnyPublisher()
    }

    /// 取得員工排班資料（穩定版）
    func fetchEmployeeSchedule(
        orgId: String? = nil,
        employeeId: String? = nil,
        month: String
    ) -> AnyPublisher<FirestoreEmployeeSchedule?, Error> {
        let actualEmployeeId = employeeId ?? Auth.auth().currentUser?.uid
        let actualOrgId = orgId ?? getDefaultOrgId()

        guard let empId = actualEmployeeId else {
            return Fail(error: ShiftProError.authenticationFailed)
                .eraseToAnyPublisher()
        }

        let docId = "\(actualOrgId)_\(empId)_\(month)"

        return getDocument(
            collection: "employee_schedules",
            document: docId,
            as: FirestoreEmployeeSchedule.self
        )
    }

    /// 監聽員工排班變化（穩定版）
    func observeEmployeeSchedule(
        orgId: String? = nil,
        employeeId: String? = nil,
        month: String
    ) -> AnyPublisher<FirestoreEmployeeSchedule?, Error> {
        let actualEmployeeId = employeeId ?? Auth.auth().currentUser?.uid
        let actualOrgId = orgId ?? getDefaultOrgId()

        guard let empId = actualEmployeeId else {
            return Fail(error: ShiftProError.authenticationFailed)
                .eraseToAnyPublisher()
        }

        let docId = "\(actualOrgId)_\(empId)_\(month)"

        return documentPublisher(
            collection: "employee_schedules",
            document: docId,
            as: FirestoreEmployeeSchedule.self
        )
    }

    /// 監聽單一文檔變化（穩定版）
    func documentPublisher<T: Decodable>(
        collection: String,
        document: String,
        as type: T.Type
    ) -> AnyPublisher<T?, Error> {
        return Future<T?, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(ShiftProError.unknown("Service unavailable")))
                return
            }

            let docRef = self.firestore.collection(collection).document(document)

            let listener = docRef.addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Firebase 實時監聽錯誤 [\(collection)/\(document)]: \(error)")
                    promise(.failure(self.mapFirebaseError(error)))
                    return
                }

                guard let snapshot = snapshot else {
                    promise(.failure(ShiftProError.dataNotFound))
                    return
                }

                if !snapshot.exists {
                    promise(.success(nil))
                    return
                }

                do {
                    let decoder = Firestore.Decoder()
                    var data = snapshot.data() ?? [:]

                    // 確保 ID 存在於數據中
                    if !data.keys.contains("id") {
                        data["id"] = document
                    }

                    let decodedObject = try decoder.decode(type, from: data)
                    promise(.success(decodedObject))
                } catch {
                    print("❌ Firebase 實時監聽解碼錯誤 [\(collection)/\(document)]: \(error)")
                    promise(.failure(ShiftProError.invalidData))
                }
            }

            // 存儲監聽器以便後續清理
            self.activeListeners["\(collection)_\(document)"] = listener
        }
        .eraseToAnyPublisher()
    }

    // MARK: - 🔧 輔助方法

    private func getDefaultOrgId() -> String {
        return UserDefaults.standard.string(forKey: "orgId") ?? "demo_store_01"
    }

    private func mapFirebaseError(_ error: Error) -> ShiftProError {
        let nsError = error as NSError

        switch nsError.code {
        case -1009, -1001: // Network errors
            return .networkConnection
        case 7: // Permission denied
            return .noPermission
        case 5: // Not found
            return .dataNotFound
        case 16: // Unauthenticated
            return .authenticationFailed
        default:
            return .firebaseError(error.localizedDescription)
        }
    }

    // MARK: - 🧹 資源清理

    private var activeListeners: [String: ListenerRegistration] = [:]
    private var cancellables = Set<AnyCancellable>()

    func removeListener(for key: String) {
        activeListeners[key]?.remove()
        activeListeners.removeValue(forKey: key)
        print("🔇 移除監聽器: \(key)")
    }

    func removeAllListeners() {
        activeListeners.values.forEach { $0.remove() }
        activeListeners.removeAll()
        print("🔇 移除所有監聽器")
    }

    deinit {
        removeAllListeners()
        cancellables.forEach { $0.cancel() }
    }

    // MARK: - 🏢 組織相關方法

    /// 新增或更新組織（穩定版）
    func addOrUpdateOrganization(
        orgId: String,
        name: String,
        settings: [String: String]? = nil
    ) -> AnyPublisher<Void, Error> {
        let now = Date()

        var payload: [String: Any] = [
            "name": name,
            "createdAt": now
        ]

        if let settings = settings {
            payload["settings"] = settings
        }

        return setData(
            collection: "organizations",
            document: orgId,
            data: payload
        )
    }

    /// 取得組織資料（穩定版）
    func fetchOrganization(orgId: String) -> AnyPublisher<FirestoreOrganization?, Error> {
        return getDocument(
            collection: "organizations",
            document: orgId,
            as: FirestoreOrganization.self
        )
    }

    // MARK: - 👥 員工相關方法

    /// 新增或更新員工（穩定版）
    func addOrUpdateEmployee(
        orgId: String,
        employeeId: String,
        name: String,
        role: String
    ) -> AnyPublisher<Void, Error> {
        let docId = "\(orgId)_\(employeeId)"
        let now = Date()

        let payload: [String: Any] = [
            "orgId": orgId,
            "employeeId": employeeId,
            "name": name,
            "role": role,
            "createdAt": now,
            "updatedAt": now
        ]

        return setData(
            collection: "employees",
            document: docId,
            data: payload
        )
    }

    /// 取得員工資料（穩定版）
    func fetchEmployee(orgId: String, employeeId: String) -> AnyPublisher<FirestoreEmployee?, Error> {
        let docId = "\(orgId)_\(employeeId)"
        return getDocument(
            collection: "employees",
            document: docId,
            as: FirestoreEmployee.self
        )
    }
}
