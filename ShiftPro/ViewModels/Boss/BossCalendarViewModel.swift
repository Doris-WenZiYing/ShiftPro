//
//  BossCalendarViewModel.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/11.
//

import Foundation
import Combine
import SwiftUI

class BossCalendarViewModel: ObservableObject {
    // MARK: - 🔥 簡化的 Published Properties
    @Published var currentVacationMode: VacationMode = .monthly
    @Published var currentDisplayMonth: String
    @Published var lastError: ShiftProError?

    // MARK: - 🔥 簡化的 Firebase 狀態
    @Published var firebaseRule: FirestoreVacationRule?
    @Published var isFirebaseLoading = false
    @Published var isSchedulePublished = false

    // MARK: - 🔥 簡化的 Toast 管理
    @Published var toastMessage = ""
    @Published var toastType: ToastType = .info
    @Published var isToastShowing = false

    // MARK: - Dependencies
    private let firebase = FirebaseService.shared
    private let userManager = UserManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 🔥 簡化的狀態管理 - 移除複雜的監聽器管理
    private var activeListener: AnyCancellable?

    // MARK: - Computed Properties
    private var currentOrgId: String {
        userManager.currentOrgId
    }

    // 🔥 統一的狀態計算
    var isVacationPublished: Bool {
        firebaseRule?.published ?? false
    }

    var vacationStatusText: String {
        if isFirebaseLoading {
            return "處理中"
        }

        if let rule = firebaseRule {
            return rule.published ? "已發佈" : "已設定未發佈"
        } else {
            return "未設定"
        }
    }

    var vacationStatusColor: Color {
        if isFirebaseLoading {
            return .blue
        }

        if let rule = firebaseRule {
            return rule.published ? .green : .orange
        } else {
            return .gray
        }
    }

    var scheduleStatusText: String {
        if isFirebaseLoading {
            return "處理中..."
        }
        return isSchedulePublished ? "已發佈" : "未發佈"
    }

    var scheduleStatusColor: Color {
        if isFirebaseLoading {
            return .blue
        }
        return isSchedulePublished ? .green : .orange
    }

