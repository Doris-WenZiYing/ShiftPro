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
    // MARK: - Published Properties
    @Published var currentVacationMode: VacationMode = .monthly
    @Published var isVacationPublished = false
    @Published var isSchedulePublished = false
    @Published var toastMessage = ""
    @Published var toastType: ToastType = .info
    @Published var isToastShowing = false
    @Published var currentDisplayMonth: String
    @Published var lastError: ShiftProError?

    // MARK: - Firebase 狀態追蹤
    @Published var firebaseRule: FirestoreVacationRule?
    @Published var isFirebaseLoading = false
    @Published var lastSyncTime: Date?

    // MARK: - Dependencies
    private let firebase = FirebaseService.shared
    private let userManager = UserManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 狀態管理
    private var isInitialized = false
    private var currentListener: AnyCancellable?

    // MARK: - Computed Properties
    private var currentOrgId: String {
        userManager.currentOrgId
    }

    var realVacationStatus: String {
        if isFirebaseLoading {
            return "處理中"
        }

        if let rule = firebaseRule {
            return rule.published ? "已發佈" : "已設定未發佈"
        } else {
            return "未設定"
        }
    }

    var realVacationStatusColor: Color {
        if isFirebaseLoading {
            return .blue
        }

        if let rule = firebaseRule {
            return rule.published ? .green : .orange
        } else {
            return .gray
        }
    }

    // MARK: - Init
    init() {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        self.currentDisplayMonth = formatter.string(from: now)

        print("👑 Boss ViewModel 初始化")

        setupUserManager()

        // 延遲初始化
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isInitialized = true
            self.loadCurrentMonthData()
        }
    }

    deinit {
        print("🗑️ BossCalendarViewModel deinit")
        removeFirebaseListener()
        cancellables.forEach { $0.cancel() }
    }

    // MARK: - 🔧 用戶管理設置

    private func setupUserManager() {
        if !userManager.isLoggedIn && !userManager.isGuest {
            userManager.setCurrentBoss(
                orgId: "demo_store_01",
                bossName: "測試老闆",
                orgName: "Demo Store"
            )
        }

        userManager.$currentUser
            .sink { [weak self] _ in
                self?.handleUserChange()
            }
            .store(in: &cancellables)

        // 監聽用戶錯誤
        userManager.$lastError
            .sink { [weak self] error in
                if let error = error {
                    self?.handleError(error, context: "User Manager")
                }
            }
            .store(in: &cancellables)
    }

    private func handleUserChange() {
        removeFirebaseListener()
        if isInitialized {
            loadCurrentMonthData()
        }
    }

    // MARK: - 🔄 月份更新

    func updateDisplayMonth(year: Int, month: Int) {
        guard isInitialized else { return }

        let newMonth = String(format: "%04d-%02d", year, month)
        guard isValidMonth(year: year, month: month) else {
            handleError(ShiftProError.validationFailed("無效的月份選擇"), context: "Month Update")
            return
        }
        guard newMonth != currentDisplayMonth else { return }

        print("📅 Boss 更新月份: \(currentDisplayMonth) -> \(newMonth)")

        removeFirebaseListener()
        currentDisplayMonth = newMonth
        loadCurrentMonthData()
    }

    private func isValidMonth(year: Int, month: Int) -> Bool {
        let currentYear = Calendar.current.component(.year, from: Date())
        return year >= currentYear - 1 && year <= currentYear + 2 && month >= 1 && month <= 12
    }

    // MARK: - 🔄 數據載入

    private func loadCurrentMonthData() {
        setupFirebaseListener()
    }

    // MARK: - 🔥 Firebase 實時監聽

    private func setupFirebaseListener() {
        removeFirebaseListener()

        currentListener = firebase.fetchVacationRule(orgId: currentOrgId, month: currentDisplayMonth)
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rule in
                self?.handleRuleUpdate(rule)
            }

        print("👂 Boss 設置 Firebase 監聽: \(currentDisplayMonth)")
    }

    private func handleRuleUpdate(_ rule: FirestoreVacationRule?) {
        firebaseRule = rule

        if let r = rule {
            isVacationPublished = r.published
            currentVacationMode = VacationMode(rawValue: r.type) ?? .monthly
        } else {
            isVacationPublished = false
        }

        lastSyncTime = Date()
        SyncStatusManager.shared.setSyncSuccess()
    }

    private func removeFirebaseListener() {
        currentListener?.cancel()
        currentListener = nil
        print("🔇 Boss 移除監聽")
    }

    // MARK: - 🚀 排休發佈

    func publishVacationSetting(_ setting: VacationSetting) {
        guard !isFirebaseLoading else {
            showToast("請等待當前操作完成", type: .warning)
            return
        }

        print("🚀 Boss 發佈排休設定...")
        print("   組織: \(currentOrgId)")
        print("   月份: \(currentDisplayMonth)")
        print("   類型: \(setting.type.rawValue)")
        print("   天數: \(setting.allowedDays)")

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
                    self?.handleError(error, context: "Publish Vacation")
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

    // MARK: - 🗑️ 取消發佈

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
                        self?.handleError(error, context: "Unpublish Vacation")
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

                    // 更新本地狀態
                    self?.isVacationPublished = false
                    self?.firebaseRule = nil
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - 📋 班表管理

    func publishSchedule(_ scheduleData: ScheduleData) {
        guard !isFirebaseLoading else {
            showToast("請等待當前操作完成", type: .warning)
            return
        }

        print("📋 Boss 發佈班表: \(scheduleData.mode.displayName)")

        isFirebaseLoading = true
        SyncStatusManager.shared.setSyncing()

        // 簡單的班表發佈模擬
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

    // MARK: - 👑 Boss Actions

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

    // MARK: - 📊 狀態屬性

    var vacationStatusText: String {
        return realVacationStatus
    }

    var vacationStatusColor: Color {
        return realVacationStatusColor
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

    // MARK: - 🔧 輔助方法

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

    // MARK: - 🎯 Toast 管理

    func showToast(_ msg: String, type: ToastType) {
        toastMessage = msg
        toastType = type
        withAnimation { isToastShowing = true }

        let delay = type == .error ? 5.0 : 3.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation { self.isToastShowing = false }
        }
    }

    // MARK: - 🚨 錯誤處理

    private func handleError(_ error: Error, context: String) {
        let shiftProError: ShiftProError

        if let spError = error as? ShiftProError {
            shiftProError = spError
        } else {
            shiftProError = ShiftProError.unknown("\(context): \(error.localizedDescription)")
        }

        lastError = shiftProError
        showToast(shiftProError.errorDescription ?? "發生錯誤", type: .error)

        print("❌ BossCalendarViewModel Error [\(context)]: \(shiftProError.errorDescription ?? "Unknown")")
    }
}
