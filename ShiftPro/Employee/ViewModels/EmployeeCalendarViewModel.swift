//
//  EmployeeCalendarViewModel.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/10.
//

import Foundation
import SwiftUI
import Combine

class EmployeeCalendarViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var isVacationEditMode = false
    @Published var vacationData = VacationData()
    @Published var currentVacationMode: VacationMode = .monthly
    @Published var toastMessage = ""
    @Published var toastType: ToastType = .info
    @Published var isToastShowing = false
    @Published var isUsingBossSettings: Bool = false

    // 🔥 新增：當前顯示的月份
    @Published var currentDisplayMonth: String = ""

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Vacation Settings
    var availableVacationDays: Int = 4
    var weeklyVacationLimit: Int = 2

    // MARK: - Initialization
    init() {
        // 初始化為當前月份
        currentDisplayMonth = getCurrentMonthString()
        setupVacationLimitsListener()
        loadVacationLimitsFromBossSettings()
        loadVacationData()

        print("📱 員工端ViewModel初始化完成 - 當前月份: \(currentDisplayMonth)")
    }

    deinit {
        removeVacationLimitsListener()
    }

    // MARK: - 🔥 新增：月份切換方法
    func updateDisplayMonth(year: Int, month: Int) {
        let newMonth = String(format: "%04d-%02d", year, month)
        if newMonth != currentDisplayMonth {
            print("📅 員工端切換到月份: \(newMonth)")
            currentDisplayMonth = newMonth

            // 🔥 優先從 Firebase 載入該月份的設定
            loadVacationLimitsFromFirebaseForCurrentMonth()

            // 載入該月份的排休數據
            loadVacationData()
        }
    }

    // MARK: - Actions
    func handleVacationAction(_ action: ShiftAction) {
        switch action {
        case .editVacation:
            // 🔥 移除當前月份限制，允許編輯未來月份
            print("🔧 嘗試編輯月份: \(currentDisplayMonth)")

            if vacationData.isSubmitted {
                showToast("本月排休已提交，無法修改", type: .error)
                return
            }

            // 🔥 修正：檢查是否有老闆發佈的設定（當前顯示月份）
            if !hasBossSettingsForDisplayMonth() {
                let monthText = formatMonthString(currentDisplayMonth)
                showToast("等待老闆發佈 \(monthText) 的排休設定", type: .info)
                return
            }

            withAnimation(.easeInOut(duration: 0.3)) {
                isVacationEditMode = true
            }

        case .clearVacation:
            clearAllVacationData()
        }
    }

    // 🔥 優化：整合週休檢查的日期切換方法
    func toggleVacationDate(_ dateString: String) {
        if vacationData.isSubmitted {
            showToast(message: "已提交排休，無法修改", type: .error)
            return
        }

        let isCurrentlySelected = vacationData.isDateSelected(dateString)
        var newVacationData = vacationData

        // 如果是取消選擇，直接處理
        if isCurrentlySelected {
            newVacationData.removeDate(dateString)
            vacationData = newVacationData
            saveVacationData()
            showToast(message: "已取消排休", type: .info)
            return
        }

        // 檢查月休限制
        if newVacationData.selectedDates.count >= availableVacationDays {
            showToast(message: "已達到本月可排休上限 \(availableVacationDays) 天", type: .error)
            return
        }

        // 🔥 新增：檢查週休限制
        if currentVacationMode == .weekly || currentVacationMode == .monthlyWithWeeklyLimit {
            let weekOfMonth = getWeekOfMonth(for: dateString)
            let currentWeekCount = getWeeklyStats()[weekOfMonth] ?? 0

            if currentWeekCount >= weeklyVacationLimit {
                let weekRangeText = getWeekRangeText(for: weekOfMonth)
                let weekDisplayText = weekRangeText.isEmpty ? "第 \(weekOfMonth) 週" : "第 \(weekOfMonth) 週 (\(weekRangeText))"

                showToast(
                    message: "已超過\(weekDisplayText)最多可排 \(weeklyVacationLimit) 天的限制",
                    type: .weeklyLimit
                )
                return
            }
        }

        // 選擇成功
        newVacationData.addDate(dateString)
        vacationData = newVacationData
        saveVacationData()

        // 🔥 新增：顯示成功訊息
        showVacationSuccessMessage(for: dateString)
    }

    // 🔥 新增：顯示排休成功訊息
    private func showVacationSuccessMessage(for dateString: String) {
        let remainingTotal = availableVacationDays - vacationData.selectedDates.count

        if currentVacationMode == .weekly || currentVacationMode == .monthlyWithWeeklyLimit {
            let weekOfMonth = getWeekOfMonth(for: dateString)
            let currentWeekCount = getWeeklyStats()[weekOfMonth] ?? 0
            let remainingWeekly = weeklyVacationLimit - currentWeekCount

            let weekRangeText = getWeekRangeText(for: weekOfMonth)
            let weekDisplayText = weekRangeText.isEmpty ? "本週" : "本週 (\(weekRangeText))"

            showToast(
                message: "排休成功！還可排休 \(remainingTotal) 天（總計），\(remainingWeekly) 天（\(weekDisplayText)）",
                type: .weeklySuccess
            )
        } else {
            showToast(
                message: "排休成功！還可排休 \(remainingTotal) 天",
                type: .success
            )
        }
    }

    func submitVacation() {
        // 🔥 新增：提交前檢查週休限制
        if currentVacationMode == .weekly || currentVacationMode == .monthlyWithWeeklyLimit {
            let weeklyStats = getWeeklyStats()
            let hasOverLimit = weeklyStats.values.contains { $0 > weeklyVacationLimit }

            if hasOverLimit {
                showToast(
                    message: "請檢查週休限制，每週最多可排 \(weeklyVacationLimit) 天",
                    type: .error
                )
                return
            }
        }

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

    // MARK: - 🔥 新增：週休功能相關方法

    /// 檢查指定日期是否可以在當前模式下選擇
    func canSelectForCurrentMode(day: Int) -> Bool {
        let dateString = String(format: "%@-%02d", currentDisplayMonth, day)

        // 檢查月休限制
        if vacationData.selectedDates.count >= availableVacationDays && !vacationData.isDateSelected(dateString) {
            return false
        }

        // 檢查週休限制
        if currentVacationMode == .weekly || currentVacationMode == .monthlyWithWeeklyLimit {
            let weekOfMonth = getWeekOfMonth(for: dateString)
            let currentWeekCount = getWeeklyStats()[weekOfMonth] ?? 0

            // 如果當前日期已選，可以取消選擇
            if vacationData.isDateSelected(dateString) {
                return true
            }

            // 檢查是否超過週限制
            return currentWeekCount < weeklyVacationLimit
        }

        return true
    }

    /// 應該顯示選擇提示
    func shouldShowSelectionHint(day: Int, canSelect: Bool, isSelected: Bool) -> Bool {
        return canSelect && !isSelected
    }

    /// 獲取指定日期字串的週數
    private func getWeekOfMonth(for dateString: String) -> Int {
        let calendar = Calendar.current
        let dateParts = dateString.split(separator: "-")

        guard dateParts.count == 3,
              let year = Int(dateParts[0]),
              let month = Int(dateParts[1]),
              let day = Int(dateParts[2]) else {
            return 1
        }

        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            return 1
        }

        return calendar.component(.weekOfMonth, from: date)
    }

    /// 獲取週統計
    func getWeeklyStats() -> [Int: Int] {
        return WeekUtils.getWeeklyStats(for: vacationData.selectedDates, in: currentDisplayMonth)
    }

    /// 獲取週範圍文字
    func getWeekRangeText(for weekNumber: Int) -> String {
        let calendar = Calendar.current
        let components = currentDisplayMonth.split(separator: "-")
        guard let year = Int(components[0]), let month = Int(components[1]) else { return "" }

        // 找到該週的任一天來計算範圍
        for day in 1...31 {
            if let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
               calendar.component(.weekOfMonth, from: date) == weekNumber {
                return WeekUtils.formatWeekRange(
                    WeekUtils.getWeekRange(for: date).start,
                    WeekUtils.getWeekRange(for: date).end
                )
            }
        }
        return ""
    }

    /// 驗證當前選擇是否符合週休限制
    func validateWeeklyLimits() -> (isValid: Bool, errorMessage: String?) {
        if currentVacationMode == .weekly || currentVacationMode == .monthlyWithWeeklyLimit {
            let weeklyStats = getWeeklyStats()

            for (week, count) in weeklyStats {
                if count > weeklyVacationLimit {
                    return (false, "第 \(week) 週超過限制（\(count)/\(weeklyVacationLimit)）")
                }
            }
        }

        return (true, nil)
    }

    /// 檢查是否有週休衝突
    func hasWeeklyConflicts() -> Bool {
        let weeklyStats = getWeeklyStats()
        return weeklyStats.values.contains { $0 > weeklyVacationLimit }
    }

    /// 獲取衝突的週數列表
    func getConflictingWeeks() -> [Int] {
        let weeklyStats = getWeeklyStats()
        return weeklyStats.compactMap { week, count in
            count > weeklyVacationLimit ? week : nil
        }.sorted()
    }

    // MARK: - Validation Methods (保留原有方法但已整合到上面)
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
            UserDefaults.standard.set(encoded, forKey: "VacationData_\(currentDisplayMonth)")
        }
    }

    private func loadVacationData() {
        let key = "VacationData_\(currentDisplayMonth)"
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(VacationData.self, from: data) {
            vacationData = decoded
        } else {
            // 如果沒有該月份的數據，初始化為空
            vacationData = VacationData()
        }
        print("📊 載入月份 \(currentDisplayMonth) 的排休數據: \(vacationData.selectedDates.count) 天")
    }

    private func clearAllVacationData() {
        let key = "VacationData_\(currentDisplayMonth)"
        UserDefaults.standard.removeObject(forKey: key)
        vacationData = VacationData()
        showToast("所有排休資料已清除", type: .info)
    }

    // 🔥 新增：統一的 Toast 顯示方法
    func showToast(message: String, type: ToastType) {
        self.toastMessage = message
        self.toastType = type
        self.isToastShowing = true

        // 🔥 新增：根據類型調整自動隱藏時間
        let hideDelay: Double = {
            switch type {
            case .error, .weeklyLimit:
                return 5.0 // 錯誤訊息顯示更久
            case .weeklySuccess:
                return 4.0 // 週休成功訊息顯示久一點
            default:
                return 3.0 // 一般訊息
            }
        }()

        DispatchQueue.main.asyncAfter(deadline: .now() + hideDelay) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.isToastShowing = false
            }
        }
    }
}