    // MARK: - Init
    init() {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        self.currentDisplayMonth = formatter.string(from: now)

        print("👑 Boss ViewModel 初始化: \(currentDisplayMonth)")

        // 🔥 簡化初始化
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.loadCurrentMonthData()
        }
    }

    deinit {
        print("🗑️ BossCalendarViewModel deinit")
        removeFirebaseListener()
        cancellables.forEach { $0.cancel() }
    }

    // MARK: - 🔥 簡化的月份更新
    func updateDisplayMonth(year: Int, month: Int) {
        let newMonth = String(format: "%04d-%02d", year, month)
        guard newMonth != currentDisplayMonth else { return }

        print("📅 Boss 月份更新: \(currentDisplayMonth) -> \(newMonth)")

        // 🔥 立即更新月份，清除舊狀態
        currentDisplayMonth = newMonth

        // 🔥 關鍵修復：清除舊狀態，避免顯示錯誤信息
        firebaseRule = nil

        // 立即載入新月份數據
        loadCurrentMonthData()
    }

    // MARK: - 🔥 簡化的數據載入
    private func loadCurrentMonthData() {
        setupFirebaseListener()
    }

    // MARK: - 🔥 修復的 Firebase 監聽器
    private func setupFirebaseListener() {
        removeFirebaseListener()

        print("👂 Boss 設置 Firebase 監聽: \(currentDisplayMonth)")

        activeListener = firebase.fetchVacationRule(orgId: currentOrgId, month: currentDisplayMonth)
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rule in
                self?.handleRuleUpdate(rule)
            }
    }

    private func handleRuleUpdate(_ rule: FirestoreVacationRule?) {
        firebaseRule = rule

        if let r = rule {
            currentVacationMode = VacationMode(rawValue: r.type) ?? .monthly
        }

        SyncStatusManager.shared.setSyncSuccess()
        print("📊 Boss 數據同步完成: \(currentDisplayMonth)")
    }

    private func removeFirebaseListener() {
        activeListener?.cancel()
        activeListener = nil
    }

    // MARK: - 🔥 簡化的排休發佈
    func publishVacationSetting(_ setting: VacationSetting) {
        guard !isFirebaseLoading else {
            showToast("請等待當前操作完成", type: .warning)
            return
        }

        print("🚀 Boss 發佈排休設定...")
        isFirebaseLoading = true
        SyncStatusManager.shared.setSyncing()

        firebase.updateVacationRule(
            orgId: currentOrgId,
            month: currentDisplayMonth,
            type: setting.type.rawValue,
            monthlyLimit: setting.allowedDays,
            weeklyLimit: setting.type == .weekly ? setting.allowedDays : nil,
            published: true
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isFirebaseLoading = false

                switch completion {
                case .failure(let error):
                    print("❌ Boss 發佈失敗: \(error)")
                    self?.showToast("發佈失敗，請重試", type: .error)
                    SyncStatusManager.shared.setSyncError()
                case .finished:
                    break
                }
            },
            receiveValue: { [weak self] in
                print("✅ Boss 發佈成功！")
                SyncStatusManager.shared.setSyncSuccess()
                self?.showToast("發佈排休成功！員工現在可以開始排休了", type: .success)

                // 發送通知
                NotificationCenter.default.post(
                    name: Notification.Name("VacationRulePublished"),
                    object: nil,
                    userInfo: [
                        "orgId": self?.currentOrgId ?? "",
                        "month": self?.currentDisplayMonth ?? ""
                    ]
                )
            }
        )
        .store(in: &cancellables)
    }

    // MARK: - 🔥 簡化的取消發佈
    func unpublishVacation() {
        guard !isFirebaseLoading else {
            showToast("請等待當前操作完成", type: .warning)
            return
        }

        print("🗑️ Boss 取消發佈排休...")
        isFirebaseLoading = true
        SyncStatusManager.shared.setSyncing()

        firebase.deleteVacationRule(orgId: currentOrgId, month: currentDisplayMonth)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isFirebaseLoading = false

                    switch completion {
                    case .failure(let error):
                        print("❌ Boss 取消發佈失敗: \(error)")
                        self?.showToast("取消發佈失敗，請重試", type: .error)
                        SyncStatusManager.shared.setSyncError()
                    case .finished:
                        break
                    }
                },
                receiveValue: { [weak self] in
                    print("✅ Boss 取消發佈成功")
                    SyncStatusManager.shared.setSyncSuccess()
                    self?.showToast("取消發佈成功", type: .warning)

                    // 發送通知
                    NotificationCenter.default.post(
                        name: Notification.Name("VacationRuleUnpublished"),
                        object: nil,
                        userInfo: [
                            "orgId": self?.currentOrgId ?? "",
                            "month": self?.currentDisplayMonth ?? ""
                        ]
                    )

                    // 清除本地狀態
                    self?.firebaseRule = nil
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - 班表管理（簡化版）
    func publishSchedule(_ scheduleData: ScheduleData) {
        guard !isFirebaseLoading else {
            showToast("請等待當前操作完成", type: .warning)
            return
        }

        print("📋 Boss 發佈班表: \(scheduleData.mode.displayName)")
        isFirebaseLoading = true
        SyncStatusManager.shared.setSyncing()

        // 🔥 簡化的班表發佈模擬
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isFirebaseLoading = false
            self.isSchedulePublished = true
            SyncStatusManager.shared.setSyncSuccess()
            self.showToast("班表發佈成功！", type: .success)
        }
    }

    func unpublishSchedule() {
        guard !isFirebaseLoading else {
            showToast("請等待當前操作完成", type: .warning)
            return
        }

        print("📋 Boss 取消發佈班表")
        isFirebaseLoading = true
        SyncStatusManager.shared.setSyncing()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isFirebaseLoading = false
            self.isSchedulePublished = false
            SyncStatusManager.shared.setSyncSuccess()
            self.showToast("班表已取消發佈", type: .warning)
        }
    }

    // MARK: - Boss Actions
    func handleBossAction(_ action: BossAction) {
        print("👑 Boss 執行動作: \(action.displayName)")

        switch action {
        case .unpublishVacation:
            unpublishVacation()
        case .unpublishSchedule:
            unpublishSchedule()
        default:
            break
        }
    }

    // MARK: - 輔助方法
    func getVacationLimits() -> (monthly: Int, weekly: Int) {
        if let rule = firebaseRule {
            return (rule.monthlyLimit ?? 8, rule.weeklyLimit ?? 2)
        }
        return (8, 2)
    }

    func isCurrentlyPublished() -> Bool {
        return firebaseRule?.published ?? false
    }

    func getCurrentVacationType() -> VacationType {
        if let rule = firebaseRule,
           let type = VacationType(rawValue: rule.type) {
            return type
        }
        return .monthly
    }

    // MARK: - Toast 管理
    func showToast(_ msg: String, type: ToastType) {
        toastMessage = msg
        toastType = type
        withAnimation { isToastShowing = true }

        let delay = type == .error ? 5.0 : 3.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation { self.isToastShowing = false }
        }
    }
}
