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

    // MARK: - Init
    init(
        scheduleService: ScheduleService = .shared,
        storage: LocalStorageService = .shared
    ) {
        self.scheduleService = scheduleService
        self.storage = storage

        // Initialize currentDisplayMonth
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        self.currentDisplayMonth = formatter.string(from: Date())

        // Load local cache first
        loadLocalCache()
        // Fetch remote & combine
        fetchAllData()
    }

    deinit {
        cancellables.forEach { $0.cancel() }
    }

    // MARK: - Public Methods

    func updateDisplayMonth(year: Int, month: Int) {
        let newMonth = String(format: "%04d-%02d", year, month)
        guard newMonth != currentDisplayMonth else { return }
        currentDisplayMonth = newMonth
        // reload
        loadLocalCache()
        fetchAllData()
    }

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
            clearAll()
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
        // 月上限
        if data.selectedDates.count >= availableVacationDays {
            showToast("已達到本月可排休上限 \(availableVacationDays) 天", type: .error)
            return
        }
        // 週上限
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

        // persist both local & remote
        storage.saveVacationData(data, month: currentDisplayMonth)

        // Convert Set<String> to [Date] for the service
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dates = Array(data.selectedDates).compactMap { dateFormatter.date(from: $0) }

        scheduleService.updateEmployeeSchedule(
            orgId: orgId,
            employeeId: employeeId,
            month: currentDisplayMonth,
            dates: dates
        )
        .flatMap { [weak self] _ in
            guard let self = self else {
                return Empty<Void, Error>().eraseToAnyPublisher()
            }
            return self.scheduleService.submitEmployeeSchedule(
                orgId: self.orgId,
                employeeId: self.employeeId,
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
                self?.vacationData = data
                self?.showToast("排休已成功提交！", type: .success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { self?.isVacationEditMode = false }
                }
            }
        )
        .store(in: &cancellables)
    }

    func clearCurrentSelection() {
        clearAll()
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let thisM = formatter.string(from: Date())
        return currentDisplayMonth == thisM
            ? "本月"
            : formatMonthString(currentDisplayMonth)
    }

    // MARK: - Month Navigation Helpers

    /// 檢查是否可以編輯月份
    func canEditMonth() -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let currentMonth = formatter.string(from: Date())
        return currentDisplayMonth >= currentMonth
    }

    /// 檢查是否為未來月份
    func isFutureMonth() -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let currentMonth = formatter.string(from: Date())
        return currentDisplayMonth > currentMonth
    }

    // MARK: - Private

    private func loadLocalCache() {
        // Load local vacation data
        if let local = storage.loadVacationData(month: currentDisplayMonth) {
            vacationData = local
        } else {
            vacationData = VacationData()
        }
    }

    private func fetchAllData() {
        // 1. 讀規則
        scheduleService.fetchVacationRule(orgId: orgId, month: currentDisplayMonth)
            .replaceError(with: nil)
            .sink { [weak self] rule in
                guard let self = self, let r = rule else { return }
                self.availableVacationDays = r.monthlyLimit ?? 8
                self.weeklyVacationLimit = r.weeklyLimit ?? 2
                self.currentVacationMode = VacationMode(rawValue: r.type) ?? .monthly
                self.isUsingBossSettings = r.published
            }
            .store(in: &cancellables)

        // 2. 讀遠端排休
        scheduleService.fetchEmployeeSchedule(
            orgId: orgId,
            employeeId: employeeId,
            month: currentDisplayMonth
        )
        .replaceError(with: nil)
        .sink { [weak self] sched in
            guard let self = self, let s = sched else { return }
            var data = VacationData()
            data.selectedDates = Set(s.selectedDates)
            data.isSubmitted = s.isSubmitted
            data.currentMonth = s.month
            self.vacationData = data
            // override local
            self.storage.saveVacationData(data, month: self.currentDisplayMonth)
        }
        .store(in: &cancellables)
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

    private func clearAll() {
        vacationData = VacationData()
        storage.clearVacationData(month: currentDisplayMonth)
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

    func showToast(_ msg: String, type: ToastType) {
        toastMessage = msg
        toastType = type
        withAnimation { isToastShowing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + (type == .error ? 5 : 3)) {
            withAnimation { self.isToastShowing = false }
        }
    }

    private func formatMonthString(_ m: String) -> String {
        let c = m.split(separator: "-")
        guard c.count == 2, let y = Int(c[0]), let mm = Int(c[1]) else { return m }
        return "\(y)年\(mm)月"
    }

    // MARK: - Read from UserDefaults
    private var orgId: String {
        UserDefaults.standard.string(forKey: "orgId") ?? "demo_store_01"
    }
    private var employeeId: String {
        UserDefaults.standard.string(forKey: "employeeId") ?? "emp_001"
    }
}
