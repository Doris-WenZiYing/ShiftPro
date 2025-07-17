//
//  VacationLimitsManager+Firebase.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/17.
//

import Foundation
import Firebase
import FirebaseFirestore

extension VacationLimitsManager {

    // MARK: - Firebase 整合設定
    private var orgId: String {
        return UserDefaults.standard.string(forKey: "orgId") ?? "demo_store_01"
    }

    private var firebaseManager: FirebaseManager {
        return FirebaseManager.shared
    }

    // MARK: - 🔥 修正：確保 Firebase 同步的保存方法

    /// 保存休假限制到 Firebase（同時保存到本地）
    func saveVacationLimitsWithFirebaseSync(_ limits: VacationLimits) -> Bool {
        print("🔥 開始保存到 Firebase: \(limits.year)-\(limits.month)")

        // 先保存到本地
        let localSuccess = saveVacationLimits(limits)

        guard localSuccess else {
            print("❌ 本地保存失敗")
            return false
        }

        // 🔥 立即測試 Firebase 連接
        testFirebaseConnection()

        // 轉換為 Firebase 格式
        let firebaseRule = VacationRuleFirebase.from(vacationLimits: limits, orgId: orgId)

        print("📦 準備同步到 Firebase:")
        print("   orgId: \(firebaseRule.orgId)")
        print("   month: \(firebaseRule.month)")
        print("   type: \(firebaseRule.type)")
        print("   monthlyLimit: \(firebaseRule.monthlyLimit)")
        print("   weeklyLimit: \(firebaseRule.weeklyLimit)")
        print("   published: \(firebaseRule.published)")

        // 🔥 直接使用 Firestore 進行同步（而不是異步）
        let db = Firestore.firestore()
        let documentId = "\(orgId)_\(firebaseRule.month)"

        do {
            let encodedData = try Firestore.Encoder().encode(firebaseRule)

            // 同步寫入
            let semaphore = DispatchSemaphore(value: 0)
            var syncSuccess = false

            db.collection("vacation_rules")
                .document(documentId)
                .setData(encodedData) { error in
                    if let error = error {
                        print("❌ Firebase 同步失敗: \(error.localizedDescription)")
                        syncSuccess = false
                    } else {
                        print("✅ Firebase 同步成功: \(documentId)")
                        syncSuccess = true
                    }
                    semaphore.signal()
                }

            // 等待同步完成（最多等待 10 秒）
            let result = semaphore.wait(timeout: .now() + 10)

            if result == .timedOut {
                print("⏰ Firebase 同步超時")
                addToOfflineQueue(limits)
                return true // 本地保存成功，但 Firebase 同步失敗
            }

            if syncSuccess {
                // 🔥 同步成功後發送通知
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .vacationLimitsDidUpdate,
                        object: limits,
                        userInfo: [
                            "isNewPublication": limits.isPublished,
                            "vacationType": limits.vacationType.rawValue,
                            "targetMonth": "\(limits.year)-\(String(format: "%02d", limits.month))",
                            "syncedToFirebase": true
                        ]
                    )
                }
            } else {
                addToOfflineQueue(limits)
            }

