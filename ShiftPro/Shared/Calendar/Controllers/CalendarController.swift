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
    // MARK: - Published Properties （保持與原有系統兼容）
    @Published public var yearMonth: CalendarMonth
    @Published public var selectedDate: CalendarDate?
    @Published internal var position: Int = CalendarConstants.centerPage // 🔥 保留，InfiniteScrollView 需要

    // MARK: - Internal Properties
    public let orientation: CalendarOrientation
    internal let scrollDetector: CurrentValueSubject<CGFloat, Never>
    internal var cancellables = Set<AnyCancellable>()

    // MARK: - 🔥 移除的防抖屬性（這些導致了問題）
    // 移除: isUserInitiated, lastLoggedMonth, isProcessingAuthChange
    // 移除: hasSetupAuthListener, lastStatusUpdate 等複雜防抖邏輯

    public init(orientation: CalendarOrientation = .vertical, month: CalendarMonth = .current) {
        let detector = CurrentValueSubject<CGFloat, Never>(0)

        self.orientation = orientation
        self.scrollDetector = detector
        self.yearMonth = month
        self.selectedDate = CalendarDate.today

        print("📅 CalendarController 初始化: \(formatMonth(month))")

        // 🔥 簡化但保留基本滾動檢測（參考 SwiftUICalendar 模式）
        detector
            .dropFirst()
            .sink { [weak self] value in
                self?.handleScrollChange(value)
            }
            .store(in: &cancellables)
    }

    // MARK: - 🔥 簡化的滾動處理（保留核心邏輯，移除防抖）
    private func handleScrollChange(_ value: CGFloat) {
        let move = position - CalendarConstants.centerPage
        let newMonth = yearMonth.addMonths(move)

        // 🔥 關鍵修復：只做必要的更新，移除複雜的防抖和狀態檢查
        if newMonth != yearMonth && abs(move) <= 1 {
            yearMonth = newMonth
            position = CalendarConstants.centerPage
            print("📅 Calendar 月份變化: \(formatMonth(newMonth))")
        }
    }

    // MARK: - 🔥 簡化的公開方法（保持 API 兼容性）
    public func setYearMonth(_ month: CalendarMonth) {
        guard month != yearMonth else { return }

        // 🔥 直接更新，移除所有防抖檢查和用戶意圖追蹤
        yearMonth = month
        position = CalendarConstants.centerPage
        print("📅 Calendar 手動設定月份: \(formatMonth(month))")
    }

    public func setYearMonth(year: Int, month: Int) {
        setYearMonth(CalendarMonth(year: year, month: month))
    }

    // MARK: - 導航方法（簡化版）
    public func navigateToMonth(year: Int, month: Int) {
        setYearMonth(year: year, month: month)
    }

    public func navigateToNextMonth() {
        let nextMonth = yearMonth.addMonths(1)
        setYearMonth(nextMonth)
    }

    public func navigateToPreviousMonth() {
        let previousMonth = yearMonth.addMonths(-1)
        setYearMonth(previousMonth)
    }

    // MARK: - 日期選擇方法
    public func selectDate(_ date: CalendarDate) {
        selectedDate = date
    }

    public func isDateSelected(_ date: CalendarDate) -> Bool {
        guard let selected = selectedDate else { return false }
        return selected == date
    }

    // MARK: - 🔥 為了兼容性保留的內部屬性
    var internalYearMonth: CalendarMonth {
        return yearMonth
    }

    // MARK: - 基本輔助方法
    private func formatMonth(_ month: CalendarMonth) -> String {
        return "\(month.year)年\(String(format: "%02d", month.month))月"
    }

    // MARK: - 🔥 保留基本驗證，移除過度的安全檢查
    func isValidMonth(_ month: CalendarMonth) -> Bool {
        let currentYear = Calendar.current.component(.year, from: Date())
        return month.year >= currentYear - 2 && month.year <= currentYear + 5
    }
}
