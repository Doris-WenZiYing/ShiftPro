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
    @Published var lastError: ShiftProError?

    // MARK: - Firebase 同步狀態
    @Published var firebaseSchedule: FirestoreEmployeeSchedule?
    @Published var firebaseRule: FirestoreVacationRule?
    @Published var isFirebaseLoading = false
    @Published var lastSyncTime: Date?

    // MARK: - Dependencies
    private let firebase = FirebaseService.shared
    private let storage = LocalStorageService.shared
    private let userManager = UserManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 數據管理
    private var currentListeners: [AnyCancellable] = []

    // MARK: - Computed Properties
    private var currentOrgId: String { userManager.currentOrgId }
    private var currentEmployeeId: String { userManager.currentEmployeeId }

    // 限制值
    var availableVacationDays: Int {
        firebaseRule?.monthlyLimit ?? 8
    }

    var weeklyVacationLimit: Int {
        firebaseRule?.weeklyLimit ?? 2
    }

    // 提交狀態
    var isReallySubmitted: Bool {
        guard let schedule = firebaseSchedule else { return false }
        return schedule.isSubmitted && !schedule.selectedDates.isEmpty
    }

    var canEditVacation: Bool {
        guard isUsingBossSettings else { return false }
        return !isReallySubmitted && canEditMonth()
    }

    // MARK: - Init
    init() {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        self.currentDisplayMonth = formatter.string(from: now)

        // 🔥 簡化初始化
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadCurrentMonthData()
        }
    }

    deinit {
        print("🗑️ EmployeeCalendarViewModel deinit")
        removeAllFirebaseListeners()
        cancellables.forEach { $0.cancel() }
    }

    // MARK: - 🔧 用戶管理設置

    private func setupUserManager() {
        if !userManager.isLoggedIn && !userManager.isGuest {
            userManager.setCurrentEmployee(
                employeeId: "emp_1",
                employeeName: "測試員工",
                orgId: "demo_store_01",
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
        removeAllFirebaseListeners()
    }

    // MARK: - 📊 月份數據管理

    private func loadCurrentMonthData() {
        // 🔥 簡化數據載入
        if let localData = LocalStorageService.shared.loadVacationData(month: currentDisplayMonth) {
            vacationData = localData
        } else {
            vacationData = VacationData()
        }

        setupFirebaseListeners()
    }

    private func saveCurrentData() {
        // 簡化數據保存邏輯
        LocalStorageService.shared.saveVacationData(vacationData, month: currentDisplayMonth)
    }

    // MARK: - 🔄 月份更新

    func updateDisplayMonth(year: Int, month: Int) {
        let newMonth = String(format: "%04d-%02d", year, month)
        guard newMonth != currentDisplayMonth else { return }

        print("📅 Employee 更新月份: \(currentDisplayMonth) -> \(newMonth)")

        // 保存當前數據
        saveCurrentData()

        // 更新月份
        currentDisplayMonth = newMonth

        // 載入新月份數據
        loadCurrentMonthData()
    }

    private func isValidMonth(year: Int, month: Int) -> Bool {
        let currentYear = Calendar.current.component(.year, from: Date())
        return year >= currentYear - 1 && year <= currentYear + 2 && month >= 1 && month <= 12
    }

    // MARK: - 🔥 Firebase 實時監聽

    private func setupFirebaseListeners() {
        removeAllFirebaseListeners()

        let rulePublisher = firebase.fetchVacationRule(orgId: currentOrgId, month: currentDisplayMonth)
            .replaceError(with: nil)

        let schedulePublisher = firebase.observeEmployeeSchedule(
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
                self?.lastSyncTime = Date()
                SyncStatusManager.shared.setSyncSuccess()
            }

        currentListeners.append(combinedListener)
        print("👂 Employee 設置 Firebase 監聽: \(currentDisplayMonth)")
    }

    private func handleRuleUpdate(_ rule: FirestoreVacationRule?) {
        firebaseRule = rule

        if let r = rule {
            currentVacationMode = VacationMode(rawValue: r.type) ?? .monthly
            isUsingBossSettings = r.published
        } else {
            isUsingBossSettings = false
        }
    }

    private func handleScheduleUpdate(_ schedule: FirestoreEmployeeSchedule?) {
        firebaseSchedule = schedule

        if let s = schedule, s.month == currentDisplayMonth {
            var newData = VacationData()
            newData.selectedDates = Set(s.selectedDates)
            newData.isSubmitted = s.isSubmitted
            newData.currentMonth = s.month

            // 只在真正不同時更新
            if vacationData.selectedDates != newData.selectedDates ||
               vacationData.isSubmitted != newData.isSubmitted {
                vacationData = newData
                print("📊 Employee Firebase 排班更新: \(currentDisplayMonth) - \(s.selectedDates.count)天, 提交=\(s.isSubmitted)")
            }
        }
    }

    private func removeAllFirebaseListeners() {
        currentListeners.forEach { $0.cancel() }
        currentListeners.removeAll()
        print("🔇 Employee 移除所有監聽")
    }

    // MARK: - 🎯 排休操作

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

    // MARK: - 📝 排休提交

    func submitVacation() {
        guard !vacationData.selectedDates.isEmpty else {
            showToast("請先選擇排休日期", type: .error)
            return
        }

        guard !isFirebaseLoading else {
            showToast("請等待當前操作完成", type: .warning)
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

        print("📝 Employee 提交排休...")

        isFirebaseLoading = true
        SyncStatusManager.shared.setSyncing()

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dates = Array(vacationData.selectedDates).compactMap { dateFormatter.date(from: $0) }

        firebase.updateEmployeeSchedule(
            orgId: currentOrgId,
            employeeId: currentEmployeeId,
            month: currentDisplayMonth,
            dates: dates
        )
        .flatMap { [weak self] _ in
            guard let self = self else {
                return Empty<Void, Error>().eraseToAnyPublisher()
            }
            return self.firebase.submitEmployeeSchedule(
                orgId: self.currentOrgId,
                employeeId: self.currentEmployeeId,
                month: self.currentDisplayMonth
            )
        }
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isFirebaseLoading = false

                switch completion {
                case .failure(let error):
                    print("❌ Employee 提交失敗: \(error)")
                    self?.handleError(error, context: "Submit Vacation")
                    SyncStatusManager.shared.setSyncError()
                case .finished:
                    break
                }
            },
            receiveValue: { [weak self] in
                print("✅ Employee 提交成功！")
                SyncStatusManager.shared.setSyncSuccess()
                self?.showToast("排休已成功提交！", type: .success)

                // 更新本地狀態
                if let self = self {
                    var updatedData = self.vacationData
                    updatedData.isSubmitted = true
                    self.vacationData = updatedData
                }

                self?.exitEditMode()
            }
        )
        .store(in: &cancellables)
    }

    // MARK: - 🗑️ 清除排休資料

    func clearAllVacationData() {
        guard !isFirebaseLoading else {
            showToast("請等待當前操作完成", type: .warning)
            return
        }

        print("🗑️ Employee 清除所有排休資料: \(currentDisplayMonth)")

        isFirebaseLoading = true
        SyncStatusManager.shared.setSyncing()

        // 清除本地資料
        let emptyData = VacationData()
        vacationData = emptyData

        // 刪除 Firebase 資料
        let docId = "\(currentOrgId)_\(currentEmployeeId)_\(currentDisplayMonth)"

        firebase.deleteDocument(
            collection: "employee_schedules",
            document: docId
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isFirebaseLoading = false

                switch completion {
                case .failure(let error):
                    print("❌ Employee 清除失敗: \(error)")
                    self?.handleError(error, context: "Clear Vacation")
                    SyncStatusManager.shared.setSyncError()
                case .finished:
                    break
                }
            },
            receiveValue: { [weak self] in
                print("✅ Employee Firebase 資料已清除")
                SyncStatusManager.shared.setSyncSuccess()
                self?.showToast("排休資料已完全清除", type: .info)

                self?.firebaseSchedule = nil
                self?.exitEditMode()
            }
        )
        .store(in: &cancellables)
    }

    func clearAllVacationDataWithToast() {
        let emptyData = VacationData()
        vacationData = emptyData
        showToast("已清除所有選擇", type: .info)
    }

    // MARK: - 📅 日期選擇邏輯

    func toggleVacationDate(_ dateString: String, showToast: Bool = false) {
        guard canEditVacation else {
            if showToast {
                self.showToast("無法編輯排休", type: .error)
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
            self.showToast("已達到本月可排休上限 \(availableVacationDays) 天", type: .error)
            return
        }

        // 週上限檢查
        if currentVacationMode != .monthly {
            let week = WeekUtils.weekIndex(of: dateString, in: currentDisplayMonth)
            let used = WeekUtils.count(in: data.selectedDates, week: week)
            if used >= weeklyVacationLimit {
                self.showToast("已超過第\(week)週最多可排 \(weeklyVacationLimit) 天", type: .weeklyLimit)
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

    // MARK: - 🔧 輔助方法

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

    // MARK: - 🎯 Toast 控制

    func showToast(_ msg: String, type: ToastType) {
        toastMessage = msg
        toastType = type
        withAnimation { isToastShowing = true }

        let delay = type == .error ? 5.0 : 3.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation { self.isToastShowing = false }
        }
    }

    // MARK: - 🔧 Private Methods

    private func apply(
        _ data: VacationData,
        message: String? = nil,
        type: ToastType = .info,
        successDate: String? = nil
    ) {
        vacationData = data

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

    // MARK: - 📢 通知監聽

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
                self?.showToast("收到新的排休設定！", type: .info)
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
                self?.showToast("老闆已取消發佈排休設定", type: .warning)
            }
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

        print("❌ EmployeeCalendarViewModel Error [\(context)]: \(shiftProError.errorDescription ?? "Unknown")")
    }
}
