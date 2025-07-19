////
////  FirebaseManager.swift
////  ShiftPro
////
////  Created by Doris Wen on 2025/7/17.
////
//
//import Foundation
//import Firebase
//import FirebaseFirestore
//
//// MARK: - Firebase 錯誤類型
//enum FirebaseError: Error, LocalizedError {
//    case documentNotFound
//    case encodingError
//    case decodingError
//    case networkError
//    case unknownError(String)
//
//    var errorDescription: String? {
//        switch self {
//        case .documentNotFound:
//            return "文檔不存在"
//        case .encodingError:
//            return "數據編碼錯誤"
//        case .decodingError:
//            return "數據解碼錯誤"
//        case .networkError:
//            return "網絡連接錯誤"
//        case .unknownError(let message):
//            return "未知錯誤: \(message)"
//        }
//    }
//}
//
//// MARK: - Firebase Manager
//class FirebaseManager: ObservableObject {
//
//    static let shared = FirebaseManager()
//    private let db = Firestore.firestore()
//
//    private init() {
//        print("🔥 FirebaseManager 初始化")
//    }
//
//    // MARK: - 通用 CRUD 操作
//
//    /// 寫入文檔
//    func setDocument<T: Codable>(
//        collection: String,
//        documentId: String,
//        data: T,
//        completion: @escaping (Result<Void, FirebaseError>) -> Void
//    ) {
//        do {
//            let encodedData = try Firestore.Encoder().encode(data)
//
//            db.collection(collection)
//                .document(documentId)
//                .setData(encodedData) { error in
//                    if let error = error {
//                        print("❌ 寫入失敗: \(error.localizedDescription)")
//                        completion(.failure(.unknownError(error.localizedDescription)))
//                    } else {
//                        print("✅ 寫入成功: \(collection)/\(documentId)")
//                        completion(.success(()))
//                    }
//                }
//        } catch {
//            print("❌ 編碼失敗: \(error)")
//            completion(.failure(.encodingError))
//        }
//    }
//
//    /// 讀取文檔
//    func getDocument<T: Codable>(
//        collection: String,
//        documentId: String,
//        type: T.Type,
//        completion: @escaping (Result<T, FirebaseError>) -> Void
//    ) {
//        db.collection(collection)
//            .document(documentId)
//            .getDocument { document, error in
//                if let error = error {
//                    print("❌ 讀取失敗: \(error.localizedDescription)")
//                    completion(.failure(.networkError))
//                    return
//                }
//
//                guard let document = document,
//                      document.exists,
//                      let data = document.data() else {
//                    print("❌ 文檔不存在: \(collection)/\(documentId)")
//                    completion(.failure(.documentNotFound))
//                    return
//                }
//
//                do {
//                    let decodedData = try Firestore.Decoder().decode(type, from: data)
//                    print("✅ 讀取成功: \(collection)/\(documentId)")
//                    completion(.success(decodedData))
//                } catch {
//                    print("❌ 解碼失敗: \(error)")
//                    completion(.failure(.decodingError))
//                }
//            }
//    }
//
//    /// 更新文檔
//    func updateDocument<T: Codable>(
//        collection: String,
//        documentId: String,
//        data: T,
//        completion: @escaping (Result<Void, FirebaseError>) -> Void
//    ) {
//        do {
//            let encodedData = try Firestore.Encoder().encode(data)
//
//            db.collection(collection)
//                .document(documentId)
//                .updateData(encodedData) { error in
//                    if let error = error {
//                        print("❌ 更新失敗: \(error.localizedDescription)")
//                        completion(.failure(.unknownError(error.localizedDescription)))
//                    } else {
//                        print("✅ 更新成功: \(collection)/\(documentId)")
//                        completion(.success(()))
//                    }
//                }
//        } catch {
//            print("❌ 編碼失敗: \(error)")
//            completion(.failure(.encodingError))
//        }
//    }
//
//    /// 刪除文檔
//    func deleteDocument(
//        collection: String,
//        documentId: String,
//        completion: @escaping (Result<Void, FirebaseError>) -> Void
//    ) {
//        db.collection(collection)
//            .document(documentId)
//            .delete { error in
//                if let error = error {
//                    print("❌ 刪除失敗: \(error.localizedDescription)")
//                    completion(.failure(.unknownError(error.localizedDescription)))
//                } else {
//                    print("✅ 刪除成功: \(collection)/\(documentId)")
//                    completion(.success(()))
//                }
//            }
//    }
//
//    /// 查詢集合
//    func getCollection<T: Codable>(
//        collection: String,
//        type: T.Type,
//        completion: @escaping (Result<[T], FirebaseError>) -> Void
//    ) {
//        db.collection(collection)
//            .getDocuments { querySnapshot, error in
//                if let error = error {
//                    print("❌ 查詢失敗: \(error.localizedDescription)")
//                    completion(.failure(.networkError))
//                    return
//                }
//
//                guard let documents = querySnapshot?.documents else {
//                    completion(.success([]))
//                    return
//                }
//
//                let results: [T] = documents.compactMap { document in
//                    do {
//                        let decodedData = try Firestore.Decoder().decode(type, from: document.data())
//                        return decodedData
//                    } catch {
//                        print("❌ 解碼失敗: \(error)")
//                        return nil
//                    }
//                }
//
//                print("✅ 查詢成功: \(collection) - \(results.count) 個文檔")
//                completion(.success(results))
//            }
//    }
//
//    /// 即時監聽文檔變化
//    func listenToDocument<T: Codable>(
//        collection: String,
//        documentId: String,
//        type: T.Type,
//        completion: @escaping (Result<T, FirebaseError>) -> Void
//    ) -> ListenerRegistration {
//        return db.collection(collection)
//            .document(documentId)
//            .addSnapshotListener { document, error in
//                if let error = error {
//                    print("❌ 監聽失敗: \(error.localizedDescription)")
//                    completion(.failure(.networkError))
//                    return
//                }
//
//                guard let document = document,
//                      document.exists,
//                      let data = document.data() else {
//                    print("❌ 文檔不存在: \(collection)/\(documentId)")
//                    completion(.failure(.documentNotFound))
//                    return
//                }
//
//                do {
//                    let decodedData = try Firestore.Decoder().decode(type, from: data)
//                    print("📱 即時更新: \(collection)/\(documentId)")
//                    completion(.success(decodedData))
//                } catch {
//                    print("❌ 解碼失敗: \(error)")
//                    completion(.failure(.decodingError))
//                }
//            }
//    }
//}
//
//// MARK: - 排班系統專用擴展
//extension FirebaseManager {
//
//    // MARK: - 休假規則操作
//
//    /// 保存休假規則
//    func saveVacationRule(
//        orgId: String,
//        month: String,
//        rule: VacationRuleFirebase,
//        completion: @escaping (Result<Void, FirebaseError>) -> Void
//    ) {
//        let documentId = "\(orgId)_\(month)"
//        setDocument(
//            collection: "vacation_rules",
//            documentId: documentId,
//            data: rule,
//            completion: completion
//        )
//    }
//
//    /// 獲取休假規則
//    func getVacationRule(
//        orgId: String,
//        month: String,
//        completion: @escaping (Result<VacationRuleFirebase, FirebaseError>) -> Void
//    ) {
//        let documentId = "\(orgId)_\(month)"
//        getDocument(
//            collection: "vacation_rules",
//            documentId: documentId,
//            type: VacationRuleFirebase.self,
//            completion: completion
//        )
//    }
//
//    /// 獲取組織的所有休假規則
//    func getVacationRules(
//        orgId: String,
//        completion: @escaping (Result<[VacationRuleFirebase], FirebaseError>) -> Void
//    ) {
//        db.collection("vacation_rules")
//            .whereField("orgId", isEqualTo: orgId)
//            .getDocuments { querySnapshot, error in
//                if let error = error {
//                    print("❌ 查詢失敗: \(error.localizedDescription)")
//                    completion(.failure(.networkError))
//                    return
//                }
//
//                guard let documents = querySnapshot?.documents else {
//                    completion(.success([]))
//                    return
//                }
//
//                let results: [VacationRuleFirebase] = documents.compactMap { document in
//                    do {
//                        let decodedData = try Firestore.Decoder().decode(VacationRuleFirebase.self, from: document.data())
//                        return decodedData
//                    } catch {
//                        print("❌ 解碼失敗: \(error)")
//                        return nil
//                    }
//                }
//
//                print("✅ 查詢成功: vacation_rules - \(results.count) 個規則")
//                completion(.success(results))
//            }
//    }
//
//    /// 監聽休假規則變化
//    func listenToVacationRule(
//        orgId: String,
//        month: String,
//        completion: @escaping (Result<VacationRuleFirebase, FirebaseError>) -> Void
//    ) -> ListenerRegistration {
//        let documentId = "\(orgId)_\(month)"
//        return listenToDocument(
//            collection: "vacation_rules",
//            documentId: documentId,
//            type: VacationRuleFirebase.self,
//            completion: completion
//        )
//    }
//}
//
//// MARK: - Firebase 專用數據模型
//struct VacationRuleFirebase: Codable {
//    let orgId: String
//    let month: String
//    let type: String
//    let monthlyLimit: Int
//    let weeklyLimit: Int
//    let published: Bool
//    let createdAt: Date
//    let updatedAt: Date
//
//    init(orgId: String, month: String, type: String, monthlyLimit: Int, weeklyLimit: Int, published: Bool) {
//        self.orgId = orgId
//        self.month = month
//        self.type = type
//        self.monthlyLimit = monthlyLimit
//        self.weeklyLimit = weeklyLimit
//        self.published = published
//        self.createdAt = Date()
//        self.updatedAt = Date()
//    }
//
//    // 從現有的 VacationLimits 轉換
//    static func from(vacationLimits: VacationLimits, orgId: String) -> VacationRuleFirebase {
//        return VacationRuleFirebase(
//            orgId: orgId,
//            month: String(format: "%04d-%02d", vacationLimits.year, vacationLimits.month),
//            type: vacationLimits.vacationType.rawValue,
//            monthlyLimit: vacationLimits.monthlyLimit ?? 0,
//            weeklyLimit: vacationLimits.weeklyLimit ?? 0,
//            published: vacationLimits.isPublished
//        )
//    }
//
//    // 轉換為現有的 VacationLimits
//    func toVacationLimits() -> VacationLimits {
//        let components = month.split(separator: "-")
//        let year = Int(components[0]) ?? 2025
//        let monthNum = Int(components[1]) ?? 1
//
//        return VacationLimits(
//            monthlyLimit: monthlyLimit > 0 ? monthlyLimit : nil,
//            weeklyLimit: weeklyLimit > 0 ? weeklyLimit : nil,
//            year: year,
//            month: monthNum,
//            isPublished: published,
//            publishedDate: published ? updatedAt : nil,
//            vacationType: VacationType(rawValue: type) ?? .monthly
//        )
//    }
//}
