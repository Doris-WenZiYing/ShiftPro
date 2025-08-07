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

    private init() {}

    // MARK: - 通用 CRUD 操作（保留現有方法）

    /// 取得單一文檔
    func getDocument<T: Decodable>(
        collection: String,
        document: String,
        as type: T.Type
    ) -> AnyPublisher<T?, Error> {
        return Future<T?, Error> { promise in
            self.firestore.collection(collection).document(document).getDocument { snapshot, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }

                guard let snapshot = snapshot,
                      snapshot.exists else {
                    promise(.success(nil))
                    return
                }

                do {
                    let decoder = Firestore.Decoder()
                    let decodedObject = try decoder.decode(type, from: snapshot.data() ?? [:])
                    promise(.success(decodedObject))
                } catch {
                    print("❌ Firebase 解碼錯誤: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    /// 設定文檔資料
    func setData(
        collection: String,
        document: String,
        data: [String: Any]
    ) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            print("📤 準備寫入 Firebase: \(collection)/\(document)")
            print("📦 資料內容: \(data)")

            self.firestore.collection(collection).document(document).setData(data) { error in
                if let error = error {
                    print("❌ Firebase 寫入失敗: \(error)")
                    promise(.failure(error))
                } else {
                    print("✅ Firebase 寫入成功: \(collection)/\(document)")
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    /// 更新文檔資料
    func updateData(
        collection: String,
        document: String,
        data: [String: Any]
    ) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            print("🔄 準備更新 Firebase: \(collection)/\(document)")
            print("📦 更新資料: \(data)")

            self.firestore.collection(collection).document(document).updateData(data) { error in
                if let error = error {
                    print("❌ Firebase 更新失敗: \(error)")
                    promise(.failure(error))
                } else {
                    print("✅ Firebase 更新成功: \(collection)/\(document)")
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    /// 刪除文檔
    func deleteDocument(
        collection: String,
        document: String
    ) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            print("🗑️ 準備刪除 Firebase 文檔: \(collection)/\(document)")

            self.firestore.collection(collection).document(document).delete { error in
                if let error = error {
                    print("❌ Firebase 刪除失敗: \(error)")
                    promise(.failure(error))
                } else {
                    print("✅ Firebase 刪除成功: \(collection)/\(document)")
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - 🔥 新增：合併 ScheduleService 的功能

    /// 更新休假規則
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
            "monthlyLimit": monthlyLimit as Any,
            "weeklyLimit": weeklyLimit as Any,
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

    /// 取得休假規則
    func fetchVacationRule(orgId: String, month: String) -> AnyPublisher<FirestoreVacationRule?, Error> {
        let docId = "\(orgId)_\(month)"
        return getDocument(
            collection: "vacation_rules",
            document: docId,
            as: FirestoreVacationRule.self
        )
    }

    /// 刪除休假規則
    func deleteVacationRule(orgId: String, month: String) -> AnyPublisher<Void, Error> {
        let docId = "\(orgId)_\(month)"
        return deleteDocument(
            collection: "vacation_rules",
            document: docId
        )
    }

    /// 更新員工排班
    func updateEmployeeSchedule(
        orgId: String? = nil,
        employeeId: String? = nil,
        month: String,
        dates: [Date]
    ) -> AnyPublisher<Void, Error> {
        let actualEmployeeId = employeeId ?? Auth.auth().currentUser?.uid
        let actualOrgId = orgId ?? UserDefaults.standard.string(forKey: "orgId") ?? "demo_store_01"

        guard let empId = actualEmployeeId else {
            return Fail(error: NSError(
                domain: "ScheduleService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "未登入或未提供員工ID"]
            ))
            .eraseToAnyPublisher()
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

        return setData(
            collection: "employee_schedules",
            document: docId,
            data: payload
        )
    }

    /// 提交員工排班
    func submitEmployeeSchedule(
        orgId: String? = nil,
        employeeId: String? = nil,
        month: String
    ) -> AnyPublisher<Void, Error> {
        let actualEmployeeId = employeeId ?? Auth.auth().currentUser?.uid
        let actualOrgId = orgId ?? UserDefaults.standard.string(forKey: "orgId") ?? "demo_store_01"

        guard let empId = actualEmployeeId else {
            return Fail(error: NSError(
                domain: "ScheduleService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "未登入或未提供員工ID"]
            ))
            .eraseToAnyPublisher()
        }

        let docId = "\(actualOrgId)_\(empId)_\(month)"
        let payload: [String: Any] = [
            "isSubmitted": true,
            "updatedAt": Date()
        ]

        return updateData(
            collection: "employee_schedules",
            document: docId,
            data: payload
        )
    }

    /// 取得員工排班資料
    func fetchEmployeeSchedule(
        orgId: String? = nil,
        employeeId: String? = nil,
        month: String
    ) -> AnyPublisher<FirestoreEmployeeSchedule?, Error> {
        let actualEmployeeId = employeeId ?? Auth.auth().currentUser?.uid
        let actualOrgId = orgId ?? UserDefaults.standard.string(forKey: "orgId") ?? "demo_store_01"

        guard let empId = actualEmployeeId else {
            return Fail(error: NSError(
                domain: "ScheduleService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "未登入或未提供員工ID"]
            ))
            .eraseToAnyPublisher()
        }

        let docId = "\(actualOrgId)_\(empId)_\(month)"

        return getDocument(
            collection: "employee_schedules",
            document: docId,
            as: FirestoreEmployeeSchedule.self
        )
    }

    /// 監聽員工排班變化
    func observeEmployeeSchedule(
        orgId: String? = nil,
        employeeId: String? = nil,
        month: String
    ) -> AnyPublisher<FirestoreEmployeeSchedule?, Error> {
        let actualEmployeeId = employeeId ?? Auth.auth().currentUser?.uid
        let actualOrgId = orgId ?? UserDefaults.standard.string(forKey: "orgId") ?? "demo_store_01"

        guard let empId = actualEmployeeId else {
            return Fail(error: NSError(
                domain: "ScheduleService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "未登入或未提供員工ID"]
            ))
            .eraseToAnyPublisher()
        }

        let docId = "\(actualOrgId)_\(empId)_\(month)"

        return documentPublisher(
            collection: "employee_schedules",
            document: docId,
            as: FirestoreEmployeeSchedule.self
        )
    }

    /// 監聽單一文檔變化 (實時更新)
    func documentPublisher<T: Decodable>(
        collection: String,
        document: String,
        as type: T.Type
    ) -> AnyPublisher<T?, Error> {
        let docRef = firestore.collection(collection).document(document)

        return Future<T?, Error> { promise in
            docRef.addSnapshotListener { snapshot, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }

                guard let snapshot = snapshot,
                      snapshot.exists else {
                    promise(.success(nil))
                    return
                }

                do {
                    let decoder = Firestore.Decoder()
                    let decodedObject = try decoder.decode(type, from: snapshot.data() ?? [:])
                    promise(.success(decodedObject))
                } catch {
                    print("❌ Firebase 實時監聽解碼錯誤: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - 🔥 新增：合併 OrganizationService 的功能

    /// 新增或更新組織
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

    /// 取得組織資料
    func fetchOrganization(orgId: String) -> AnyPublisher<FirestoreOrganization?, Error> {
        return getDocument(
            collection: "organizations",
            document: orgId,
            as: FirestoreOrganization.self
        )
    }

    // MARK: - 🔥 新增：合併 EmployeeService 的功能

    /// 新增或更新員工
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

    /// 取得員工資料
    func fetchEmployee(orgId: String, employeeId: String) -> AnyPublisher<FirestoreEmployee?, Error> {
        let docId = "\(orgId)_\(employeeId)"
        return getDocument(
            collection: "employees",
            document: docId,
            as: FirestoreEmployee.self
        )
    }
}
