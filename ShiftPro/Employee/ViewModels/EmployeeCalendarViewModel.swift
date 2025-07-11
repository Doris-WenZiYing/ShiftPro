//
//  EmployeeCalendarViewModel.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/10.
//

import Foundation
import SwiftUI
import Combine

// MARK: - EmployeeCalendarViewModel
class EmployeeCalendarViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var isVacationEditMode = false
    @Published var vacationData = VacationData()
    @Published var currentVacationMode: VacationMode = .monthly
    @Published var toastMessage = ""
    @Published var toastType: ToastType = .info
    @Published var isToastShowing = false
    @Published var isUsingBossSettings: Bool = false

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Vacation Settings
    var availableVacationMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date.now)
    }

    var availableVacationDays: Int = 4
    var weeklyVacationLimit: Int = 2

    // MARK: - Initialization
    init() {
        setupVacationLimitsListener()
        loadVacationLimitsFromBossSettings()
        loadVacationData()
    }

    deinit {
        removeVacationLimitsListener()
    }

    // MARK: - Actions
    func handleVacationAction(_ action: ShiftAction) {
        switch action {
        case .editVacation:
            let currentMonth = getCurrentMonthString()
            if currentMonth != availableVacationMonth {
                showToast("只能在 \(formatMonthString(availableVacationMonth)) 排休", type: .error)
                return
            }

            if vacationData.isSubmitted {
                showToast("本月排休已提交，無法修改", type: .error)
                return
            }

            withAnimation(.easeInOut(duration: 0.3)) {
                isVacationEditMode = true
            }

        case .clearVacation:
            clearAllVacationData()
        }
    }

    func toggleVacationDate(_ dateString: String) {
        if vacationData.isSubmitted {
            showToast(message: "已提交排休，無法修改", type: .error)
            return
        }

        var newVacationData = vacationData

        if newVacationData.isDateSelected(dateString) {
            newVacationData.removeDate(dateString)
        } else {
            // 檢查月排休限制
            if newVacationData.selectedDates.count >= availableVacationDays {
                showToast(message: "已超過可排休天數上限 (\(availableVacationDays) 天)", type: .error)
                return
            }

            // 檢查週排休限制
            if currentVacationMode == .weekly || currentVacationMode == .monthlyWithWeeklyLimit {
                if !canSelectForWeeklyLimit(dateString: dateString) {
                    showToast(message: "已超過本週排休上限 (\(weeklyVacationLimit) 天)", type: .error)
                    return
                }
            }

            newVacationData.addDate(dateString)
        }

        vacationData = newVacationData
        saveVacationData()
    }

    func submitVacation() {
        vacationData.isSubmitted = true
        vacationData.currentMonth = getCurrentMonthString()
        saveVacationData()
        showToast(message: "排休已成功提交！", type: .success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.isVacationEditMode = false
            }
        }
    }

    func clearCurrentSelection() {
        vacationData.selectedDates.removeAll()
        saveVacationData()
    }

    func exitEditMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isVacationEditMode = false
        }
    }

    // MARK: - Validation Methods
    func canSelectForCurrentMode(day: Int) -> Bool {
        switch currentVacationMode {
        case .monthly:
            return true
        case .weekly, .monthlyWithWeeklyLimit:
            let dateString = String(format: "%@-%02d", availableVacationMonth, day)
            return canSelectForWeeklyLimit(dateString: dateString)
        }
    }

    // 重命名方法：從 shouldShowWeeklyHint 改為 shouldShowSelectionHint
    func shouldShowSelectionHint(day: Int, canSelect: Bool, isSelected: Bool) -> Bool {
        // 所有模式都顯示可選擇且未選擇的日期
        return canSelect && !isSelected
    }

    private func canSelectForWeeklyLimit(dateString: String) -> Bool {
        let calendar = Calendar.current
        let components = dateString.split(separator: "-")
        guard components.count == 3,
              let year = Int(components[0]),
              let month = Int(components[1]),
              let day = Int(components[2]) else {
            return false
        }

        guard let targetDate = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            return false
        }

        let selectedInSameWeek = vacationData.selectedDates.compactMap { dateString -> Date? in
            let parts = dateString.split(separator: "-")
            guard parts.count == 3,
                  let y = Int(parts[0]),
                  let m = Int(parts[1]),
                  let d = Int(parts[2]) else { return nil }
            return calendar.date(from: DateComponents(year: y, month: m, day: d))
        }.filter { selectedDate in
            calendar.isDate(selectedDate, equalTo: targetDate, toGranularity: .weekOfYear)
        }

        return selectedInSameWeek.count < weeklyVacationLimit
    }

    // MARK: - Helper Methods
    func formatMonthString(_ monthString: String) -> String {
        let components = monthString.split(separator: "-")
        if components.count == 2,
           let year = Int(components[0]),
           let month = Int(components[1]) {
            return "\(year)年\(month)月"
        }
        return monthString
    }

    func getCurrentMonthString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    func showToast(_ message: String, type: ToastType) {
        toastMessage = message
        toastType = type
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isToastShowing = true
        }
    }

    func dateToString(_ date: CalendarDate) -> String {
        return String(format: "%04d-%02d-%02d", date.year, date.month, date.day)
    }

    func textColor(for date: CalendarDate, isSelected: Bool, isVacationSelected: Bool) -> Color {
        if isVacationSelected {
            return .white
        } else if isSelected && !isVacationEditMode {
            return .black
        } else if date.isCurrentMonth == true {
            return .white
        } else {
            return isSelected ? .black : .gray.opacity(0.4)
        }
    }

    // MARK: - Data Persistence
    private func saveVacationData() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(vacationData) {
            UserDefaults.standard.set(encoded, forKey: "VacationData_\(getCurrentMonthString())")
        }
    }

    private func loadVacationData() {
        let key = "VacationData_\(getCurrentMonthString())"
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(VacationData.self, from: data) {
            vacationData = decoded
        }
    }

    private func clearAllVacationData() {
        let key = "VacationData_\(getCurrentMonthString())"
        UserDefaults.standard.removeObject(forKey: key)
        vacationData = VacationData()
        showToast("所有排休資料已清除", type: .info)
    }

    func showToast(message: String, type: ToastType) {
        self.toastMessage = message
        self.toastType = type
        self.isToastShowing = true
    }
}

