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
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Limits
    private(set) var availableVacationDays = 8
    private(set) var weeklyVacationLimit = 2

    // MARK: - Cache
    private var loadedMonths = Set<String>() // 追蹤已載入的月份
    private var isLoading = false // 防止重複載入

    // 🚨 緊急防護機制
    private var lastUpdateTime: Date = Date()
    private var updateCount: Int = 0
    private let maxUpdatesPerSecond = 3
    private var isBlocked = false

    // MARK: - 假資料配置
    private let demoOrgId = "demo_store_01"
    private let demoEmployeeId = "emp_001"

    // MARK: - Init
    init(
        scheduleService: ScheduleService = .shared,
        storage: LocalStorageService = .shared
    ) {
        self.scheduleService = scheduleService
        self.storage = storage

        // Initialize currentDisplayMonth - 確保格式正確
        let now = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        self.currentDisplayMonth = String(format: "%04d-%02d", year, month)

        print("🎯 初始化 EmployeeCalendarViewModel")
        print("   - 初始月份: \(currentDisplayMonth)")

        // 設定假資料
        setupDemoData()

        // 載入當前月份資料
        loadCurrentMonthData()
    }

    deinit {
        print("🗑️ EmployeeCalendarViewModel deinit")
        cancellables.forEach { $0.cancel() }
    }

    // MARK: - Demo Data Setup
    private func setupDemoData() {
        UserDefaults.standard.set(demoOrgId, forKey: "orgId")
        UserDefaults.standard.set(demoEmployeeId, forKey: "employeeId")
        print("🎭 使用假資料: orgId=\(demoOrgId), employeeId=\(demoEmployeeId)")
    }

    // MARK: - 🚨 緊急防護方法
    private func shouldBlockUpdate(year: Int, month: Int) -> Bool {
        let now = Date()

        // 檢查是否已被阻擋
        if isBlocked {
            print("🚫 更新已被阻擋，請稍後再試")
            return true
        }

        // 重置計數器（每秒）
        if now.timeIntervalSince(lastUpdateTime) > 1.0 {
            updateCount = 0
            lastUpdateTime = now
        }

        updateCount += 1

        // 檢查更新頻率
        if updateCount > maxUpdatesPerSecond {
            print("🚫 更新過於頻繁，暫時阻擋所有更新")
            isBlocked = true

            // 5秒後解除阻擋
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.isBlocked = false
                self.updateCount = 0
                print("✅ 解除更新阻擋")
            }
            return true
        }

        // 檢查年份合理性
        let currentYear = Calendar.current.component(.year, from: Date())
        if abs(year - currentYear) > 2 {
            print("🚫 年份超出合理範圍: \(year) (當前: \(currentYear))")
            return true
        }

        return false
    }

    // MARK: - Public Methods

    func updateDisplayMonth(year: Int, month: Int) {
        // 🚨 緊急防護檢查
        if shouldBlockUpdate(year: year, month: month) {
            return
        }

        print("🔍 updateDisplayMonth 被調用:")
        print("   - 傳入參數: year=\(year), month=\(month)")
        print("   - 當前月份: \(currentDisplayMonth)")
        print("   - 更新次數: \(updateCount)")

        // 驗證年月範圍 - 更嚴格的檢查
        if year < 2020 || year > 2030 {
            print("❌ 無效的年份: \(year)")
            return
        }

        if month < 1 || month > 12 {
            print("❌ 無效的月份: \(month)")
            return
        }

        let newMonth = String(format: "%04d-%02d", year, month)
        guard newMonth != currentDisplayMonth else {
            print("📅 月份相同，跳過載入: \(newMonth)")
            return
        }

        print("📅 EmployeeViewModel 更新月份: \(currentDisplayMonth) -> \(newMonth)")
        currentDisplayMonth = newMonth

        // 如果已經載入過這個月份，只需要從快取讀取
        if loadedMonths.contains(newMonth) {
            print("📋 從快取載入月份: \(newMonth)")
            loadLocalCache()
            return
        }

        // 重置並載入新月份資料
        resetMonthData()
        loadCurrentMonthData()
    }

    // 🔍 新增：安全的月份更新方法
    func safeUpdateDisplayMonth(year: Int, month: Int) {
        print("🔒 safeUpdateDisplayMonth 被調用: year=\(year), month=\(month)")

        // 基本範圍檢查
        guard year >= 2020 && year <= 2030 else {
            print("❌ 年份超出範圍: \(year)")
            return
        }

        guard month >= 1 && month <= 12 else {
            print("❌ 月份超出範圍: \(month)")
            return
        }

        // 檢查是否為合理的變化（只允許±2年的變化）
        let currentDate = DateFormatter.yearMonthFormatter.date(from: currentDisplayMonth) ?? Date()
        let currentYear = Calendar.current.component(.year, from: currentDate)

        if abs(year - currentYear) > 2 {
            print("❌ 年份變化過大: 從 \(currentYear) 到 \(year)")
            return
        }

        updateDisplayMonth(year: year, month: month)
    }

    // 🚨 強制重置方法
    func emergencyReset() {
        print("🚨 執行緊急重置")
        isBlocked = false
        updateCount = 0
        isLoading = false
        loadedMonths.removeAll()

        // 回到當前月份
        let now = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        let currentMonth = String(format: "%04d-%02d", year, month)

        currentDisplayMonth = currentMonth
        resetMonthData()
        loadCurrentMonthData()

        print("✅ 緊急重置完成，回到: \(currentMonth)")
    }

    // 🔍 新增：單純的下個月/上個月方法
    func goToNextMonth() {
        if isBlocked {
            print("🚫 系統暫時阻擋中，無法切換月份")
            return
        }

        let currentDate = DateFormatter.yearMonthFormatter.date(from: currentDisplayMonth) ?? Date()
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentDate) ?? Date()
        let year = Calendar.current.component(.year, from: nextMonth)
        let month = Calendar.current.component(.month, from: nextMonth)

        print("📈 前往下個月: \(year)-\(month)")
        updateDisplayMonth(year: year, month: month)
    }

    func goToPreviousMonth() {
        if isBlocked {
            print("🚫 系統暫時阻擋中，無法切換月份")
            return
        }

        let currentDate = DateFormatter.yearMonthFormatter.date(from: currentDisplayMonth) ?? Date()
        let previousMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentDate) ?? Date()
        let year = Calendar.current.component(.year, from: previousMonth)
        let month = Calendar.current.component(.month, from: previousMonth)

        print("📉 前往上個月: \(year)-\(month)")
        updateDisplayMonth(year: year, month: month)
    }

    func goToCurrentMonth() {
        let now = Date()
        let year = Calendar.current.component(.year, from: now)
        let month = Calendar.current.component(.month, from: now)

        print("📍 回到當前月份: \(year)-\(month)")
        updateDisplayMonth(year: year, month: month)
    }

    private func resetMonthData() {
        vacationData = VacationData()
        isUsingBossSettings = false
        availableVacationDays = 8
        weeklyVacationLimit = 2
        currentVacationMode = .monthly
    }

    private func loadCurrentMonthData() {
        // 防止重複載入
        guard !isLoading else {
            print("📊 正在載入中，跳過重複請求")
            return
        }

        // 檢查是否已載入過
        if loadedMonths.contains(currentDisplayMonth) {
            print("📊 月份已載入過: \(currentDisplayMonth)")
            loadLocalCache()
            return
        }

        isLoading = true
        print("📊 載入月份資料: \(currentDisplayMonth)")

        // 1. 載入本地快取
        loadLocalCache()

        // 2. 批次載入資料
        let vacationRulePublisher = scheduleService.fetchVacationRule(orgId: demoOrgId, month: currentDisplayMonth)
            .replaceError(with: nil)

        let employeeSchedulePublisher = scheduleService.fetchEmployeeSchedule(
            orgId: demoOrgId,
            employeeId: demoEmployeeId,
            month: currentDisplayMonth
        )
        .replaceError(with: nil)

        // 合併兩個請求
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
                    // 更新本地快取
                    self.storage.saveVacationData(data, month: self.currentDisplayMonth)
                } else {
                    print("📊 沒有找到員工排班資料，保持本地資料")
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - 清除快取方法
    func clearCache() {
        loadedMonths.removeAll()
        isLoading = false
        print("🗑️ 已清除月份快取")
    }

    func reloadCurrentMonth() {
        loadedMonths.remove(currentDisplayMonth)
        isLoading = false
        resetMonthData()
        loadCurrentMonthData()
        print("🔄 重新載入當前月份: \(currentDisplayMonth)")
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
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dates = Array(data.selectedDates).compactMap { dateFormatter.date(from: $0) }

        scheduleService.updateEmployeeSchedule(
            orgId: demoOrgId,
            employeeId: demoEmployeeId,
            month: currentDisplayMonth,
            dates: dates
        )
        .flatMap { [weak self] _ in
            guard let self = self else {
                return Empty<Void, Error>().eraseToAnyPublisher()
            }
            return self.scheduleService.submitEmployeeSchedule(
                orgId: self.demoOrgId,
                employeeId: self.demoEmployeeId,
                month: self.currentDisplayMonth
            )
        }
        .sink(
            receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    print("Submit error: \(error)")
                case .finished:
                    break
                }
            },
            receiveValue: { [weak self] in
                DispatchQueue.main.async {
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
        // 清除本地資料
        let oldData = vacationData
        vacationData = VacationData()
        storage.clearVacationData(month: currentDisplayMonth)

        // 如果之前有提交過的資料，也清除 Firebase
        if oldData.isSubmitted || !oldData.selectedDates.isEmpty {
            scheduleService.updateEmployeeSchedule(
                orgId: demoOrgId,
                employeeId: demoEmployeeId,
                month: currentDisplayMonth,
                dates: []
            )
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        print("Clear error: \(error)")
                    case .finished:
                        break
                    }
                },
                receiveValue: { [weak self] in
                    DispatchQueue.main.async {
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
            print("📱 載入本地快取: \(local)")
        } else {
            vacationData = VacationData()
            print("📱 沒有本地快取，使用預設值")
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
