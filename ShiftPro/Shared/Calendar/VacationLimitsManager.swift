//
//  VacationLimitsManager.swift
//  ShiftPro
//
//  增強版休假限制管理器
//

import Foundation

class VacationLimitsManager: ObservableObject {
    static let shared = VacationLimitsManager()

    private let userDefaults = UserDefaults.standard
    private let limitsKey = "VacationLimits"

    private init() {}

    // MARK: - 保存休假限制
    func saveVacationLimits(_ limits: VacationLimits) -> Bool {
        do {
            let encoded = try JSONEncoder().encode(limits)
            let key = "\(limitsKey)_\(limits.year)_\(limits.month)"
            userDefaults.set(encoded, forKey: key)

            print("✅ 休假限制已保存: \(key)")
            print("   類型: \(limits.vacationType.rawValue)")
            print("   月限制: \(limits.monthlyLimit ?? 0)")
            print("   週限制: \(limits.weeklyLimit ?? 0)")
            print("   已發佈: \(limits.isPublished)")

            return true
        } catch {
            print("❌ 保存休假限制失敗: \(error)")
            return false
        }
    }

    // MARK: - 保存並發送通知
    func saveVacationLimitsWithNotification(_ limits: VacationLimits) -> Bool {
        let success = saveVacationLimits(limits)
        if success {
            // 發送通知給員工端
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .vacationLimitsDidUpdate,
                    object: limits,
                    userInfo: [
                        "isNewPublication": limits.isPublished, // 🔥 修復：使用 limits.isPublished
                        "vacationType": limits.vacationType.rawValue,
                        "targetMonth": "\(limits.year)-\(String(format: "%02d", limits.month))"
                    ]
                )

                print("📤 通知已發送給員工端")
                print("   月份: \(limits.year)-\(String(format: "%02d", limits.month))")
                print("   類型: \(limits.vacationType.rawValue)")
                print("   是否為新發佈: \(limits.isPublished)")
            }
        }
        return success
    }

    // MARK: - 獲取休假限制
    func getVacationLimits(for year: Int, month: Int) -> VacationLimits {
        let key = "\(limitsKey)_\(year)_\(month)"

        if let data = userDefaults.data(forKey: key),
           let limits = try? JSONDecoder().decode(VacationLimits.self, from: data) {

            print("📖 讀取到休假限制: \(key)")
            print("   類型: \(limits.vacationType.rawValue)")
            print("   月限制: \(limits.monthlyLimit ?? 0)")
            print("   週限制: \(limits.weeklyLimit ?? 0)")
            print("   已發佈: \(limits.isPublished)")

            return limits
        }

        // 返回默認值
        print("🔄 使用默認休假限制: \(key)")
        return VacationLimits(
            monthlyLimit: 8,
            weeklyLimit: 2,
            year: year,
            month: month,
            isPublished: false,
            vacationType: .monthly
        )
    }

    // MARK: - 檢查是否有設定
    func hasLimitsForMonth(year: Int, month: Int) -> Bool {
        let key = "\(limitsKey)_\(year)_\(month)"
        let hasData = userDefaults.data(forKey: key) != nil

        if hasData {
            // 進一步檢查是否已發佈
            let limits = getVacationLimits(for: year, month: month)
            print("🔍 檢查月份 \(year)-\(month) 的設定狀態: 已發佈=\(limits.isPublished)")
            return limits.isPublished
        }

        print("🔍 檢查月份 \(year)-\(month): 無資料")
        return false
    }

    // MARK: - 獲取所有已發佈的設定
    func getAllPublishedLimits() -> [VacationLimits] {
        var allLimits: [VacationLimits] = []

        // 搜索所有相關的key
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let limitsKeys = allKeys.filter { $0.hasPrefix(limitsKey) }

        for key in limitsKeys {
            if let data = userDefaults.data(forKey: key),
               let limits = try? JSONDecoder().decode(VacationLimits.self, from: data),
               limits.isPublished {
                allLimits.append(limits)
            }
        }

        // 按年月排序
        return allLimits.sorted { first, second in
            if first.year != second.year {
                return first.year < second.year
            }
            return first.month < second.month
        }
    }

    // MARK: - 刪除設定
    func deleteLimits(for year: Int, month: Int) -> Bool {
        let key = "\(limitsKey)_\(year)_\(month)"
        userDefaults.removeObject(forKey: key)

        print("🗑️ 已刪除休假限制: \(key)")

        // 發送刪除通知
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .vacationLimitsDidUpdate,
                object: nil,
                userInfo: [
                    "isDeleted": true,
                    "targetMonth": "\(year)-\(String(format: "%02d", month))"
                ]
            )
        }

        return true
    }

    // MARK: - 清除所有設定
    func clearAllLimits() {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let limitsKeys = allKeys.filter { $0.hasPrefix(limitsKey) }

        for key in limitsKeys {
            userDefaults.removeObject(forKey: key)
        }

        print("🧹 已清除所有休假限制")

        // 發送清除通知
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .vacationLimitsDidUpdate,
                object: nil,
                userInfo: ["isCleared": true]
            )
        }
    }

    // MARK: - 調試方法
    func printAllStoredLimits() {
        print("\n📋 所有儲存的休假限制:")
        let allLimits = getAllPublishedLimits()

        if allLimits.isEmpty {
            print("   (無)")
        } else {
            for limits in allLimits {
                print("   \(limits.displayText)")
            }
        }
        print("")
    }
}
