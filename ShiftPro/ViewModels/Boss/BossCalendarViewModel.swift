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

    // MARK: - 🔥 新增：Firebase 狀態追蹤
    @Published var firebaseRule: FirestoreVacationRule?
    @Published var isFirebaseLoading = false
    @Published var lastSyncTime: Date?
    @Published var pendingPublications: Set<String> = []

    // MARK: - Dependencies
    private let scheduleService: ScheduleService
    private let storage: LocalStorageService
    private let userManager = UserManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 🔥 修復問題5：智能快取和監聽管理，Toast 控制
    private var firebaseListeners: [String: AnyCancellable] = [:]
    private var dataCache: [String: CachedBossData] = [:]
    private var isInitialized = false
    private var hasShownPublishToast: Set<String> = [] // 🔥 新增：控制發佈成功 Toast

    // MARK: - Computed Properties
    private var currentOrgId: String { userManager.currentOrgId }

    // MARK: - 🔥 優化：真實狀態從 Firebase 判斷
    var realVacationStatus: String {
        if let rule = firebaseRule {
            return rule.published ? "已發佈" : "已設定未發佈"
        } else {
            return "未設定"
        }
    }

    var realVacationStatusColor: Color {
        if let rule = firebaseRule {
            return rule.published ? .green : .orange
        } else {
            return .gray
        }
    }

    // MARK: - Init
    init(
        scheduleService: ScheduleService = .shared,
        storage: LocalStorageService = .shared
    ) {
        self.scheduleService = scheduleService
        self.storage = storage

        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        self.currentDisplayMonth = formatter.string(from: now)

        print("👑 Boss ViewModel 初始化")

        setupUserManager()

        // 延遲初始化避免啟動時過載
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isInitialized = true
            self.loadCurrentMonthData()
            self.setupNotificationListeners()
        }
    }

    deinit {
        print("🗑️ BossCalendarViewModel deinit")
        removeAllFirebaseListeners()
        cancellables.forEach { $0.cancel() }
    }

    // MARK: - 🔥 優化：用戶管理
    private func setupUserManager() {
        if !userManager.isLoggedIn {
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
    }

    private func handleUserChange() {
        removeAllFirebaseListeners()
        clearAllCache()
        if isInitialized {
            loadCurrentMonthData()
        }
    }

    // MARK: - 🔥 優化：月份更新
    func updateDisplayMonth(year: Int, month: Int) {
        guard isInitialized else { return }

        let newMonth = String(format: "%04d-%02d", year, month)
        guard isValidMonth(year: year, month: month) else { return }
        guard newMonth != currentDisplayMonth else { return }

        print("📅 Boss 更新月份: \(currentDisplayMonth) -> \(newMonth)")

        // 移除舊月份監聽
        removeFirebaseListener(for: currentDisplayMonth)

        currentDisplayMonth = newMonth

        // 🔥 修復問題5：重置發佈 Toast 狀態
        hasShownPublishToast.remove(newMonth)

        loadCurrentMonthData()
    }

    private func isValidMonth(year: Int, month: Int) -> Bool {
        let currentYear = Calendar.current.component(.year, from: Date())
        return year >= currentYear - 1 && year <= currentYear + 2 && month >= 1 && month <= 12
    }

    // MARK: - 🔥 優化：數據載入
    private func loadCurrentMonthData() {
        // 1. 檢查快取
        if let cached = dataCache[currentDisplayMonth],
           Date().timeIntervalSince(cached.timestamp) < 300 { // 5分鐘快取
            applyCachedData(cached)
            return
        }

        // 2. 載入本地狀態
        loadLocalStatus()

        // 3. 設置 Firebase 監聽
        setupFirebaseListener()
    }

    private func loadLocalStatus() {
        let key = "BossPublishStatus_\(currentOrgId)_\(currentDisplayMonth)"

        if let data = UserDefaults.standard.data(forKey: key),
           let status = try? JSONDecoder().decode(BossPublishStatus.self, from: data) {
            isVacationPublished = status.vacationPublished
            isSchedulePublished = status.schedulePublished
            print("📱 Boss 載入本地狀態: 排休=\(isVacationPublished)")
        }
    }

    // MARK: - 🔥 新增：Firebase 實時監聽
    private func setupFirebaseListener() {
        let listenerId = currentDisplayMonth

        let ruleListener = scheduleService.fetchVacationRule(orgId: currentOrgId, month: currentDisplayMonth)
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rule in
                self?.handleRuleUpdate(rule)
            }

        firebaseListeners[listenerId] = ruleListener
        print("👂 Boss 設置 Firebase 監聽: \(listenerId)")
    }

    // 🔥 修復問題5：優化規則更新處理，控制 Toast 顯示
    private func handleRuleUpdate(_ rule: FirestoreVacationRule?) {
        firebaseRule = rule

        if let r = rule {
            let wasPublished = isVacationPublished
            isVacationPublished = r.published

            // 更新模式
            currentVacationMode = VacationMode(rawValue: r.type) ?? .monthly

            // 🔥 修復問題5：只在真正變化且未顯示過時顯示通知
            if r.published && !wasPublished && !hasShownPublishToast.contains(currentDisplayMonth) {
                showToast("排休設定已發佈並同步", type: .success)
                hasShownPublishToast.insert(currentDisplayMonth)
            }
        } else {
            isVacationPublished = false
        }

        // 更新快取和本地狀態
        updateCache(rule: rule)
        savePublishStatus()
        lastSyncTime = Date()
        SyncStatusManager.shared.setSyncSuccess()
    }

    // MARK: - 🔥 優化：快取管理
    private struct CachedBossData {
        let rule: FirestoreVacationRule?
        let timestamp: Date
    }

    private func updateCache(rule: FirestoreVacationRule?) {
        dataCache[currentDisplayMonth] = CachedBossData(
            rule: rule,
            timestamp: Date()
        )

        // 限制快取大小
        if dataCache.count > 6 {
            let oldestKey = dataCache.min { $0.value.timestamp < $1.value.timestamp }?.key
            if let key = oldestKey {
                dataCache.removeValue(forKey: key)
            }
        }
    }

    private func applyCachedData(_ cached: CachedBossData) {
        handleRuleUpdate(cached.rule)
        print("📋 Boss 使用快取: \(currentDisplayMonth)")
    }

    private func clearAllCache() {
        dataCache.removeAll()
        firebaseRule = nil
        hasShownPublishToast.removeAll() // 🔥 修復問題5：清除發佈 Toast 記錄
    }

    // MARK: - 🔥 優化：Firebase 監聽管理
    private func removeFirebaseListener(for month: String) {
        firebaseListeners[month]?.cancel()
        firebaseListeners.removeValue(forKey: month)
        print("🔇 Boss 移除監聽: \(month)")
    }

    private func removeAllFirebaseListeners() {
        firebaseListeners.values.forEach { $0.cancel() }
        firebaseListeners.removeAll()
        print("🔇 Boss 移除所有監聽")
    }

    // MARK: - 🔥 優化：排休發佈
    func publishVacationSetting(_ setting: VacationSetting) {
        print("🚀 Boss 發佈排休設定...")
        print("   組織: \(currentOrgId)")
        print("   月份: \(currentDisplayMonth)")
        print("   類型: \(setting.type.rawValue)")
        print("   天數: \(setting.allowedDays)")

        // 標記為處理中
        pendingPublications.insert(currentDisplayMonth)
        isFirebaseLoading = true
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
            DispatchQueue.main.async {
                self?.isFirebaseLoading = false
                self?.pendingPublications.remove(self?.currentDisplayMonth ?? "")

                switch completion {
                case .failure(let error):
                    print("❌ Boss 發佈失敗: \(error)")
                    SyncStatusManager.shared.setSyncError()
                    self?.showToast("發佈失敗，請重試", type: .error)
                case .finished:
                    break
                }
            }
        } receiveValue: { [weak self] in
            DispatchQueue.main.async {
                print("✅ Boss 發佈成功！")
                SyncStatusManager.shared.setSyncSuccess()

                // 🔥 修復問題5：只在此處顯示成功通知，標記已顯示
                if let month = self?.currentDisplayMonth, ((self?.hasShownPublishToast.contains(month)) == nil) {
                    self?.showToast("發佈排休成功！員工現在可以開始排休了", type: .success)
                    self?.hasShownPublishToast.insert(month)
                }

                // 發送通知
                NotificationCenter.default.post(
                    name: Notification.Name("VacationRulePublished"),
                    object: nil,
                    userInfo: [
                        "orgId": self?.currentOrgId ?? "",
                        "month": self?.currentDisplayMonth ?? ""
                    ]
                )

                // 強制重新載入
                self?.forceReloadCurrentMonth()
            }
        }
        .store(in: &cancellables)
    }

    // MARK: - 🔥 優化：取消發佈
    func unpublishVacation() {
        print("🗑️ Boss 取消發佈排休...")

        isFirebaseLoading = true
        SyncStatusManager.shared.setSyncing()

        scheduleService.deleteVacationRule(orgId: currentOrgId, month: currentDisplayMonth)
            .sink { [weak self] completion in
                DispatchQueue.main.async {
                    self?.isFirebaseLoading = false

                    switch completion {
                    case .failure(let error):
                        print("❌ Boss 取消發佈失敗: \(error)")
                        SyncStatusManager.shared.setSyncError()
                        self?.showToast("取消發佈失敗", type: .error)
                    case .finished:
                        break
                    }
                }
            } receiveValue: { [weak self] in
                DispatchQueue.main.async {
                    print("✅ Boss 取消發佈成功")
                    SyncStatusManager.shared.setSyncSuccess()
                    self?.showToast("取消發佈成功", type: .warning)

                    // 🔥 修復問題5：重置發佈 Toast 狀態
                    if let month = self?.currentDisplayMonth {
                        self?.hasShownPublishToast.remove(month)
                    }

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
                    self?.savePublishStatus()

                    // 清除快取
                    self?.dataCache.removeValue(forKey: self?.currentDisplayMonth ?? "")
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - 🔥 新增：強制重新載入
    func forceReloadCurrentMonth() {
        print("🔄 Boss 強制重新載入: \(currentDisplayMonth)")
        dataCache.removeValue(forKey: currentDisplayMonth)
        setupFirebaseListener()
    }

    // MARK: - Schedule Management
    func publishSchedule(_ scheduleData: ScheduleData) {
        print("📋 Boss 發佈班表: \(scheduleData.mode.displayName)")

        isFirebaseLoading = true
        SyncStatusManager.shared.setSyncing()

        // 這裡可以擴展班表發佈邏輯
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isFirebaseLoading = false
            self.isSchedulePublished = true
            self.savePublishStatus()
            SyncStatusManager.shared.setSyncSuccess()
            self.showToast("班表發佈成功！", type: .success)
        }
    }

    func unpublishSchedule() {
        print("📋 Boss 取消發佈班表")

        isFirebaseLoading = true
        SyncStatusManager.shared.setSyncing()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isFirebaseLoading = false
            self.isSchedulePublished = false
            self.savePublishStatus()
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

    // MARK: - 🔥 優化：狀態屬性
    var vacationStatusText: String {
        if isFirebaseLoading && pendingPublications.contains(currentDisplayMonth) {
            return "發佈中..."
        }
        return realVacationStatus
    }

    var vacationStatusColor: Color {
        if isFirebaseLoading {
            return .blue
        }
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

    // MARK: - 🔥 優化：本地狀態管理
    private func savePublishStatus() {
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

    // MARK: - Toast Management
    func showToast(_ msg: String, type: ToastType) {
        toastMessage = msg
        toastType = type
        withAnimation { isToastShowing = true }

        let delay = type == .error ? 5.0 : 3.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation { self.isToastShowing = false }
        }
    }

    // MARK: - 🔥 新增：通知監聽
    private func setupNotificationListeners() {
        // 監聽設定頁面發佈通知
        NotificationCenter.default.addObserver(
            forName: Notification.Name("BossSettingsPublished"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let month = notification.userInfo?["month"] as? String,
               month == self?.currentDisplayMonth {
                print("📢 Boss 收到設定頁面發佈通知")
                self?.forceReloadCurrentMonth()
            }
        }
    }

    // MARK: - 🔥 新增：狀態查詢方法
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
}
