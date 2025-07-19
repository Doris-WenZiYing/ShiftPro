//
//  FirebaseService.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/17.
//

import FirebaseFirestore
import Combine

final class FirebaseService {
    static let shared = FirebaseService()
    let firestore = Firestore.firestore()

    private init() {}

    // MARK: - Generic CRUD Operations

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
                    // 🔥 使用 Firestore 原生解碼器
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
                    // 🔥 使用 Firestore 原生解碼器
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

    // MARK: - Collection Operations

    /// 取得集合中的所有文檔
    func getCollection<T: Decodable>(
        collection: String,
        as type: T.Type
    ) -> AnyPublisher<[T], Error> {
        return Future<[T], Error> { promise in
            self.firestore.collection(collection).getDocuments { querySnapshot, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }

                guard let documents = querySnapshot?.documents else {
                    promise(.success([]))
                    return
                }

                do {
                    var results: [T] = []
                    let decoder = Firestore.Decoder()

                    for document in documents {
                        let decodedObject = try decoder.decode(type, from: document.data())
                        results.append(decodedObject)
                    }

                    promise(.success(results))
                } catch {
                    print("❌ Firebase 集合解碼錯誤: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    /// 查詢集合
    func queryCollection<T: Decodable>(
        collection: String,
        field: String,
        isEqualTo value: Any,
        as type: T.Type
    ) -> AnyPublisher<[T], Error> {
        return Future<[T], Error> { promise in
            self.firestore.collection(collection)
                .whereField(field, isEqualTo: value)
                .getDocuments { querySnapshot, error in
                    if let error = error {
                        promise(.failure(error))
                        return
                    }

                    guard let documents = querySnapshot?.documents else {
                        promise(.success([]))
                        return
                    }

                    do {
                        var results: [T] = []

                        for document in documents {
                            var data = document.data()
                            data["id"] = document.documentID  // 添加文檔 ID

                            let processedData = self.convertFirebaseTimestamps(data)
                            let jsonData = try JSONSerialization.data(withJSONObject: processedData)

                            let decoder = JSONDecoder()
                            decoder.dateDecodingStrategy = .millisecondsSince1970

                            let decodedObject = try decoder.decode(type, from: jsonData)
                            results.append(decodedObject)
                        }

                        promise(.success(results))
                    } catch {
                        print("❌ Firebase 查詢解碼錯誤: \(error)")
                        promise(.failure(error))
                    }
                }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Private Helper Methods

    /// 檢查類型是否需要 id 欄位
    private func typeRequiresId<T>(_ type: T.Type) -> Bool {
        let typeName = String(describing: type)
        return typeName.contains("Firestore") || typeName.contains("Identifiable")
    }

    /// 將 Firebase Timestamp 轉換為時間戳（毫秒），以便 JSON 序列化
    private func convertFirebaseTimestamps(_ data: [String: Any]) -> [String: Any] {
        var processedData = [String: Any]()

        for (key, value) in data {
            if let timestamp = value as? Timestamp {
                // 將 Firebase Timestamp 轉換為毫秒時間戳
                let milliseconds = timestamp.seconds * 1000 + Int64(timestamp.nanoseconds / 1_000_000)
                processedData[key] = milliseconds
            } else if let nestedDict = value as? [String: Any] {
                // 遞歸處理嵌套字典
                processedData[key] = convertFirebaseTimestamps(nestedDict)
            } else if let array = value as? [Any] {
                // 處理陣列中的時間戳
                processedData[key] = convertFirebaseTimestampsInArray(array)
            } else {
                // 其他類型直接保留
                processedData[key] = value
            }
        }

        return processedData
    }

    /// 處理陣列中的 Firebase Timestamp
    private func convertFirebaseTimestampsInArray(_ array: [Any]) -> [Any] {
        return array.map { element in
            if let timestamp = element as? Timestamp {
                // 轉換為毫秒時間戳
                let milliseconds = timestamp.seconds * 1000 + Int64(timestamp.nanoseconds / 1_000_000)
                return milliseconds
            } else if let nestedDict = element as? [String: Any] {
                return convertFirebaseTimestamps(nestedDict)
            } else if let nestedArray = element as? [Any] {
                return convertFirebaseTimestampsInArray(nestedArray)
            } else {
                return element
            }
        }
    }

    // MARK: - Utility Methods

    /// 檢查文檔是否存在
    func documentExists(
        collection: String,
        document: String
    ) -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { promise in
            self.firestore.collection(collection).document(document).getDocument { snapshot, error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(snapshot?.exists ?? false))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    /// 批次寫入操作
    func batchWrite(operations: [(collection: String, document: String, data: [String: Any])]) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            let batch = self.firestore.batch()

            for operation in operations {
                let docRef = self.firestore.collection(operation.collection).document(operation.document)
                batch.setData(operation.data, forDocument: docRef)
            }

            batch.commit { error in
                if let error = error {
                    print("❌ Firebase 批次寫入失敗: \(error)")
                    promise(.failure(error))
                } else {
                    print("✅ Firebase 批次寫入成功")
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}
