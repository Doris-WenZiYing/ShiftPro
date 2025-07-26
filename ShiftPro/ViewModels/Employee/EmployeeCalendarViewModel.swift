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
    // MARK: - Published
    @Published var isVacationEditMode = false
    @Published var vacationData = VacationData()
    @Published var currentVacationMode: VacationMode = .monthly
    @Published var toastMessage = ""
    @Published var toastType: ToastType = .info
    @Published var isToastShowing = false
    @Published var isUsingBossSettings = false
    @Published var currentDisplayMonth: String

    // MARK: - Dependencies
    private let scheduleService: ScheduleService
    private let storage: LocalStorageService
    private let userManager = UserManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Limits
    private(set) var availableVacationDays = 8
    private(set) var weeklyVacationLimit = 2

    // MARK: - 🔥 優化：智能快取系統
    private var dataCache: [String: CachedMonthData] = [:]
    private var isLoading = false
    private var vacationRuleListener: AnyCancellable?

    // MARK: - 🔥 優化：月份管理
    private var userVisibleMonth: String = ""
    private var isInitialized = false
    private var lastSyncTime: Date = Date()

    // MARK: - Real Data Properties
    private var currentOrgId: String {
        userManager.currentOrgId
    }

    private var currentEmployeeId: String {
        userManager.currentEmployeeId
    }

    // MARK: - Init
    init(
        scheduleService: ScheduleService = .shared,
        storage: LocalStorageService = .shared
    ) {
        self.scheduleService = scheduleService
        self.storage = storage

        // 🔥 修復：使用正確的日期格式初始化
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        self.currentDisplayMonth = formatter.string(from: now)
        self.userVisibleMonth = self.currentDisplayMonth

        print("🎯 Employee 初始化 EmployeeCalendarViewModel")
        print("   - 初始月份: \(currentDisplayMonth)")
        print("   - 組織ID: \(currentOrgId)")
        print("   - 員工ID: \(currentEmployeeId)")

        // 如果沒有登入，設定預設身分
        if !userManager.isLoggedIn {
            setupDefaultEmployee()
        }

        // 🔥 優化：延遲初始化，避免啟動時的大量查詢
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isInitialized = true
            self.loadCurrentMonthData()
            self.setupVacationRuleListener()
            self.setupNotificationListeners()
        }

        // 🔥 監聽用戶身分變化
        userManager.$currentUser
            .sink { [weak self] _ in
                self?.clearAllCache()
                if self?.isInitialized == true {
                    self?.loadCurrentMonthData()
                    self?.setupVacationRuleListener()
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        print("🗑️ EmployeeCalendarViewModel deinit")
        cancellables.forEach { $0.cancel() }
        vacationRuleListener?.cancel()
    }

    // MARK: - Setup Default Employee
    private func setupDefaultEmployee() {
        userManager.setCurrentEmployee(
            employeeId: "emp_001",
            employeeName: "測試員工",
            orgId: "demo_store_01",
            orgName: "Demo Store"
        )
        print("👤 設定預設員工身分")
    }

    // MARK: - 🔥 優化：智能月份更新
    func updateDisplayMonth(year: Int, month: Int) {
        guard isInitialized else {
            print("⏳ Employee 等待初始化完成")
            return
        }

        let newMonth = String(format: "%04d-%02d", year, month)

        // 🔥 基本驗證
        guard isValidMonth(year: year, month: month) else {
            print("🚫 Employee 忽略無效月份: \(year)-\(month)")
            return
        }

        // 🔥 只處理真正的變化
        guard newMonth != currentDisplayMonth else {
            print("📅 Employee 月份相同，跳過: \(newMonth)")
            return
        }

        print("📅 Employee 月份更新: \(currentDisplayMonth) -> \(newMonth)")
        currentDisplayMonth = newMonth
        userVisibleMonth = newMonth

        // 🔥 智能載入：檢查快取或載入新資料
        loadMonthDataSmart(month: newMonth)
    }

    private func isValidMonth(year: Int, month: Int) -> Bool {
        let currentYear = Calendar.current.component(.year, from: Date())
        return year >= currentYear - 1 &&
               year <= currentYear + 2 &&
               month >= 1 &&
               month <= 12
    }

    // MARK: - 🔥 優化：智能資料載入
    private func loadMonthDataSmart(month: String) {
        // 1. 檢查快取
        if let cached = dataCache[month],
           Date().timeIntervalSince(cached.timestamp) < 300 { // 5分鐘快取
            print("📋 Employee 使用快取: \(month)")
            applyCached(cached)
            return
        }

        // 2. 載入本地資料
        loadLocalCache()

        // 3. 只為當前用戶可見月份查詢 Firebase
        if month == userVisibleMonth {
            loadFromFirebase(month: month)
        }
    }

    private func loadFromFirebase(month: String) {
        guard !isLoading else { return }

        isLoading = true
        lastSyncTime = Date()
        SyncStatusManager.shared.setSyncing()

        print("📊 Employee 從 Firebase 載入: \(month)")

        let vacationRulePublisher = scheduleService.fetchVacationRule(orgId: currentOrgId, month: month)
            .replaceError(with: nil)

        let employeeSchedulePublisher = scheduleService.fetchEmployeeSchedule(
            orgId: currentOrgId,
            employeeId: currentEmployeeId,
            month: month
        )
        .replaceError(with: nil)

        Publishers.CombineLatest(vacationRulePublisher, employeeSchedulePublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (rule, schedule) in
                guard let self = self else { return }

                self.isLoading = false
                SyncStatusManager.shared.setSyncSuccess()

                // 處理休假規則
                if let r = rule {
                    self.availableVacationDays = r.monthlyLimit ?? 8
                    self.weeklyVacationLimit = r.weeklyLimit ?? 2
                    self.currentVacationMode = VacationMode(rawValue: r.type) ?? .monthly
                    self.isUsingBossSettings = r.published
                } else {
                    self.isUsingBossSettings = false
                }

                // 處理員工排班
                if let s = schedule {
                    var data = VacationData()
                    data.selectedDates = Set(s.selectedDates)
                    data.isSubmitted = s.isSubmitted
                    data.currentMonth = s.month
                    self.vacationData = data
                    self.storage.saveVacationData(data, month: month)
                }

                // 🔥 更新快取
                self.updateCache(month: month, rule: rule, schedule: schedule)

                print("✅ Employee Firebase 載入完成: \(month)")
            }
            .store(in: &cancellables)
    }

    // MARK: - 🔥 智能快取系統
    private struct CachedMonthData {
        let rule: FirestoreVacationRule?
        let schedule: FirestoreEmployeeSchedule?
        let timestamp: Date
    }

    private func updateCache(month: String, rule: FirestoreVacationRule?, schedule: FirestoreEmployeeSchedule?) {
        dataCache[month] = CachedMonthData(
            rule: rule,
            schedule: schedule,
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

    private func applyCached(_ cached: CachedMonthData) {
        if let rule = cached.rule {
            availableVacationDays = rule.monthlyLimit ?? 8
            weeklyVacationLimit = rule.weeklyLimit ?? 2
            currentVacationMode = VacationMode(rawValue: rule.type) ?? .monthly
            isUsingBossSettings = rule.published
        } else {
            isUsingBossSettings = false
        }

        if let schedule = cached.schedule {
            var data = VacationData()
            data.selectedDates = Set(schedule.selectedDates)
            data.isSubmitted = schedule.isSubmitted
            data.currentMonth = schedule.month
            vacationData = data
        } else {
            loadLocalCache()
        }
    }

    // MARK: - 🔥 優化：實時監聽休假規則
    private func setupVacationRuleListener() {
        vacationRuleListener?.cancel()

        print("👂 Employee 監聽休假規則: \(currentOrgId)_\(currentDisplayMonth)")

        vacationRuleListener = scheduleService.fetchVacationRule(orgId: currentOrgId, month: currentDisplayMonth)
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rule in
                guard let self = self else { return }

                if let r = rule {
                    let wasUsingBossSettings = self.isUsingBossSettings
                    self.availableVacationDays = r.monthlyLimit ?? 8
                    self.weeklyVacationLimit = r.weeklyLimit ?? 2
                    self.currentVacationMode = VacationMode(rawValue: r.type) ?? .monthly
                    self.isUsingBossSettings = r.published

                    // 🔥 只在狀態真正改變時顯示通知
                    if r.published && !wasUsingBossSettings {
                        self.showToast("老闆已發佈 \(self.getMonthDisplayText()) 的排休設定！", type: .success)
                    }
                } else {
                    self.isUsingBossSettings = false
                }
            }
    }

    // MARK: - 🔥 通知監聽器
    private func setupNotificationListeners() {
        // 監聽發佈通知
        NotificationCenter.default.addObserver(
            forName: Notification.Name("VacationRulePublished"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let orgId = notification.userInfo?["orgId"] as? String,
                  let month = notification.userInfo?["month"] as? String,
                  orgId == self.currentOrgId,
                  month == self.currentDisplayMonth else { return }

            print("📢 Employee 收到發佈通知")
            self.reloadCurrentMonth()
        }

        // 監聽取消發佈通知
        NotificationCenter.default.addObserver(
            forName: Notification.Name("VacationRuleUnpublished"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let orgId = notification.userInfo?["orgId"] as? String,
                  let month = notification.userInfo?["month"] as? String,
                  orgId == self.currentOrgId,
                  month == self.currentDisplayMonth else { return }

            print("📢 Employee 收到取消發佈通知")
            self.isUsingBossSettings = false
            self.showToast("老闆已取消發佈排休設定", type: .warning)
        }
    }

    // MARK: - Cache Management
    func clearAllCache() {
        dataCache.removeAll()
        isLoading = false
        print("🗑️ Employee 已清除所有快取")
    }

    func reloadCurrentMonth() {
        dataCache.removeValue(forKey: currentDisplayMonth)
        loadMonthDataSmart(month: currentDisplayMonth)
        print("🔄 Employee 重新載入當前月份: \(currentDisplayMonth)")
    }

    // MARK: - 🔥 修復：清除當前月份的所有資料
    func clearCurrentMonthData() {
        print("🗑️ Employee 清除當前月份所有資料: \(currentDisplayMonth)")

        // 1. 清除本地資料
        vacationData = VacationData()
        storage.clearVacationData(month: currentDisplayMonth)

        // 2. 清除快取
        dataCache.removeValue(forKey: currentDisplayMonth)

        // 3. 清除 Firebase 資料
        SyncStatusManager.shared.setSyncing()

        scheduleService.updateEmployeeSchedule(
            orgId: currentOrgId,
            employeeId: currentEmployeeId,
            month: currentDisplayMonth,
            dates: []
        )
        .sink(
            receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    DispatchQueue.main.async {
                        print("❌ Employee 清除失敗: \(error)")
                        SyncStatusManager.shared.setSyncError()
                    }
                case .finished:
                    break
                }
            },
            receiveValue: { [weak self] in
                DispatchQueue.main.async {
                    SyncStatusManager.shared.setSyncSuccess()
                    self?.showToast("當前月份排休資料已完全清除", type: .info)
                }
            }
        )
        .store(in: &cancellables)
    }

    // MARK: - Vacation Actions
    func handleVacationAction(_ action: ShiftAction) {
        switch action {
        case .editVacation:
            guard !vacationData.isSubmitted else {
                showToast("本月排休已提交，無法修改", type: .error)
                return
            }
            guard isUsingBossSettings else {
                showToast("等待老闆發佈 \(getMonthDisplayText()) 的排休設定", type: .info)
                return
            }
            withAnimation { isVacationEditMode.toggle() }

        case .clearVacation:
            clearCurrentMonthData()
        }
    }

    func toggleVacationDate(_ dateString: String) {
        guard !vacationData.isSubmitted else {
            showToast("已提交排休，無法修改", type: .error)
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
            let wk = WeekUtils.weekIndex(of: dateString, in: currentDisplayMonth)
            let used = WeekUtils.count(in: data.selectedDates, week: wk)
            if used >= weeklyVacationLimit {
                showToast("已超過第\(wk)週最多可排 \(weeklyVacationLimit) 天", type: .weeklyLimit)
                return
            }
        }

        data.selectedDates.insert(dateString)
        apply(data, successDate: dateString)
    }

    func submitVacation() {
        print("📝 Employee 提交排休...")

        // 週上限檢查
        if currentVacationMode != .monthly {
            let stats = WeekUtils.weeklyStats(for: vacationData.selectedDates, in: currentDisplayMonth)
            if stats.values.contains(where: { $0 > weeklyVacationLimit }) {
                showToast("請檢查週休限制，每週最多可排 \(weeklyVacationLimit) 天", type: .error)
                return
            }
        }

        var data = vacationData
        data.isSubmitted = true
        data.currentMonth = currentDisplayMonth

        // 本地保存
        storage.saveVacationData(data, month: currentDisplayMonth)

        // Firebase 保存
        SyncStatusManager.shared.setSyncing()

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dates = Array(data.selectedDates).compactMap { dateFormatter.date(from: $0) }

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
            receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    DispatchQueue.main.async {
                        print("❌ Employee 提交失敗: \(error)")
                        SyncStatusManager.shared.setSyncError()
                    }
                case .finished:
                    break
                }
            },
            receiveValue: { [weak self] in
                DispatchQueue.main.async {
                    print("✅ Employee 提交成功！")
                    SyncStatusManager.shared.setSyncSuccess()
                    self?.vacationData = data
                    self?.showToast("排休已成功提交！", type: .success)

                    // 更新快取
                    if let month = self?.currentDisplayMonth {
                        self?.dataCache.removeValue(forKey: month)
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { self?.isVacationEditMode = false }
                    }
                }
            }
        )
        .store(in: &cancellables)
    }

    func clearCurrentSelection() {
        clearCurrentMonthData()
    }

    // MARK: - Helpers
    func dateToString(_ date: CalendarDate) -> String {
        String(format: "%04d-%02d-%02d", date.year, date.month, date.day)
    }

    func canSelect(day: Int) -> Bool {
        let ds = String(format: "%@-%02d", currentDisplayMonth, day)
        if vacationData.selectedDates.count >= availableVacationDays && !vacationData.selectedDates.contains(ds) {
            return false
        }
        if currentVacationMode != .monthly {
            let wk = WeekUtils.weekIndex(of: ds, in: currentDisplayMonth)
            let used = WeekUtils.count(in: vacationData.selectedDates, week: wk)
            return vacationData.selectedDates.contains(ds) || used < weeklyVacationLimit
        }
        return true
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

    // MARK: - Month Navigation Helpers
    func canEditMonth() -> Bool {
        let currentFormatter = DateFormatter()
        currentFormatter.dateFormat = "yyyy-MM"
        let currentMonth = currentFormatter.string(from: Date())

        let canEdit = currentDisplayMonth >= currentMonth
        print("🔍 Employee canEditMonth: 當前顯示=\(currentDisplayMonth), 系統當前=\(currentMonth), 可編輯=\(canEdit)")
        return canEdit
    }

    func isFutureMonth() -> Bool {
        let currentFormatter = DateFormatter()
        currentFormatter.dateFormat = "yyyy-MM"
        let currentMonth = currentFormatter.string(from: Date())

        let isFuture = currentDisplayMonth > currentMonth
        print("🔍 Employee isFutureMonth: 當前顯示=\(currentDisplayMonth), 系統當前=\(currentMonth), 是未來=\(isFuture)")
        return isFuture
    }

    func showToast(_ msg: String, type: ToastType) {
        toastMessage = msg
        toastType = type
        withAnimation { isToastShowing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + (type == .error ? 5 : 3)) {
            withAnimation { self.isToastShowing = false }
        }
    }

    // MARK: - Private
    private func loadLocalCache() {
        if let local = storage.loadVacationData(month: currentDisplayMonth) {
            vacationData = local
            print("📱 Employee 載入本地快取: \(currentDisplayMonth)")
        } else {
            vacationData = VacationData()
            print("📱 Employee 沒有本地快取，使用預設值")
        }
    }

    private func loadCurrentMonthData() {
        loadMonthDataSmart(month: currentDisplayMonth)
    }

    private func apply(
        _ data: VacationData,
        message: String? = nil,
        type: ToastType = .info,
        successDate: String? = nil
    ) {
        vacationData = data
        storage.saveVacationData(data, month: currentDisplayMonth)
        if let msg = message { showToast(msg, type: type) }
        if let ds = successDate { showSuccess(ds) }
    }

    private func showSuccess(_ dateString: String) {
        let leftAll = availableVacationDays - vacationData.selectedDates.count
        if currentVacationMode != .monthly {
            let wk = WeekUtils.weekIndex(of: dateString, in: currentDisplayMonth)
            let used = WeekUtils.count(in: vacationData.selectedDates, week: wk)
            let leftWeek = weeklyVacationLimit - used
            showToast("排休成功！剩餘 \(leftAll) 天，週剩餘 \(leftWeek) 天", type: .weeklySuccess)
        } else {
            showToast("排休成功！剩餘 \(leftAll) 天", type: .success)
        }
    }
}
