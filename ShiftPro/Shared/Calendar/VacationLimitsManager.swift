//
//  VacationLimitsManager.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/15.
//

import Foundation
import FirebaseFirestore

class VacationLimitsManager: ObservableObject {
    static let shared = VacationLimitsManager()

    private let userDefaults = UserDefaults.standard
    private let limitsKey    = "VacationLimits"
    private let db           = Firestore.firestore()

    /// 後端或預設的組織 ID（可由登入流程設定）
    var orgId: String {
        userDefaults.string(forKey: "orgId") ?? "demo_store_01"
    }

    private init() {}

    // MARK: - Local Storage

    /// 將 VacationLimits 編碼後存到 UserDefaults
    func saveVacationLimits(_ limits: VacationLimits) -> Bool {
        do {
            let data = try JSONEncoder().encode(limits)
            let key  = "\(limitsKey)_\(limits.month)"
            userDefaults.set(data, forKey: key)
            print("✅ 本地儲存休假限制：\(key)")
            return true
        } catch {
            print("❌ 本地儲存失敗：\(error)")
            return false
        }
    }

    /// 從 UserDefaults 取出 VacationLimits，若無則回傳預設
    func getVacationLimits(for year: Int, month: Int) -> VacationLimits {
        let monthString = String(format: "%04d-%02d", year, month)
        let key = "\(limitsKey)_\(monthString)"

        if let data = userDefaults.data(forKey: key),
           let limits = try? JSONDecoder().decode(VacationLimits.self, from: data) {
            return limits
        }

        // 回傳未發布的預設
        return VacationLimits(
            orgId: orgId,
            month: monthString,
            vacationType: VacationType.monthly.rawValue,
            monthlyLimit: nil,
            weeklyLimit: nil,
            isPublished: false,
            publishedDate: nil
        )
    }

    func hasLimitsForMonth(year: Int, month: Int) -> Bool {
        getVacationLimits(for: year, month: month).isPublished
    }

    func deleteLimits(for year: Int, month: Int) -> Bool {
        let monthString = String(format: "%04d-%02d", year, month)
        let key = "\(limitsKey)_\(monthString)"
        userDefaults.removeObject(forKey: key)

        // 同步刪除 Firestore
        db.collection("vacation_limits")
          .document("\(orgId)_\(monthString)")
          .delete() { error in
            if let e = error {
                print("❌ Firebase 刪除失敗：\(e)")
            } else {
                print("✅ Firebase 刪除成功：\(monthString)")
            }
          }

        // 發送更新通知
        NotificationCenter.default.post(
            name: .vacationLimitsDidUpdate,
            object: nil,
            userInfo: ["targetMonth": monthString, "isDeleted": true]
        )
        return true
    }

    // MARK: - Firebase Sync

    /// 將本地或 Boss 設定同步到 Firestore
    func syncToFirebase(_ limits: VacationLimits, completion: @escaping (Bool) -> Void) {
        let key = "\(orgId)_\(limits.month)"
        let data: [String: Any] = [
            "orgId": limits.orgId,
            "month": limits.month,
            "vacationType": limits.vacationType,
            "monthlyLimit": limits.monthlyLimit ?? 0,
            "weeklyLimit": limits.weeklyLimit ?? 0,
            "isPublished": limits.isPublished,
            "publishedDate": limits.publishedDate ?? Date(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        db.collection("vacation_limits")
          .document(key)
          .setData(data) { error in
            if let e = error {
                print("❌ Firebase 同步失敗：\(e)")
                completion(false)
            } else {
                print("✅ Firebase 同步成功：\(key)")
                completion(true)
                // 通知 UI
                NotificationCenter.default.post(
                    name: .vacationLimitsDidUpdate,
                    object: nil,
                    userInfo: [
                        "targetMonth": limits.month,
                        "isNewPublication": limits.isPublished
                    ]
                )
            }
          }
    }

    /// 從 Firestore 讀取單月設定（一次性），並更新本地快取
    func loadVacationLimitsFromFirebase(
        for year: Int,
        month: Int,
        completion: @escaping (VacationLimits?) -> Void
    ) {
        let monthString = String(format: "%04d-%02d", year, month)
        let key = "\(orgId)_\(monthString)"
        db.collection("vacation_limits")
          .document(key)
          .getDocument { snap, error in
            guard
              let data = snap?.data(),
              error == nil,
              let limits = self.parseFirebaseData(data, monthString: monthString)
            else {
              completion(nil)
              return
            }
            // 更新本地
            _ = self.saveVacationLimits(limits)
            completion(limits)
          }
    }

    /// 解析 Firestore 回傳的 raw data
    private func parseFirebaseData(
        _ data: [String: Any],
        monthString: String
    ) -> VacationLimits? {
        guard
          let vType  = data["vacationType"] as? String,
          let isPub  = data["isPublished"] as? Bool
        else { return nil }

        let mLimit = data["monthlyLimit"] as? Int
        let wLimit = data["weeklyLimit"] as? Int
        let pubDate: Date?
        if let ts = data["publishedDate"] as? Timestamp {
            pubDate = ts.dateValue()
        } else {
            pubDate = nil
        }

        return VacationLimits(
            orgId: orgId,
            month: monthString,
            vacationType: vType,
            monthlyLimit: mLimit,
            weeklyLimit: wLimit,
            isPublished: isPub,
            publishedDate: pubDate
        )
    }
}
