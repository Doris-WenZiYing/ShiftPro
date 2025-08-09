//
//  CalendarController.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/9.
//

import SwiftUI
import Combine

public enum CalendarOrientation {
    case horizontal
    case vertical
}

public class CalendarController: ObservableObject {
    @Published public var yearMonth: CalendarMonth
    @Published public var selectedDate: CalendarDate?
    @Published internal var position: Int = CalendarConstants.centerPage
    @Published internal var internalYearMonth: CalendarMonth

    public let orientation: CalendarOrientation
    internal let scrollDetector: CurrentValueSubject<CGFloat, Never>
    internal var cancellables = Set<AnyCancellable>()

    private var isUserInitiated = false
    private var lastLoggedMonth: CalendarMonth?
    private var isUpdating = false  // 防止重複更新
    private var lastUpdateTime: Date = Date.distantPast
    private let minUpdateInterval: TimeInterval = 0.3  // 最小更新間隔

    public init(orientation: CalendarOrientation = .vertical, month: CalendarMonth = .current) {
        let detector = CurrentValueSubject<CGFloat, Never>(0)

        self.orientation = orientation
        self.scrollDetector = detector
        self.internalYearMonth = month
        self.yearMonth = month
        self.selectedDate = CalendarDate.today
        self.lastLoggedMonth = month

        // 🔥 修復：更穩定的滾動檢測
        detector
            .debounce(for: .seconds(0.3), scheduler: DispatchQueue.main)  // 增加防抖時間
            .dropFirst()
            .sink { [weak self] value in
                self?.handleScrollChange(value)
            }
            .store(in: &cancellables)

        print("📅 CalendarController 初始化: \(formatMonth(month))")
    }

    // 🔥 修復：穩定的滾動變化處理
    private func handleScrollChange(_ value: CGFloat) {
        guard !isUpdating else { return }

        let now = Date()
        guard now.timeIntervalSince(lastUpdateTime) >= minUpdateInterval else { return }

        isUpdating = true
        lastUpdateTime = now

        let move = position - CalendarConstants.centerPage
        let newMonth = internalYearMonth.addMonths(move)

        // 🔥 只在真正變化且變化合理時更新
        if newMonth != yearMonth && abs(move) <= 1 {
            let oldMonth = yearMonth
            internalYearMonth = newMonth
            yearMonth = newMonth

            // 🔥 控制日誌輸出頻率
            if shouldLogMonthChange(newMonth) {
                print("📅 Calendar 滾動變化: \(formatMonth(oldMonth)) → \(formatMonth(newMonth))")
                lastLoggedMonth = newMonth
            }
        }

        // 🔥 穩定重置位置
        DispatchQueue.main.async {
            self.position = CalendarConstants.centerPage
            self.isUpdating = false
            self.objectWillChange.send()
        }
    }

    // 🔥 修復：控制是否應該記錄月份變化
    private func shouldLogMonthChange(_ month: CalendarMonth) -> Bool {
        // 如果是用戶主動操作，總是記錄
        if isUserInitiated {
            isUserInitiated = false
            return true
        }

        // 如果與上次記錄的月份不同，且時間間隔合理，才記錄
        guard let lastMonth = lastLoggedMonth else { return true }

        let monthDiff = abs((month.year * 12 + month.month) - (lastMonth.year * 12 + lastMonth.month))
        return monthDiff >= 1
    }

    private func formatMonth(_ month: CalendarMonth) -> String {
        return "\(month.year)年\(String(format: "%02d", month.month))月"
    }

    // 🔥 修復：安全的月份設定
    public func setYearMonth(year: Int, month: Int) {
        setYearMonth(CalendarMonth(year: year, month: month))
    }

    public func setYearMonth(_ month: CalendarMonth) {
        guard !isUpdating else { return }

        // 🔥 防止無效更新
        guard month != yearMonth else { return }

        isUpdating = true
        isUserInitiated = true

        yearMonth = month
        internalYearMonth = month
        position = CalendarConstants.centerPage

        DispatchQueue.main.async {
            self.isUpdating = false
            self.objectWillChange.send()
        }

        print("📅 Calendar 用戶設定月份: \(formatMonth(month))")
    }

    public func selectDate(_ date: CalendarDate) {
        selectedDate = date
    }

    public func isDateSelected(_ date: CalendarDate) -> Bool {
        guard let selected = selectedDate else { return false }
        return selected == date
    }

    // 🔥 新增：靜默導航（不產生日誌，不觸發更新檢查）
    func silentNavigateToMonth(year: Int, month: Int) {
        let targetMonth = CalendarMonth(year: year, month: month)

        guard targetMonth != yearMonth else { return }
        guard !isUpdating else { return }

        // 直接更新，不觸發用戶操作標記
        yearMonth = targetMonth
        internalYearMonth = targetMonth
        position = CalendarConstants.centerPage

        // 不設置 isUserInitiated，避免產生日誌
        objectWillChange.send()
    }

    // 🔥 修復：安全的月份導航
    public func navigateToMonth(year: Int, month: Int) {
        guard !isUpdating else { return }
        setYearMonth(year: year, month: month)
    }

    // 🔥 新增：月份導航方法
    public func navigateToNextMonth() {
        let nextMonth = yearMonth.addMonths(1)
        setYearMonth(nextMonth)
    }

    public func navigateToPreviousMonth() {
        let previousMonth = yearMonth.addMonths(-1)
        setYearMonth(previousMonth)
    }

    // 🔥 新增：檢查是否可以安全更新
    public func canUpdate() -> Bool {
        return !isUpdating
    }

    // 🔥 新增：強制重置狀態（如果遇到異常）
    public func resetState() {
        isUpdating = false
        position = CalendarConstants.centerPage
        objectWillChange.send()
        print("🔄 Calendar 狀態已重置")
    }
}

// 🔥 新增：CalendarController 的安全擴展
extension CalendarController {
    // 檢查月份是否在合理範圍內
    func isValidMonth(_ month: CalendarMonth) -> Bool {
        let currentYear = Calendar.current.component(.year, from: Date())
        return month.year >= currentYear - 2 && month.year <= currentYear + 5
    }

    // 安全的月份切換，帶驗證
    func safeNavigateToMonth(year: Int, month: Int) -> Bool {
        let targetMonth = CalendarMonth(year: year, month: month)

        guard isValidMonth(targetMonth) else {
            print("⚠️ 無效的月份: \(year)-\(month)")
            return false
        }

        guard canUpdate() else {
            print("⚠️ Calendar 正在更新中，無法導航")
            return false
        }

        setYearMonth(targetMonth)
        return true
    }
}