// MARK: - Vacation Limits Extension (保持不變)
extension EmployeeCalendarViewModel {

    /// 從管理者設定中載入休假限制（基於當前顯示月份）
    func loadVacationLimitsFromBossSettings() {
        let targetMonth = currentDisplayMonth
        print("🎯 員工端讀取月份: \(targetMonth)")

        let components = targetMonth.split(separator: "-")
        guard components.count == 2,
              let year = Int(components[0]),
              let month = Int(components[1]) else {
            print("❌ 員工端: 無法解析月份 \(targetMonth)")
            return
        }

        let limits = VacationLimitsManager.shared.getVacationLimits(for: year, month: month)

        print("📖 員工端讀取到休假限制:")
        print("   目標月份: \(year)-\(month)")
        print("   類型: \(limits.vacationType.rawValue)")
        print("   月限制: \(limits.monthlyLimit ?? 0)")
        print("   週限制: \(limits.weeklyLimit ?? 0)")
        print("   已發佈: \(limits.isPublished)")

        // 更新 ViewModel 中的限制值
        if let monthlyLimit = limits.monthlyLimit {
            self.availableVacationDays = monthlyLimit
        }

        if let weeklyLimit = limits.weeklyLimit {
            self.weeklyVacationLimit = weeklyLimit
        }

        // 根據老闆設定的類型更新員工端的模式
        switch limits.vacationType {
        case .monthly:
            self.currentVacationMode = .monthly
        case .weekly:
            self.currentVacationMode = .weekly
        case .flexible:
            self.currentVacationMode = .monthly // 默認為月排休
        }

        self.isUsingBossSettings = limits.isPublished

        if limits.isPublished {
            print("✅ 員工端已應用老闆設定")
        } else {
            print("⏳ 員工端使用默認設定（等待老闆發佈）")
        }
    }

