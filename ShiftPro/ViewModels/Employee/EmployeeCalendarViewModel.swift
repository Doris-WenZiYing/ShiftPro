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

    // MARK: - 🔥 優化：用戶管理設置
    private func setupUserManager() {
        if !userManager.isLoggedIn {
            userManager.setCurrentEmployee(
                employeeId: "emp_001",
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

    // MARK: - 🔥 優化：月份更新
    func updateDisplayMonth(year: Int, month: Int) {
        guard isInitialized else { return }

        let newMonth = String(format: "%04d-%02d", year, month)
        guard isValidMonth(year: year, month: month) else { return }
        guard newMonth != currentDisplayMonth else { return }

        print("📅 Employee 更新月份: \(currentDisplayMonth) -> \(newMonth)")

        // 移除舊月份監聽
        removeFirebaseListener(for: currentDisplayMonth)

        currentDisplayMonth = newMonth
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

        // 2. 載入本地資料
        loadLocalData()

        // 3. 設置 Firebase 監聽
        setupFirebaseListeners()
    }

    private func loadLocalData() {
        if let local = storage.loadVacationData(month: currentDisplayMonth) {
            vacationData = local
            print("📱 Employee 載入本地資料: \(currentDisplayMonth)")
        } else {
            vacationData = VacationData()
        }
    }

    // MARK: - 🔥 修復：Firebase 實時監聽
    private func setupFirebaseListeners() {
        let listenerId = currentDisplayMonth

        // 🔥 修復：正確的 Publishers.CombineLatest 使用
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

    private func handleRuleUpdate(_ rule: FirestoreVacationRule?) {
        firebaseRule = rule

        if let r = rule {
            currentVacationMode = VacationMode(rawValue: r.type) ?? .monthly
            let wasUsingBossSettings = isUsingBossSettings
            isUsingBossSettings = r.published

            // 只在真正變化時顯示通知
            if r.published && !wasUsingBossSettings {
                showToast("老闆發佈了 \(getMonthDisplayText()) 的排休設定！", type: .success)
            }
        } else {
            isUsingBossSettings = false
        }
    }

    private func handleScheduleUpdate(_ schedule: FirestoreEmployeeSchedule?) {
        firebaseSchedule = schedule

        if let s = schedule {
            // 🔥 關鍵：以 Firebase 資料為準
            var newData = VacationData()
            newData.selectedDates = Set(s.selectedDates)
            newData.isSubmitted = s.isSubmitted
            newData.currentMonth = s.month

            // 只在真正不同時更新
            if vacationData.selectedDates != newData.selectedDates ||
               vacationData.isSubmitted != newData.isSubmitted {
                vacationData = newData
                storage.saveVacationData(newData, month: currentDisplayMonth)
                print("📊 Employee Firebase 排班更新: \(s.selectedDates.count)天, 提交=\(s.isSubmitted)")
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
                    showToast("等待老闆發佈 \(getMonthDisplayText()) 的排休設定", type: .info)
                } else if isReallySubmitted {
                    showToast("本月排休已提交，無法修改", type: .error)
                } else {
                    showToast("無法編輯此月份", type: .error)
                }
                return
            }

            // 🔥 新增：進入排休編輯模式
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
            showToast("請先選擇排休日期", type: .error)
            return
        }

        // 週限制檢查
        if currentVacationMode != .monthly {
            let stats = WeekUtils.weeklyStats(for: vacationData.selectedDates, in: currentDisplayMonth)
            if stats.values.contains(where: { $0 > weeklyVacationLimit }) {
                showToast("請檢查週休限制，每週最多可排 \(weeklyVacationLimit) 天", type: .error)
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
                        self?.showToast("提交失敗，請重試", type: .error)
                    case .finished:
                        break
                    }
                }
            },
            receiveValue: { [weak self] in
                DispatchQueue.main.async {
                    print("✅ Employee 提交成功！")
                    SyncStatusManager.shared.setSyncSuccess()
                    self?.showToast("排休已成功提交！", type: .success)

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
        vacationData = VacationData()
        storage.clearVacationData(month: currentDisplayMonth)

        // 2. 清除快取
        dataCache.removeValue(forKey: currentDisplayMonth)

        // 3. 刪除 Firebase 資料
        let docId = "\(currentOrgId)_\(currentEmployeeId)_\(currentDisplayMonth)"

        // 🔥 修復：正確的 Firebase Service 使用
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
                        self?.showToast("清除失敗，請重試", type: .error)
                    case .finished:
                        break
                    }
                }
            },
            receiveValue: { [weak self] in
                DispatchQueue.main.async {
                    print("✅ Employee Firebase 資料已清除")
                    SyncStatusManager.shared.setSyncSuccess()
                    self?.showToast("排休資料已完全清除", type: .info)

                    // 重置狀態
                    self?.firebaseSchedule = nil
                    self?.exitEditMode()
                }
            }
        )
        .store(in: &cancellables)
    }

    // MARK: - 🔥 優化：日期選擇邏輯
    func toggleVacationDate(_ dateString: String) {
        guard canEditVacation else {
            showToast("無法編輯排休", type: .error)
            return
        }

        var data = vacationData

        if data.selectedDates.contains(dateString) {
            data.selectedDates.remove(dateString)
            apply(data, message: "已取消排休", type: .info)
            return
        }

        // 月上限檢查
        if data.selectedDates.count >= availableVacationDays {
            showToast("已達到本月可排休上限 \(availableVacationDays) 天", type: .error)
            return
        }

        // 週上限檢查
        if currentVacationMode != .monthly {
            let week = WeekUtils.weekIndex(of: dateString, in: currentDisplayMonth)
            let used = WeekUtils.count(in: data.selectedDates, week: week)
            if used >= weeklyVacationLimit {
                showToast("已超過第\(week)週最多可排 \(weeklyVacationLimit) 天", type: .weeklyLimit)
                return
            }
        }

        data.selectedDates.insert(dateString)
        apply(data, successDate: dateString)
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

    func showToast(_ msg: String, type: ToastType) {
        toastMessage = msg
        toastType = type
        withAnimation { isToastShowing = true }

        let delay = type == .error ? 5.0 : 3.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation { self.isToastShowing = false }
        }
    }

    // MARK: - Private Methods
    private func apply(
        _ data: VacationData,
        message: String? = nil,
        type: ToastType = .info,
        successDate: String? = nil
    ) {
        vacationData = data
        storage.saveVacationData(data, month: currentDisplayMonth)

        if let msg = message {
            showToast(msg, type: type)
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
            showToast("排休成功！剩餘 \(remaining) 天，週剩餘 \(weekRemaining) 天", type: .weeklySuccess)
        } else {
            showToast("排休成功！剩餘 \(remaining) 天", type: .success)
        }
    }

    // MARK: - 🔥 新增：通知監聽
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
                self?.setupFirebaseListeners() // 重新設置監聽
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
                self?.showToast("老闆已取消發佈排休設定", type: .warning)
            }
        }
    }
}