            return true

        } catch {
            print("❌ Firebase 編碼失敗: \(error)")
            addToOfflineQueue(limits)
            return true
        }
    }

    // MARK: - 🔥 新增：測試 Firebase 連接
    private func testFirebaseConnection() {
        let db = Firestore.firestore()

        // 快速測試寫入
        let testData = ["test": "connection", "timestamp": Timestamp(date: Date())] as [String : Any]
        db.collection("test").document("quick_test").setData(testData) { error in
            if let error = error {
                print("❌ Firebase 連接測試失敗: \(error.localizedDescription)")
            } else {
                print("✅ Firebase 連接測試成功")
            }
        }
    }

    // MARK: - 🔥 修正：從 Firebase 載入方法
    func loadVacationLimitsFromFirebase(for year: Int, month: Int, completion: @escaping (VacationLimits?) -> Void) {
        let monthString = String(format: "%04d-%02d", year, month)
        let documentId = "\(orgId)_\(monthString)"

        print("🔍 從 Firebase 載入: \(documentId)")

        let db = Firestore.firestore()
        db.collection("vacation_rules")
            .document(documentId)
            .getDocument { document, error in
                if let error = error {
                    print("❌ Firebase 讀取失敗: \(error.localizedDescription)")

                    // 嘗試從本地載入
                    let localLimits = self.getVacationLimits(for: year, month: month)
                    completion(localLimits.isPublished ? localLimits : nil)
                    return
                }

                guard let document = document,
                      document.exists,
                      let data = document.data() else {
                    print("📱 Firebase 中無該文檔: \(documentId)")

                    // 嘗試從本地載入
                    let localLimits = self.getVacationLimits(for: year, month: month)
                    completion(localLimits.isPublished ? localLimits : nil)
                    return
                }

                do {
                    let firebaseRule = try Firestore.Decoder().decode(VacationRuleFirebase.self, from: data)
                    let limits = firebaseRule.toVacationLimits()

                    print("✅ 從 Firebase 載入成功: \(monthString)")
                    print("   類型: \(limits.vacationType.rawValue)")
                    print("   月限制: \(limits.monthlyLimit ?? 0)")
                    print("   週限制: \(limits.weeklyLimit ?? 0)")
                    print("   已發佈: \(limits.isPublished)")

                    // 同步到本地
                    _ = self.saveVacationLimits(limits)

                    completion(limits)

                } catch {
                    print("❌ Firebase 解碼失敗: \(error)")

                    // 嘗試從本地載入
                    let localLimits = self.getVacationLimits(for: year, month: month)
                    completion(localLimits.isPublished ? localLimits : nil)
                }
            }
    }

    // MARK: - 🔥 修正：離線佇列支援

    /// 添加到離線佇列
    private func addToOfflineQueue(_ limits: VacationLimits) {
        var offlineQueue = getOfflineQueue()

        // 移除重複的月份
        offlineQueue.removeAll { $0.year == limits.year && $0.month == limits.month }

        // 添加新的
        offlineQueue.append(limits)
        saveOfflineQueue(offlineQueue)

        print("📱 已添加到離線佇列: \(limits.year)-\(limits.month)")
    }

    /// 處理離線佇列
    func processOfflineQueue() {
        let offlineQueue = getOfflineQueue()

        guard !offlineQueue.isEmpty else {
            print("📱 離線佇列為空")
            return
        }

        print("📱 處理離線佇列: \(offlineQueue.count) 個項目")

        for limits in offlineQueue {
            let firebaseRule = VacationRuleFirebase.from(vacationLimits: limits, orgId: orgId)
            let documentId = "\(orgId)_\(String(format: "%04d-%02d", limits.year, limits.month))"

            let db = Firestore.firestore()

            do {
                let encodedData = try Firestore.Encoder().encode(firebaseRule)

                db.collection("vacation_rules")
                    .document(documentId)
                    .setData(encodedData) { error in
                        if let error = error {
                            print("❌ 離線佇列項目同步失敗: \(error.localizedDescription)")
                        } else {
                            print("✅ 離線佇列項目同步成功: \(limits.year)-\(limits.month)")
                            self.removeFromOfflineQueue(limits)
                        }
                    }
            } catch {
                print("❌ 離線佇列項目編碼失敗: \(error)")
            }
        }
    }

    /// 獲取離線佇列
    private func getOfflineQueue() -> [VacationLimits] {
        guard let data = UserDefaults.standard.data(forKey: "offlineQueue"),
              let queue = try? JSONDecoder().decode([VacationLimits].self, from: data) else {
            return []
        }
        return queue
    }

    /// 保存離線佇列
    private func saveOfflineQueue(_ queue: [VacationLimits]) {
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: "offlineQueue")
        }
    }

    /// 從離線佇列移除
    private func removeFromOfflineQueue(_ limits: VacationLimits) {
        var offlineQueue = getOfflineQueue()
        offlineQueue.removeAll { $0.year == limits.year && $0.month == limits.month }
        saveOfflineQueue(offlineQueue)
    }

    // MARK: - 🔥 新增：設定組織 ID
    func setOrganizationId(_ orgId: String) {
        UserDefaults.standard.set(orgId, forKey: "orgId")
        print("🏢 設定組織 ID: \(orgId)")
    }

    /// 獲取組織 ID
    func getOrganizationId() -> String {
        return orgId
    }
}