    /// 檢查當前顯示月份是否有管理者設定的限制
    func hasBossSettingsForDisplayMonth() -> Bool {
        let components = currentDisplayMonth.split(separator: "-")
        guard components.count == 2,
              let year = Int(components[0]),
              let month = Int(components[1]) else {
            return false
        }

        let hasSettings = VacationLimitsManager.shared.hasLimitsForMonth(year: year, month: month)
        print("🔍 員工端檢查月份 \(currentDisplayMonth) 是否有老闆設定: \(hasSettings)")
        return hasSettings
    }

    /// 獲取當前顯示月份的限制資訊
    func getCurrentDisplayMonthLimits() -> VacationLimits? {
        let components = currentDisplayMonth.split(separator: "-")
        guard components.count == 2,
              let year = Int(components[0]),
              let month = Int(components[1]) else {
            return nil
        }

        return VacationLimitsManager.shared.getVacationLimits(for: year, month: month)
    }

    /// 設置限制更新監聽器
    func setupVacationLimitsListener() {
        print("📡 員工端設置通知監聽器")

        NotificationCenter.default.addObserver(
            forName: .vacationLimitsDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("📬 員工端收到休假設定更新通知")

            if let userInfo = notification.userInfo {
                print("📋 通知詳情: \(userInfo)")

                if let isNewPublication = userInfo["isNewPublication"] as? Bool,
                   let vacationType = userInfo["vacationType"] as? String,
                   let targetMonth = userInfo["targetMonth"] as? String {

                    print("🎯 收到排休設定更新:")
                    print("   類型: \(vacationType)")
                    print("   月份: \(targetMonth)")
                    print("   是否為新發佈: \(isNewPublication)")

                    // 檢查是否是當前顯示月份的設定
                    if targetMonth == self?.currentDisplayMonth {
                        if isNewPublication {
                            self?.showToast(
                                message: "老闆已發佈 \(vacationType) 排休設定，可以開始排休了！",
                                type: .success
                            )
                        } else {
                            self?.showToast(
                                message: "老闆已更新 \(vacationType) 排休設定",
                                type: .info
                            )
                        }

                        // 🔥 重新載入當前顯示月份的設定
                        self?.loadVacationLimitsFromBossSettings()
                    } else {
                        if isNewPublication {
                            self?.showToast(
                                message: "老闆已發佈 \(targetMonth) 的排休設定",
                                type: .info
                            )
                        }
                    }
                }
            }
        }
    }