// MARK: - Vacation Limits Extension
extension EmployeeCalendarViewModel {

    /// 從管理者設定中載入休假限制
    func loadVacationLimitsFromBossSettings() {
        let components = availableVacationMonth.split(separator: "-")
        guard components.count == 2,
              let year = Int(components[0]),
              let month = Int(components[1]) else {
            return
        }

        let limits = VacationLimitsManager.shared.getVacationLimits(for: year, month: month)

        // 更新 ViewModel 中的限制值
        if let monthlyLimit = limits.monthlyLimit {
            self.availableVacationDays = monthlyLimit
        }

        if let weeklyLimit = limits.weeklyLimit {
            self.weeklyVacationLimit = weeklyLimit
        }

        // 檢查是否使用了老闆設定
        self.isUsingBossSettings = VacationLimitsManager.shared.hasLimitsForMonth(year: year, month: month)
    }

    /// 檢查當前月份是否有管理者設定的限制
    func hasBossSettingsForCurrentMonth() -> Bool {
        let components = availableVacationMonth.split(separator: "-")
        guard components.count == 2,
              let year = Int(components[0]),
              let month = Int(components[1]) else {
            return false
        }

        return VacationLimitsManager.shared.hasLimitsForMonth(year: year, month: month)
    }

    /// 獲取當前月份的限制資訊
    func getCurrentMonthLimits() -> VacationLimits? {
        let components = availableVacationMonth.split(separator: "-")
        guard components.count == 2,
              let year = Int(components[0]),
              let month = Int(components[1]) else {
            return nil
        }

        return VacationLimitsManager.shared.getVacationLimits(for: year, month: month)
    }

    /// 設置限制更新監聽器
    func setupVacationLimitsListener() {
        NotificationCenter.default.addObserver(
            forName: .vacationLimitsDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadVacationLimitsFromBossSettings()
        }
    }

    /// 移除限制更新監聽器
    func removeVacationLimitsListener() {
        NotificationCenter.default.removeObserver(
            self,
            name: .vacationLimitsDidUpdate,
            object: nil
        )
    }
}
