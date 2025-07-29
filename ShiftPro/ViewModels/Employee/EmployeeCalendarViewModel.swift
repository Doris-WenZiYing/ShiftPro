//
//  EmployeeCalendarViewModel.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/10.
//

import Foundation
import Combine
import SwiftUI

class EmployeeCalendarViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isVacationEditMode = false
    @Published var vacationData = VacationData()
    @Published var currentVacationMode: VacationMode = .monthly
    @Published var toastMessage = ""
    @Published var toastType: ToastType = .info
    @Published var isToastShowing = false
    @Published var isUsingBossSettings = false
    @Published var currentDisplayMonth: String
    @Published var isSubmissionMode = false

    // MARK: - 🔥 新增：Firebase 同步狀態
    @Published var firebaseSchedule: FirestoreEmployeeSchedule?
    @Published var firebaseRule: FirestoreVacationRule?
    @Published var isFirebaseLoading = false
    @Published var lastSyncTime: Date?

    // MARK: - Dependencies
    private let scheduleService: ScheduleService
    private let storage: LocalStorageService
    private let userManager = UserManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 🔥 修復數據丟失：每月獨立的數據管理
    private var monthlyVacationData: [String: VacationData] = [:]
    private var lastToastTime: Date = Date.distantPast
    private let toastCooldownInterval: TimeInterval = 2.0

    // 🔥 修復：狀態追蹤而非冷卻機制
    private var lastKnownBossSettingState: [String: Bool] = [:]

    // MARK: - 🔥 優化：智能快取與狀態管理
    private var firebaseListeners: [String: AnyCancellable] = [:]
    private var dataCache: [String: CachedEmployeeData] = [:]
    private var isInitialized = false

    // MARK: - Computed Properties
    private var currentOrgId: String { userManager.currentOrgId }
    private var currentEmployeeId: String { userManager.currentEmployeeId }

    // MARK: - Limits (從 Firebase 規則獲取)
    var availableVacationDays: Int {
        firebaseRule?.monthlyLimit ?? 8
    }

    var weeklyVacationLimit: Int {
        firebaseRule?.weeklyLimit ?? 2
    }

    // MARK: - 🔥 新增：真實提交狀態判斷
    var isReallySubmitted: Bool {
        guard let schedule = firebaseSchedule else { return false }
        return schedule.isSubmitted && !schedule.selectedDates.isEmpty
    }

    var canEditVacation: Bool {
        guard isUsingBossSettings else { return false }
        return !isReallySubmitted && canEditMonth()
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

        print("👤 Employee ViewModel 初始化")

        setupUserManager()

        // 🔥 修復：載入所有月份的本地數據
        loadAllMonthlyData()

        // 延遲初始化避免啟動時過載
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isInitialized = true
            self.loadCurrentMonthData()
            self.setupNotificationListeners()
        }
    }

    deinit {
        print("🗑️ EmployeeCalendarViewModel deinit")
        removeAllFirebaseListeners()
        cancellables.forEach { $0.cancel() }
    }

    // MARK: - 🔥 修復數據丟失：載入所有月份數據
    private func loadAllMonthlyData() {
        // 載入最近6個月的數據
        let calendar = Calendar.current
        let currentDate = Date()

        for offset in -3...3 {
            if let targetDate = calendar.date(byAdding: .month, value: offset, to: currentDate) {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM"
                let monthKey = formatter.string(from: targetDate)

                if let localData = storage.loadVacationData(month: monthKey) {
                    monthlyVacationData[monthKey] = localData
                    print("📱 載入 \(monthKey) 本地數據: \(localData.selectedDates.count) 天")
                }
            }
        }
    }

    // MARK: - 🔥 修復數據丟失：保存所有月份數據
    private func saveMonthlyData(_ data: VacationData, for month: String) {
        monthlyVacationData[month] = data
        storage.saveVacationData(data, month: month)
        print("💾 保存 \(month) 數據: \(data.selectedDates.count) 天")
    }

    // MARK: - 🔥 修復數據丟失：獲取特定月份數據
    private func getVacationData(for month: String) -> VacationData {
        if let data = monthlyVacationData[month] {
            return data
        }

        // 嘗試從本地載入
        if let localData = storage.loadVacationData(month: month) {
            monthlyVacationData[month] = localData
            return localData
        }

        // 創建新的空數據
        let newData = VacationData()
        monthlyVacationData[month] = newData
        return newData
    }

    // MARK: - 🔥 優化：用戶管理設置
    private func setupUserManager() {
        if !userManager.isLoggedIn {
            userManager.setCurrentEmployee(
                employeeId: "emp_1",
                employeeName: "測試員工",
                orgId: "demo_store_01",
                orgName: "Demo Store"
            )
        }

        // 監聽用戶變化
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

    // MARK: - 🔥 修復：月份更新時保持數據獨立性
    func updateDisplayMonth(year: Int, month: Int) {
        guard isInitialized else { return }

        let newMonth = String(format: "%04d-%02d", year, month)
        guard isValidMonth(year: year, month: month) else { return }

        // 🔥 修復：保存當前月份數據
        if currentDisplayMonth != newMonth {
            saveMonthlyData(vacationData, for: currentDisplayMonth)
        }

        guard newMonth != currentDisplayMonth else { return }

        print("📅 Employee 更新月份: \(currentDisplayMonth) -> \(newMonth)")

        // 移除舊月份監聽
        removeFirebaseListener(for: currentDisplayMonth)

        currentDisplayMonth = newMonth

        // 🔥 修復：載入新月份的獨立數據
        vacationData = getVacationData(for: newMonth)

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
           Date().timeIntervalSince(cached.timestamp) < 180 { // 3分鐘快取
            applyCachedData(cached)
            return
        }

        // 2. 確保載入當前月份的數據
        vacationData = getVacationData(for: currentDisplayMonth)

        // 3. 設置 Firebase 監聽
        setupFirebaseListeners()
    }

    // MARK: - 🔥 修復：Firebase 實時監聽
    private func setupFirebaseListeners() {
        let listenerId = currentDisplayMonth

        let rulePublisher = scheduleService.fetchVacationRule(orgId: currentOrgId, month: currentDisplayMonth)
            .replaceError(with: nil)

        let schedulePublisher = scheduleService.observeEmployeeSchedule(
            orgId: currentOrgId,
            employeeId: currentEmployeeId,
            month: currentDisplayMonth
        )
        .replaceError(with: nil)

        // 組合監聽器
        let combinedListener = Publishers.CombineLatest(rulePublisher, schedulePublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (rule, schedule) in
                self?.handleRuleUpdate(rule)
                self?.handleScheduleUpdate(schedule)
                self?.updateCache(rule: rule, schedule: schedule)
                self?.lastSyncTime = Date()
                SyncStatusManager.shared.setSyncSuccess()
            }

        firebaseListeners[listenerId] = combinedListener
        print("👂 Employee 設置 Firebase 監聽: \(listenerId)")
    }

    // 🔥 修復：老闆設定狀態更新處理
    private func handleRuleUpdate(_ rule: FirestoreVacationRule?) {
        firebaseRule = rule
        let monthKey = currentDisplayMonth

        if let r = rule {
            let newBossSettingState = r.published
            let lastKnownState = lastKnownBossSettingState[monthKey]

            currentVacationMode = VacationMode(rawValue: r.type) ?? .monthly
            isUsingBossSettings = newBossSettingState

            // 🔥 只在老闆新發佈設定時顯示通知
            if newBossSettingState {
                // 只有在已經記錄過狀態且狀態確實發生變化時才顯示
                if let lastState = lastKnownState, !lastState {
                    showToastWithCooldown("老闆發佈了 \(getMonthDisplayText()) 的排休設定！", type: .success)
                }
            }

            // 更新記錄的狀態
            lastKnownBossSettingState[monthKey] = newBossSettingState
        } else {
            isUsingBossSettings = false
            lastKnownBossSettingState[monthKey] = false
        }
    }

    // 🔥 修復數據丟失：處理 Firebase 排班更新時保持數據獨立性
    private func handleScheduleUpdate(_ schedule: FirestoreEmployeeSchedule?) {
        firebaseSchedule = schedule

        if let s = schedule, s.month == currentDisplayMonth {
            // 🔥 關鍵修復：只更新當前顯示月份的數據
            var newData = VacationData()
            newData.selectedDates = Set(s.selectedDates)
            newData.isSubmitted = s.isSubmitted
            newData.currentMonth = s.month

            // 只在真正不同時更新
            if vacationData.selectedDates != newData.selectedDates ||
               vacationData.isSubmitted != newData.isSubmitted {
                vacationData = newData
                saveMonthlyData(newData, for: currentDisplayMonth)
                print("📊 Employee Firebase 排班更新: \(currentDisplayMonth) - \(s.selectedDates.count)天, 提交=\(s.isSubmitted)")
            }
        }
    }

    // MARK: - 🔥 優化：快取管理
    private struct CachedEmployeeData {
        let rule: FirestoreVacationRule?
        let schedule: FirestoreEmployeeSchedule?
        let timestamp: Date
    }

    private func updateCache(rule: FirestoreVacationRule?, schedule: FirestoreEmployeeSchedule?) {
        dataCache[currentDisplayMonth] = CachedEmployeeData(
            rule: rule,
            schedule: schedule,
            timestamp: Date()
        )

        // 限制快取大小
        if dataCache.count > 5 {
            let oldestKey = dataCache.min { $0.value.timestamp < $1.value.timestamp }?.key
            if let key = oldestKey {
                dataCache.removeValue(forKey: key)
            }
        }
    }

    private func applyCachedData(_ cached: CachedEmployeeData) {
        handleRuleUpdate(cached.rule)
        handleScheduleUpdate(cached.schedule)
        print("📋 Employee 使用快取: \(currentDisplayMonth)")
    }

    private func clearAllCache() {
        dataCache.removeAll()
        firebaseRule = nil
        firebaseSchedule = nil
        lastKnownBossSettingState.removeAll()
    }

    // MARK: - 🔥 優化：Firebase 監聽管理
    private func removeFirebaseListener(for month: String) {
        firebaseListeners[month]?.cancel()
        firebaseListeners.removeValue(forKey: month)
        print("🔇 Employee 移除監聽: \(month)")
    }

    private func removeAllFirebaseListeners() {
        firebaseListeners.values.forEach { $0.cancel() }
        firebaseListeners.removeAll()
        print("🔇 Employee 移除所有監聽")
    }

    // MARK: - 🔥 優化：排休操作
    func handleVacationAction(_ action: ShiftAction) {
        switch action {
        case .editVacation:
            guard canEditVacation else {
                if !isUsingBossSettings {
                    showToastWithCooldown("等待老闆發佈 \(getMonthDisplayText()) 的排休設定", type: .info)
                } else if isReallySubmitted {
                    showToastWithCooldown("本月排休已提交，無法修改", type: .error)
                } else {
                    showToastWithCooldown("無法編輯此月份", type: .error)
                }
                return
            }

            // 進入排休編輯模式
            isSubmissionMode = true

        case .clearVacation:
            clearAllVacationData()
        }
    }

    func enterEditMode() {
        guard canEditVacation else { return }
        withAnimation { isVacationEditMode = true }
    }

    func exitEditMode() {
        withAnimation {
            isVacationEditMode = false
            isSubmissionMode = false
        }
    }

    // MARK: - 🔥 優化：排休提交
    func submitVacation() {
        print("📝 Employee 提交排休...")

        guard !vacationData.selectedDates.isEmpty else {
            showToastWithCooldown("請先選擇排休日期", type: .error)
            return
        }

        // 週限制檢查
        if currentVacationMode != .monthly {
            let stats = WeekUtils.weeklyStats(for: vacationData.selectedDates, in: currentDisplayMonth)
            if stats.values.contains(where: { $0 > weeklyVacationLimit }) {
                showToastWithCooldown("請檢查週休限制，每週最多可排 \(weeklyVacationLimit) 天", type: .error)
                return
            }
        }

        isFirebaseLoading = true
        SyncStatusManager.shared.setSyncing()

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dates = Array(vacationData.selectedDates).compactMap { dateFormatter.date(from: $0) }

        scheduleService.updateEmployeeSchedule(
            orgId: currentOrgId,
            employeeId: currentEmployeeId,
            month: currentDisplayMonth,
            dates: dates
        )
        .flatMap { [weak self] _ in
            guard let self = self else {
                return Empty<Void, Error>().eraseToAnyPublisher()
            }
            return self.scheduleService.submitEmployeeSchedule(
                orgId: self.currentOrgId,
                employeeId: self.currentEmployeeId,
                month: self.currentDisplayMonth
            )
        }
        .sink(
            receiveCompletion: { [weak self] completion in
                DispatchQueue.main.async {
                    self?.isFirebaseLoading = false
                    switch completion {
                    case .failure(let error):
                        print("❌ Employee 提交失敗: \(error)")
                        SyncStatusManager.shared.setSyncError()
                        self?.showToastWithCooldown("提交失敗，請重試", type: .error)
                    case .finished:
                        break
                    }
                }
            },
            receiveValue: { [weak self] in
                DispatchQueue.main.async {
                    print("✅ Employee 提交成功！")
                    SyncStatusManager.shared.setSyncSuccess()
                    self?.showToastWithCooldown("排休已成功提交！", type: .success)

                    // 🔥 修復：提交成功後更新當前月份數據狀態
                    if let self = self {
                        var updatedData = self.vacationData
                        updatedData.isSubmitted = true
                        self.vacationData = updatedData
                        self.saveMonthlyData(updatedData, for: self.currentDisplayMonth)
                    }

                    // 退出編輯模式
                    self?.exitEditMode()

                    // 清除快取強制重新載入
                    if let month = self?.currentDisplayMonth {
                        self?.dataCache.removeValue(forKey: month)
                    }
                }
            }
        )
        .store(in: &cancellables)
    }

    // MARK: - 🔥 修復：完整清除排休資料
    func clearAllVacationData() {
        print("🗑️ Employee 清除所有排休資料: \(currentDisplayMonth)")

        isFirebaseLoading = true
        SyncStatusManager.shared.setSyncing()

        // 1. 清除本地資料
        let emptyData = VacationData()
        vacationData = emptyData
        saveMonthlyData(emptyData, for: currentDisplayMonth)

        // 2. 清除快取
        dataCache.removeValue(forKey: currentDisplayMonth)

        // 3. 刪除 Firebase 資料
        let docId = "\(currentOrgId)_\(currentEmployeeId)_\(currentDisplayMonth)"

        let firebaseService = FirebaseService.shared
        firebaseService.deleteDocument(
            collection: "employee_schedules",
            document: docId
        )
        .sink(
            receiveCompletion: { [weak self] completion in
                DispatchQueue.main.async {
                    self?.isFirebaseLoading = false
                    switch completion {
                    case .failure(let error):
                        print("❌ Employee 清除失敗: \(error)")
                        SyncStatusManager.shared.setSyncError()
                        self?.showToastWithCooldown("清除失敗，請重試", type: .error)
                    case .finished:
                        break
                    }
                }
            },
            receiveValue: { [weak self] in
                DispatchQueue.main.async {
                    print("✅ Employee Firebase 資料已清除")
                    SyncStatusManager.shared.setSyncSuccess()
                    self?.showToastWithCooldown("排休資料已完全清除", type: .info)

                    // 重置狀態
                    self?.firebaseSchedule = nil
                    self?.exitEditMode()
                }
            }
        )
        .store(in: &cancellables)
    }

    // MARK: - 新增帶 Toast 的清除方法
    func clearAllVacationDataWithToast() {
        let emptyData = VacationData()
        vacationData = emptyData
        saveMonthlyData(emptyData, for: currentDisplayMonth)
        showToastWithCooldown("已清除所有選擇", type: .info)
    }

    // MARK: - 🔥 優化：日期選擇邏輯
    func toggleVacationDate(_ dateString: String, showToast: Bool = false) {
        guard canEditVacation else {
            if showToast {
                showToastWithCooldown("無法編輯排休", type: .error)
            }
            return
        }

        var data = vacationData

        if data.selectedDates.contains(dateString) {
            data.selectedDates.remove(dateString)
            apply(data, message: nil, type: .info)
            return
        }

        // 月上限檢查
        if data.selectedDates.count >= availableVacationDays {
            showToastWithCooldown("已達到本月可排休上限 \(availableVacationDays) 天", type: .error)
            return
        }

        // 週上限檢查
        if currentVacationMode != .monthly {
            let week = WeekUtils.weekIndex(of: dateString, in: currentDisplayMonth)
            let used = WeekUtils.count(in: data.selectedDates, week: week)
            if used >= weeklyVacationLimit {
                showToastWithCooldown("已超過第\(week)週最多可排 \(weeklyVacationLimit) 天", type: .weeklyLimit)
                return
            }
        }

        data.selectedDates.insert(dateString)
        apply(data, successDate: nil)
    }

    func canSelect(day: Int) -> Bool {
        let dateString = String(format: "%@-%02d", currentDisplayMonth, day)

        if vacationData.selectedDates.count >= availableVacationDays &&
           !vacationData.selectedDates.contains(dateString) {
            return false
        }

        if currentVacationMode != .monthly {
            let week = WeekUtils.weekIndex(of: dateString, in: currentDisplayMonth)
            let used = WeekUtils.count(in: vacationData.selectedDates, week: week)
            return vacationData.selectedDates.contains(dateString) || used < weeklyVacationLimit
        }

        return true
    }

    // MARK: - Helper Methods
    func dateToString(_ date: CalendarDate) -> String {
        String(format: "%04d-%02d-%02d", date.year, date.month, date.day)
    }

    func getMonthDisplayText() -> String {
        let currentFormatter = DateFormatter()
        currentFormatter.dateFormat = "yyyy-MM"
        let thisMonth = currentFormatter.string(from: Date())

        if currentDisplayMonth == thisMonth {
            return "本月"
        } else {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy年MM月"
            if let date = currentFormatter.date(from: currentDisplayMonth) {
                return displayFormatter.string(from: date)
            }
            return currentDisplayMonth
        }
    }

    func canEditMonth() -> Bool {
        let currentFormatter = DateFormatter()
        currentFormatter.dateFormat = "yyyy-MM"
        let currentMonth = currentFormatter.string(from: Date())
        return currentDisplayMonth >= currentMonth
    }

    func isFutureMonth() -> Bool {
        let currentFormatter = DateFormatter()
        currentFormatter.dateFormat = "yyyy-MM"
        let currentMonth = currentFormatter.string(from: Date())
        return currentDisplayMonth > currentMonth
    }

    // MARK: - Toast 控制方法
    func showToast(_ msg: String, type: ToastType) {
        toastMessage = msg
        toastType = type
        withAnimation { isToastShowing = true }

        let delay = type == .error ? 5.0 : 3.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation { self.isToastShowing = false }
        }
    }

    private func showToastWithCooldown(_ msg: String, type: ToastType) {
        let now = Date()
        guard now.timeIntervalSince(lastToastTime) >= toastCooldownInterval else {
            print("🔇 Toast 冷卻中，跳過顯示: \(msg)")
            return
        }

        lastToastTime = now
        showToast(msg, type: type)
    }

    // MARK: - Private Methods
    private func apply(
        _ data: VacationData,
        message: String? = nil,
        type: ToastType = .info,
        successDate: String? = nil
    ) {
        vacationData = data
        saveMonthlyData(data, for: currentDisplayMonth)

        if let msg = message {
            showToastWithCooldown(msg, type: type)
        }

        if let dateString = successDate {
            showSuccessMessage(for: dateString)
        }
    }

    private func showSuccessMessage(for dateString: String) {
        let remaining = availableVacationDays - vacationData.selectedDates.count

        if currentVacationMode != .monthly {
            let week = WeekUtils.weekIndex(of: dateString, in: currentDisplayMonth)
            let used = WeekUtils.count(in: vacationData.selectedDates, week: week)
            let weekRemaining = weeklyVacationLimit - used
            showToastWithCooldown("排休成功！剩餘 \(remaining) 天，週剩餘 \(weekRemaining) 天", type: .weeklySuccess)
        } else {
            showToastWithCooldown("排休成功！剩餘 \(remaining) 天", type: .success)
        }
    }

    // MARK: - 🔥 修復：通知監聽優化
    private func setupNotificationListeners() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("VacationRulePublished"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let orgId = notification.userInfo?["orgId"] as? String,
               let month = notification.userInfo?["month"] as? String,
               orgId == self?.currentOrgId,
               month == self?.currentDisplayMonth {
                print("📢 Employee 收到發佈通知")

                // 🔥 收到外部通知時，可以顯示提示（但要檢查是否為重複）
                if let self = self {
                    let monthKey = self.currentDisplayMonth
                    let lastState = self.lastKnownBossSettingState[monthKey] ?? false
                    if !lastState {
                        self.showToastWithCooldown("收到新的排休設定！", type: .info)
                    }
                }

                self?.setupFirebaseListeners()
            }
        }

        NotificationCenter.default.addObserver(
            forName: Notification.Name("VacationRuleUnpublished"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let orgId = notification.userInfo?["orgId"] as? String,
               let month = notification.userInfo?["month"] as? String,
               orgId == self?.currentOrgId,
               month == self?.currentDisplayMonth {
                print("📢 Employee 收到取消發佈通知")
                self?.isUsingBossSettings = false

                // 更新狀態記錄
                if let self = self {
                    let monthKey = self.currentDisplayMonth
                    self.lastKnownBossSettingState[monthKey] = false
                }

                self?.showToastWithCooldown("老闆已取消發佈排休設定", type: .warning)
            }
        }
    }
}
