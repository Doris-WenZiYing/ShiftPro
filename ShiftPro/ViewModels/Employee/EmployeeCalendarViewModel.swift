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

    // MARK: - Cache and Loading State
    private var loadedMonths = Set<String>()
    private var isLoading = false
    private var vacationRuleListener: AnyCancellable?

    // 🚨 緊急防護機制
    private var lastUpdateTime: Date = Date()
    private var updateCount: Int = 0
    private let maxUpdatesPerSecond = 3
    private var isBlocked = false

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

        // Initialize currentDisplayMonth
        let now = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        self.currentDisplayMonth = String(format: "%04d-%02d", year, month)

        print("🎯 初始化 EmployeeCalendarViewModel")
        print("   - 初始月份: \(currentDisplayMonth)")
        print("   - 組織ID: \(currentOrgId)")
        print("   - 員工ID: \(currentEmployeeId)")

        // 如果沒有登入，設定預設身分
        if !userManager.isLoggedIn {
            setupDefaultEmployee()
        }

        // 載入當前月份資料
        loadCurrentMonthData()

        // 🔥 設定實時監聽老闆發佈的休假規則
        setupVacationRuleListener()

        // 🔥 監聽老闆發佈/取消發佈通知
        setupNotificationListeners()

        // 🔥 監聽用戶身分變化
        userManager.$currentUser
            .sink { [weak self] _ in
                self?.clearCache()
                self?.loadCurrentMonthData()
                self?.setupVacationRuleListener()
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

    // MARK: - 🔥 實時監聽休假規則
    private func setupVacationRuleListener() {
        vacationRuleListener?.cancel()

        print("👂 Employee 開始監聽休假規則變化: \(currentOrgId)_\(currentDisplayMonth)")

        vacationRuleListener = scheduleService.fetchVacationRule(orgId: currentOrgId, month: currentDisplayMonth)
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rule in
                guard let self = self else { return }

                if let r = rule {
                    print("📡 Employee 收到休假規則更新: \(r)")
                    self.availableVacationDays = r.monthlyLimit ?? 8
                    self.weeklyVacationLimit = r.weeklyLimit ?? 2
                    self.currentVacationMode = VacationMode(rawValue: r.type) ?? .monthly
                    self.isUsingBossSettings = r.published

                    if r.published && !self.isUsingBossSettings {
                        self.showToast("老闆已發佈 \(self.getMonthDisplayText()) 的排休設定！", type: .success)
                    }
                } else {
                    print("📡 Employee 沒有收到休假規則")
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

    // MARK: - 🚨 緊急防護方法
    private func shouldBlockUpdate(year: Int, month: Int) -> Bool {
        let now = Date()

        if isBlocked {
            print("🚫 更新已被阻擋，請稍後再試")
            return true
        }

        if now.timeIntervalSince(lastUpdateTime) > 1.0 {
            updateCount = 0
            lastUpdateTime = now
        }

        updateCount += 1

        if updateCount > maxUpdatesPerSecond {
            print("🚫 更新過於頻繁，暫時阻擋所有更新")
            isBlocked = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.isBlocked = false
                self.updateCount = 0
                print("✅ 解除更新阻擋")
            }
            return true
        }

        let currentYear = Calendar.current.component(.year, from: Date())
        if abs(year - currentYear) > 2 {
            print("🚫 年份超出合理範圍: \(year) (當前: \(currentYear))")
            return true
        }

        return false
    }

    // MARK: - Public Methods

    func updateDisplayMonth(year: Int, month: Int) {
        if shouldBlockUpdate(year: year, month: month) {
            return
        }

        print("🔍 Employee updateDisplayMonth:")
        print("   - 傳入參數: year=\(year), month=\(month)")
        print("   - 當前月份: \(currentDisplayMonth)")
        print("   - 更新次數: \(updateCount)")

        if year < 2020 || year > 2030 || month < 1 || month > 12 {
            print("❌ 無效的年月: \(year)-\(month)")
            return
        }

        let newMonth = String(format: "%04d-%02d", year, month)
        guard newMonth != currentDisplayMonth else {
            print("📅 月份相同，跳過載入: \(newMonth)")
            return
        }

        print("📅 Employee 更新月份: \(currentDisplayMonth) -> \(newMonth)")
        currentDisplayMonth = newMonth

        // 更新監聽器到新月份
        setupVacationRuleListener()

        // 載入新月份資料
        if loadedMonths.contains(newMonth) {
            print("📋 從快取載入月份: \(newMonth)")
            loadLocalCache()
        } else {
            resetMonthData()
            loadCurrentMonthData()
        }
    }

    func safeUpdateDisplayMonth(year: Int, month: Int) {
        print("🔒 Employee safeUpdateDisplayMonth: year=\(year), month=\(month)")

        guard year >= 2020 && year <= 2030 && month >= 1 && month <= 12 else {
            print("❌ 年月超出範圍: \(year)-\(month)")
            return
        }

        let currentDate = DateFormatter.yearMonthFormatter.date(from: currentDisplayMonth) ?? Date()
        let currentYear = Calendar.current.component(.year, from: currentDate)

        if abs(year - currentYear) > 2 {
            print("❌ 年份變化過大: 從 \(currentYear) 到 \(year)")
            return
        }

        updateDisplayMonth(year: year, month: month)
    }

    func emergencyReset() {
        print("🚨 Employee 執行緊急重置")
        isBlocked = false
        updateCount = 0
        isLoading = false
        loadedMonths.removeAll()
        vacationRuleListener?.cancel()

        let now = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        let currentMonth = String(format: "%04d-%02d", year, month)

        currentDisplayMonth = currentMonth
        resetMonthData()
        loadCurrentMonthData()
        setupVacationRuleListener()

        print("✅ Employee 緊急重置完成，回到: \(currentMonth)")
    }

    private func resetMonthData() {
        vacationData = VacationData()
        isUsingBossSettings = false
        availableVacationDays = 8
        weeklyVacationLimit = 2
        currentVacationMode = .monthly
    }

    private func loadCurrentMonthData() {
        guard !isLoading else {
            print("📊 正在載入中，跳過重複請求")
            return
        }

        if loadedMonths.contains(currentDisplayMonth) {
            print("📊 月份已載入過: \(currentDisplayMonth)")
            loadLocalCache()
            return
        }

        isLoading = true
        print("📊 Employee 載入月份資料: \(currentDisplayMonth)")
        print("   組織: \(currentOrgId), 員工: \(currentEmployeeId)")

        // 1. 載入本地快取
        loadLocalCache()

        // 2. 批次載入 Firebase 資料
        let vacationRulePublisher = scheduleService.fetchVacationRule(orgId: currentOrgId, month: currentDisplayMonth)
            .replaceError(with: nil)

        let employeeSchedulePublisher = scheduleService.fetchEmployeeSchedule(
            orgId: currentOrgId,
            employeeId: currentEmployeeId,
            month: currentDisplayMonth
        )
        .replaceError(with: nil)

        Publishers.CombineLatest(vacationRulePublisher, employeeSchedulePublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (rule, schedule) in
                guard let self = self else { return }

                self.isLoading = false
                self.loadedMonths.insert(self.currentDisplayMonth)

                // 處理休假規則
                if let r = rule {
                    print("📊 找到休假規則: \(r)")
                    self.availableVacationDays = r.monthlyLimit ?? 8
                    self.weeklyVacationLimit = r.weeklyLimit ?? 2
                    self.currentVacationMode = VacationMode(rawValue: r.type) ?? .monthly
                    self.isUsingBossSettings = r.published
                } else {
                    print("📊 沒有找到休假規則")
                    self.isUsingBossSettings = false
                }

                // 處理員工排班
                if let s = schedule {
                    print("📊 找到員工排班: \(s)")
                    var data = VacationData()
                    data.selectedDates = Set(s.selectedDates)
                    data.isSubmitted = s.isSubmitted
                    data.currentMonth = s.month
                    self.vacationData = data
                    self.storage.saveVacationData(data, month: self.currentDisplayMonth)
                } else {
                    print("📊 沒有找到員工排班資料，保持本地資料")
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Cache Management
    func clearCache() {
        loadedMonths.removeAll()
        isLoading = false
        print("🗑️ Employee 已清除月份快取")
    }

    func reloadCurrentMonth() {
        loadedMonths.remove(currentDisplayMonth)
        isLoading = false
        resetMonthData()
        loadCurrentMonthData()
        print("🔄 Employee 重新載入當前月份: \(currentDisplayMonth)")
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
            clearAllVacationData()
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
        print("   組織: \(currentOrgId), 員工: \(currentEmployeeId)")
        print("   月份: \(currentDisplayMonth)")
        print("   選擇日期: \(vacationData.selectedDates)")

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

        // 🔥 設定同步狀態
        SyncStatusManager.shared.setSyncing()

        // Firebase 保存
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { self?.isVacationEditMode = false }
                    }
                }
            }
        )
        .store(in: &cancellables)
    }

    func clearCurrentSelection() {
        clearAllVacationData()
    }

    private func clearAllVacationData() {
        print("🗑️ Employee 清除排休資料")

        let oldData = vacationData
        vacationData = VacationData()
        storage.clearVacationData(month: currentDisplayMonth)

        if oldData.isSubmitted || !oldData.selectedDates.isEmpty {
            // 🔥 設定同步狀態
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
                            print("❌ 清除失敗: \(error)")
                            SyncStatusManager.shared.setSyncError()
                        }
                    case .finished:
                        break
                    }
                },
                receiveValue: { [weak self] in
                    DispatchQueue.main.async {
                        SyncStatusManager.shared.setSyncSuccess()
                        self?.showToast("排休資料已清除", type: .info)
                    }
                }
            )
            .store(in: &cancellables)
        } else {
            showToast("排休資料已清除", type: .info)
        }
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
        let thisM = DateFormatter.yearMonthFormatter.string(from: Date())
        return currentDisplayMonth == thisM ? "本月" : formatMonthString(currentDisplayMonth)
    }

    // MARK: - Month Navigation Helpers

    func canEditMonth() -> Bool {
        let currentMonth = DateFormatter.yearMonthFormatter.string(from: Date())
        return currentDisplayMonth >= currentMonth
    }

    func isFutureMonth() -> Bool {
        let currentMonth = DateFormatter.yearMonthFormatter.string(from: Date())
        return currentDisplayMonth > currentMonth
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
            print("📱 Employee 載入本地快取: \(local)")
        } else {
            vacationData = VacationData()
            print("📱 Employee 沒有本地快取，使用預設值")
        }
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

    private func formatMonthString(_ m: String) -> String {
        guard let date = DateFormatter.yearMonthFormatter.date(from: m) else { return m }
        return DateFormatter.monthYearFormatter.string(from: date)
    }
}
