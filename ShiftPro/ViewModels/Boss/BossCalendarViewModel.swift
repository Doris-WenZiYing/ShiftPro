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
    // MARK: - Published
    @Published var currentVacationMode: VacationMode = .monthly
    @Published var isVacationPublished = false
    @Published var isSchedulePublished = false
    @Published var toastMessage = ""
    @Published var toastType: ToastType = .info
    @Published var isToastShowing = false
    @Published var currentDisplayMonth: String

    // MARK: - Dependencies
    private let scheduleService: ScheduleService
    private let storage: LocalStorageService
    private let userManager = UserManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 🔥 優化：控制月份切換
    private var isInitialized = false
    private var lastValidatedMonth: String = ""
    private var pendingMonthUpdates = Set<String>()
    private var updateThrottleTimer: Timer?

    // MARK: - Real Data Properties
    private var currentOrgId: String {
        userManager.currentOrgId
    }

    // MARK: - Init
    init(
        scheduleService: ScheduleService = .shared,
        storage: LocalStorageService = .shared
    ) {
        self.scheduleService = scheduleService
        self.storage = storage

        // Initialize currentDisplayMonth using extension
        self.currentDisplayMonth = DateFormatter.yearMonthFormatter.string(from: Date())
        self.lastValidatedMonth = self.currentDisplayMonth

        print("👑 Boss 初始化 - 組織: \(currentOrgId)")

        // 如果沒有登入，設定預設身分
        if !userManager.isLoggedIn {
            setupDefaultBoss()
        }

        // load saved publish status
        loadPublishStatus()

        // 🔥 延遲標記為已初始化，避免初始化期間的無意義更新
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isInitialized = true
            print("✅ Boss ViewModel 初始化完成")
        }

        // 🔥 監聽發佈通知
        NotificationCenter.default.addObserver(
            forName: Notification.Name("VacationRulePublished"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let month = notification.userInfo?["month"] as? String,
               month == self?.currentDisplayMonth {
                self?.isVacationPublished = true
                self?.savePublishStatus()
            }
        }

        // 🔥 監聽用戶身分變化
        userManager.$currentUser
            .sink { [weak self] _ in
                self?.loadPublishStatus()
            }
            .store(in: &cancellables)
    }

    deinit {
        cancellables.forEach { $0.cancel() }
        updateThrottleTimer?.invalidate()
    }

    // MARK: - Setup Default Boss
    private func setupDefaultBoss() {
        userManager.setCurrentBoss(
            orgId: "demo_store_01",
            bossName: "測試老闆",
            orgName: "Demo Store"
        )
        print("👑 設定預設老闆身分")
    }

    // MARK: - 🔥 優化的月份管理
    func updateDisplayMonth(year: Int, month: Int) {
        let newMonth = String(format: "%04d-%02d", year, month)

        // 🔥 防護 1：忽略無效的年份
        let currentYear = Calendar.current.component(.year, from: Date())
        if abs(year - currentYear) > 5 {
            print("🚫 Boss 忽略無效年份: \(year)")
            return
        }

        // 🔥 防護 2：檢查是否為有意義的變化
        guard newMonth != currentDisplayMonth else {
            return
        }

        // 🔥 防護 3：等待初始化完成
        guard isInitialized else {
            print("⏳ Boss 等待初始化完成: \(newMonth)")
            return
        }

        // 🔥 防護 4：節流控制，避免快速連續更新
        pendingMonthUpdates.insert(newMonth)
        updateThrottleTimer?.invalidate()
        updateThrottleTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.processPendingMonthUpdates()
        }
    }

    private func processPendingMonthUpdates() {
        guard let latestMonth = pendingMonthUpdates.max() else { return }
        pendingMonthUpdates.removeAll()

        // 只處理最新的月份變化
        guard latestMonth != currentDisplayMonth else { return }

        print("📅 Boss 處理月份變化: \(currentDisplayMonth) -> \(latestMonth)")
        currentDisplayMonth = latestMonth
        lastValidatedMonth = latestMonth

        // 只有合理的月份才載入狀態
        if isReasonableMonth(latestMonth) {
            loadPublishStatus()
        }
    }

    // 🔥 新增：檢查月份是否合理
    private func isReasonableMonth(_ monthString: String) -> Bool {
        let components = monthString.split(separator: "-")
        guard components.count == 2,
              let year = Int(components[0]),
              let month = Int(components[1]) else {
            return false
        }

        let currentYear = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())

        // 只允許當前年份前後2年的範圍
        guard abs(year - currentYear) <= 2 else { return false }

        // 月份必須在1-12之間
        guard month >= 1 && month <= 12 else { return false }

        return true
    }

    // MARK: - Publish Vacation (使用真實數據 + 同步狀態)
    func publishVacationSetting(_ setting: VacationSetting) {
        print("🚀 Boss 發佈排休設定到 Firebase...")
        print("   組織: \(currentOrgId)")
        print("   月份: \(currentDisplayMonth)")
        print("   類型: \(setting.type.rawValue)")
        print("   允許天數: \(setting.allowedDays)")

        // 🔥 設定同步狀態
        SyncStatusManager.shared.setSyncing()

        scheduleService.updateVacationRule(
            orgId: currentOrgId,
            month: currentDisplayMonth,
            type: setting.type.rawValue,
            monthlyLimit: setting.allowedDays,
            weeklyLimit: setting.type == .weekly ? setting.allowedDays : nil,
            published: true
        )
        .sink { [weak self] completion in
            switch completion {
            case .failure(let error):
                DispatchQueue.main.async {
                    print("❌ Boss 發佈失敗: \(error)")
                    SyncStatusManager.shared.setSyncError()
                    self?.showToast("發佈失敗，請重試", type: .error)
                }
            case .finished:
                break
            }
        } receiveValue: { [weak self] in
            DispatchQueue.main.async {
                print("✅ Boss 發佈成功！")
                SyncStatusManager.shared.setSyncSuccess()
                self?.isVacationPublished = true
                self?.savePublishStatus()
                self?.showToast("發佈排休成功！員工現在可以開始排休了", type: .success)

                // 🔥 發送通知給員工端
                NotificationCenter.default.post(
                    name: Notification.Name("VacationRulePublished"),
                    object: nil,
                    userInfo: [
                        "orgId": self?.currentOrgId ?? "",
                        "month": self?.currentDisplayMonth ?? ""
                    ]
                )
            }
        }
        .store(in: &cancellables)
    }

    func unpublishVacation() {
        print("🗑️ Boss 取消發佈排休...")

        // 🔥 設定同步狀態
        SyncStatusManager.shared.setSyncing()

        scheduleService.deleteVacationRule(orgId: currentOrgId, month: currentDisplayMonth)
            .sink { [weak self] completion in
                switch completion {
                case .failure(let error):
                    DispatchQueue.main.async {
                        print("❌ 取消發佈失敗: \(error)")
                        SyncStatusManager.shared.setSyncError()
                        self?.showToast("取消發佈失敗", type: .error)
                    }
                case .finished:
                    break
                }
            } receiveValue: { [weak self] in
                DispatchQueue.main.async {
                    print("✅ 取消發佈成功")
                    SyncStatusManager.shared.setSyncSuccess()
                    self?.isVacationPublished = false
                    self?.savePublishStatus()
                    self?.showToast("取消發佈成功", type: .warning)

                    // 🔥 通知員工端更新
                    NotificationCenter.default.post(
                        name: Notification.Name("VacationRuleUnpublished"),
                        object: nil,
                        userInfo: [
                            "orgId": self?.currentOrgId ?? "",
                            "month": self?.currentDisplayMonth ?? ""
                        ]
                    )
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Helpers

    var vacationStatusText: String {
        isVacationPublished ? "已發佈" : "未發佈"
    }

    var vacationStatusColor: Color {
        isVacationPublished ? .green : .orange
    }

    var scheduleStatusText: String {
        isSchedulePublished ? "已發佈" : "未發佈"
    }

    var scheduleStatusColor: Color {
        isSchedulePublished ? .green : .orange
    }

    // MARK: - Schedule Management

    /// 發佈班表
    func publishSchedule(_ scheduleData: ScheduleData) {
        print("📋 Boss 發佈班表: \(scheduleData.mode.displayName)")
        // TODO: 實作班表發佈到 Firebase
        DispatchQueue.main.async {
            self.isSchedulePublished = true
            self.savePublishStatus()
            self.showToast("班表發佈成功！", type: .success)
        }
    }

    /// 處理老闆操作
    func handleBossAction(_ action: BossAction) {
        print("👑 Boss 執行動作: \(action.displayName)")

        switch action {
        case .publishVacation:
            // 處理發佈休假設定
            break
        case .unpublishVacation:
            unpublishVacation()
        case .publishSchedule:
            // 處理發佈班表 (這個會在 View 中直接處理)
            break
        case .unpublishSchedule:
            unpublishSchedule()
        case .manageVacationLimits:
            // 處理管理休假限制 (這個會在 View 中直接處理)
            break
        default:
            break
        }
    }

    /// 取消發佈班表
    func unpublishSchedule() {
        print("📋 Boss 取消發佈班表")
        DispatchQueue.main.async {
            self.isSchedulePublished = false
            self.savePublishStatus()
            self.showToast("班表已取消發佈", type: .warning)
        }
    }

    // MARK: - 🔥 優化的本地存儲
    private func loadPublishStatus() {
        // 🔥 只處理合理的月份
        guard isReasonableMonth(currentDisplayMonth) else {
            print("🚫 Boss 跳過不合理月份的狀態載入: \(currentDisplayMonth)")
            return
        }

        let key = "BossPublishStatus_\(currentOrgId)_\(currentDisplayMonth)"

        if let data = UserDefaults.standard.data(forKey: key),
           let status = try? JSONDecoder().decode(BossPublishStatus.self, from: data) {
            isVacationPublished = status.vacationPublished
            isSchedulePublished = status.schedulePublished
            print("📱 Boss 載入本地狀態: 排休=\(isVacationPublished), 班表=\(isSchedulePublished)")
        } else {
            // fallback: check Firestore (但要避免過於頻繁)
            loadFromFirebaseWithThrottle()
        }
    }

    // 🔥 新增：節流的 Firebase 查詢
    private var lastFirebaseQuery: Date = Date.distantPast
    private func loadFromFirebaseWithThrottle() {
        let now = Date()

        // 限制 Firebase 查詢頻率（每3秒最多一次）
        guard now.timeIntervalSince(lastFirebaseQuery) >= 3.0 else {
            print("🚫 Boss Firebase 查詢過於頻繁，跳過")
            return
        }

        lastFirebaseQuery = now
        print("🔍 Boss 從 Firebase 檢查發佈狀態: \(currentDisplayMonth)")

        scheduleService.fetchVacationRule(orgId: currentOrgId, month: currentDisplayMonth)
            .replaceError(with: nil)
            .sink { [weak self] rule in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    let isPublished = rule?.published ?? false
                    self.isVacationPublished = isPublished
                    self.savePublishStatus()
                    print("☁️ Boss Firebase 狀態: 排休=\(isPublished), 月份=\(self.currentDisplayMonth)")
                }
            }
            .store(in: &cancellables)
    }

    private func savePublishStatus() {
        guard isReasonableMonth(currentDisplayMonth) else { return }

        let status = BossPublishStatus(
            vacationPublished: isVacationPublished,
            schedulePublished: isSchedulePublished,
            month: currentDisplayMonth,
            orgId: currentOrgId
        )
        let key = "BossPublishStatus_\(currentOrgId)_\(currentDisplayMonth)"
        if let encoded = try? JSONEncoder().encode(status) {
            UserDefaults.standard.set(encoded, forKey: key)
            print("💾 Boss 保存狀態: \(currentDisplayMonth)")
        }
    }

    func showToast(_ msg: String, type: ToastType) {
        toastMessage = msg
        toastType = type
        withAnimation { isToastShowing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + (type == .error ? 5 : 3)) {
            withAnimation { self.isToastShowing = false }
        }
    }
}