    /// 移除限制更新監聽器
    func removeVacationLimitsListener() {
        print("📡 員工端移除通知監聽器")
        NotificationCenter.default.removeObserver(
            self,
            name: .vacationLimitsDidUpdate,
            object: nil
        )
    }
}

// MARK: Firebase
extension EmployeeCalendarViewModel {
    private func loadVacationLimitsFromFirebaseForCurrentMonth() {
            let components = currentDisplayMonth.split(separator: "-")
            guard components.count == 2,
                  let year = Int(components[0]),
                  let month = Int(components[1]) else {
                print("❌ 無法解析月份: \(currentDisplayMonth)")
                return
            }

            print("🔍 從 Firebase 載入月份設定: \(year)-\(month)")

            VacationLimitsManager.shared.loadVacationLimitsFromFirebase(for: year, month: month) { [weak self] limits in
                DispatchQueue.main.async {
                    if let limits = limits {
                        print("✅ 從 Firebase 載入成功: \(limits.vacationType.rawValue)")

                        // 更新 ViewModel 中的限制值
                        if let monthlyLimit = limits.monthlyLimit {
                            self?.availableVacationDays = monthlyLimit
                        }

                        if let weeklyLimit = limits.weeklyLimit {
                            self?.weeklyVacationLimit = weeklyLimit
                        }

                        // 根據老闆設定的類型更新員工端的模式
                        switch limits.vacationType {
                        case .monthly:
                            self?.currentVacationMode = .monthly
                        case .weekly:
                            self?.currentVacationMode = .weekly
                        case .flexible:
                            self?.currentVacationMode = .monthly
                        }

                        self?.isUsingBossSettings = limits.isPublished

                        print("✅ 員工端已應用 Firebase 設定")
                        print("   類型: \(limits.vacationType.rawValue)")
                        print("   月限制: \(limits.monthlyLimit ?? 0)")
                        print("   週限制: \(limits.weeklyLimit ?? 0)")

                    } else {
                        print("⏳ Firebase 中無該月份設定，使用默認值")
                        self?.loadVacationLimitsFromBossSettings()
                    }
                }
            }
        }

    // MARK: - 🔥 新增：獲取月份顯示文字
        func getMonthDisplayText() -> String {
            let currentMonth = getCurrentMonthString()

            if currentDisplayMonth == currentMonth {
                return "本月"
            } else {
                return formatMonthString(currentDisplayMonth)
            }
        }

        // MARK: - 🔥 新增：檢查月份是否可以編輯
        func canEditMonth() -> Bool {
            // 允許編輯當前月份和未來月份
            let currentMonth = getCurrentMonthString()
            return currentDisplayMonth >= currentMonth
        }

        // MARK: - 🔥 新增：檢查是否為未來月份
        func isFutureMonth() -> Bool {
            let currentMonth = getCurrentMonthString()
            return currentDisplayMonth > currentMonth
        }

        // MARK: - 🔥 新增：獲取月份編輯狀態文字
        func getMonthEditStatusText() -> String {
            let currentMonth = getCurrentMonthString()

            if currentDisplayMonth == currentMonth {
                return isUsingBossSettings ? "可排休" : "等待發佈"
            } else if currentDisplayMonth > currentMonth {
                return isUsingBossSettings ? "可預約排休" : "等待發佈"
            } else {
                return "已過期"
            }
        }

        // MARK: - 🔥 新增：獲取月份編輯狀態顏色
        func getMonthEditStatusColor() -> Color {
            let currentMonth = getCurrentMonthString()

            if currentDisplayMonth == currentMonth {
                return isUsingBossSettings ? .green : .orange
            } else if currentDisplayMonth > currentMonth {
                return isUsingBossSettings ? .blue : .orange
            } else {
                return .gray
            }
        }
}
