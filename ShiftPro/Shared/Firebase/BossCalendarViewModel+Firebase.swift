////
////  BossCalendarViewModel+Firebase.swift
////  ShiftPro
////
////  Created by Doris Wen on 2025/7/17.
////
//
//import Foundation
//import Firebase
//
//extension BossCalendarViewModel {
//
//    // MARK: - Firebase 支援方法
//
//    /// 發佈休假設定到 Firebase
//    func publishVacationSettingToFirebase(_ setting: VacationSetting) {
//        let limits = setting.toVacationLimits()
//
//        // 使用 Firebase 同步版本
//        let success = VacationLimitsManager.shared.saveVacationLimitsWithFirebaseSync(limits)
//
//        if success {
//            isVacationPublished = true
//            savePublishStatus()
//            showToast("發佈排休成功！已同步至雲端", type: .success)
//        } else {
//            showToast("發佈排休失敗，請重試", type: .error)
//        }
//    }
//
//    /// 從 Firebase 載入發佈狀態
//    func loadPublishStatusFromFirebase() {
//        let components = currentDisplayMonth.split(separator: "-")
//        let year = Int(components[0]) ?? Calendar.current.component(.year, from: Date())
//        let month = Int(components[1]) ?? Calendar.current.component(.month, from: Date())
//
//        VacationLimitsManager.shared.loadVacationLimitsFromFirebase(for: year, month: month) { [weak self] limits in
//            DispatchQueue.main.async {
//                if let limits = limits {
//                    self?.isVacationPublished = limits.isPublished
//                    print("✅ 從 Firebase 載入發佈狀態: \(limits.isPublished)")
//                } else {
//                    self?.isVacationPublished = false
//                    print("📱 Firebase 中無該月份數據，使用本地狀態")
//                }
//                self?.savePublishStatus()
//            }
//        }
//    }
//
//    /// 開始監聽 Firebase 中的休假限制變化
//    func startFirebaseListening() {
//        let components = currentDisplayMonth.split(separator: "-")
//        let year = Int(components[0]) ?? Calendar.current.component(.year, from: Date())
//        let month = Int(components[1]) ?? Calendar.current.component(.month, from: Date())
//
//        // 移除舊的監聽器
//        stopFirebaseListening()
//
//        // 開始新的監聽
//        firebaseListener = VacationLimitsManager.shared.startListening(month: month)
//    }
//
//    /// 停止 Firebase 監聽
//    func stopFirebaseListening() {
//        firebaseListener?.remove()
//        firebaseListener = nil
//    }
//
//    /// 取消發佈並從 Firebase 刪除
//    func unpublishVacationFromFirebase() {
//        let components = currentDisplayMonth.split(separator: "-")
//        let year = Int(components[0]) ?? Calendar.current.component(.year, from: Date())
//        let month = Int(components[1]) ?? Calendar.current.component(.month, from: Date())
//
//        let success = VacationLimitsManager.shared.deleteLimits(for: year, month: month)
//
//        if success {
//            isVacationPublished = false
//            savePublishStatus()
//            showToast("排休計劃已取消發佈並從雲端刪除", type: .warning)
//        } else {
//            showToast("取消發佈失敗，請重試", type: .error)
//        }
//    }
//
//    /// 處理離線佇列
//    func processOfflineQueue() {
//        VacationLimitsManager.shared.processOfflineQueue()
//    }
//
//    // MARK: - 私有屬性擴展
//    private var firebaseListener: ListenerRegistration? {
//        get {
//            return objc_getAssociatedObject(self, &AssociatedKeys.firebaseListener) as? ListenerRegistration
//        }
//        set {
//            objc_setAssociatedObject(self, &AssociatedKeys.firebaseListener, newValue, .OBJC_ASSOCIATION_RETAIN)
//        }
//    }
//}
//
//// MARK: - 關聯鍵
//private struct AssociatedKeys {
//    static var firebaseListener = "firebaseListener"
//}
//
//// MARK: - 修改現有方法以支援 Firebase
//extension BossCalendarViewModel {
//
//    /// 修改 updateDisplayMonth 以支援 Firebase
//    func updateDisplayMonthWithFirebase(year: Int, month: Int) {
//        let newMonth = String(format: "%04d-%02d", year, month)
//        if newMonth != currentDisplayMonth {
//            print("📅 老闆端切換到月份: \(newMonth)")
//            currentDisplayMonth = newMonth
//
//            // 重新載入該月份的設定和數據（優先從 Firebase）
//            loadPublishStatusFromFirebase()
//
//            // 開始監聽新月份的變化
//            startFirebaseListening()
//        }
//    }
//
//    /// 修改 handleBossAction 以支援 Firebase
//    func handleBossActionWithFirebase(_ action: BossAction) {
//        switch action {
//        case .unpublishVacation:
//            unpublishVacationFromFirebase()
//        case .unpublishSchedule:
//            unpublishWorkSchedule()
//        default:
//            handleBossAction(action)
//        }
//    }
//}
//
//// MARK: - 網絡狀態監控
//extension BossCalendarViewModel {
//
//    /// 檢查網絡連接狀態
//    func checkNetworkStatus() {
//        // 簡單的網絡狀態檢查
//        let testRef = Firestore.firestore().collection("test").document("connection")
//        testRef.getDocument { [weak self] document, error in
//            DispatchQueue.main.async {
//                let isConnected = error == nil
//                print("🌐 網絡狀態: \(isConnected ? "已連接" : "未連接")")
//
//                if isConnected {
//                    // 網絡恢復時處理離線佇列
//                    self?.processOfflineQueue()
//                }
//            }
//        }
//    }
//
//    /// 顯示網絡狀態相關的 Toast
//    func showNetworkStatus(_ isConnected: Bool) {
//        let message = isConnected ? "已連接至雲端" : "離線模式，數據將在恢復連接時同步"
//        let type: ToastType = isConnected ? .success : .warning
//        showToast(message, type: type)
//    }
//}
