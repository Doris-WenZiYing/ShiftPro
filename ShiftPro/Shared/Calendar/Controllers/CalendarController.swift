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

    // 🔥 新增：控制日誌輸出
    private var isUserInitiated = false
    private var lastLoggedMonth: CalendarMonth?

    public init(orientation: CalendarOrientation = .vertical, month: CalendarMonth = .current) {
        let detector = CurrentValueSubject<CGFloat, Never>(0)

        self.orientation = orientation
        self.scrollDetector = detector
        self.internalYearMonth = month
        self.yearMonth = month
        self.selectedDate = CalendarDate.today
        self.lastLoggedMonth = month

        detector
            .debounce(for: .seconds(0.2), scheduler: DispatchQueue.main)
            .dropFirst()
            .sink { [weak self] value in
                if let self = self {
                    let move = self.position - CalendarConstants.centerPage
                    let newMonth = self.internalYearMonth.addMonths(move)

                    // 🔥 只在真正變化時記錄
                    if newMonth != self.yearMonth {
                        self.internalYearMonth = newMonth
                        self.yearMonth = newMonth

                        // 🔥 控制日誌輸出頻率
                        if self.shouldLogMonthChange(newMonth) {
                            print("📅 Calendar 月份變化: \(self.formatMonth(newMonth))")
                            self.lastLoggedMonth = newMonth
                        }
                    }

                    self.position = CalendarConstants.centerPage
                    self.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
    }

    // 🔥 新增：控制是否應該記錄月份變化
    private func shouldLogMonthChange(_ month: CalendarMonth) -> Bool {
        // 如果是用戶主動操作，總是記錄
        if isUserInitiated {
            isUserInitiated = false
            return true
        }

        // 如果與上次記錄的月份不同，且時間間隔合理，才記錄
        guard let lastMonth = lastLoggedMonth else { return true }

        let monthDiff = abs((month.year * 12 + month.month) - (lastMonth.year * 12 + lastMonth.month))
        return monthDiff >= 1 // 至少差一個月才記錄
    }

    private func formatMonth(_ month: CalendarMonth) -> String {
        return "\(month.year)年\(String(format: "%02d", month.month))月"
    }

    public func setYearMonth(year: Int, month: Int) {
        self.setYearMonth(CalendarMonth(year: year, month: month))
    }

    public func setYearMonth(_ month: CalendarMonth) {
        // 🔥 標記為用戶主動操作
        isUserInitiated = true

        self.yearMonth = month
        self.internalYearMonth = month
        self.position = CalendarConstants.centerPage
        self.objectWillChange.send()

        print("📅 Calendar 用戶設定月份: \(formatMonth(month))")
    }

    public func selectDate(_ date: CalendarDate) {
        self.selectedDate = date
    }

    public func isDateSelected(_ date: CalendarDate) -> Bool {
        guard let selected = selectedDate else { return false }
        return selected == date
    }

    // 🔥 新增：靜默導航（不產生日誌）
    func silentNavigateToMonth(year: Int, month: Int) {
        let targetMonth = CalendarMonth(year: year, month: month)

        // 不觸發用戶操作標記
        self.yearMonth = targetMonth
        self.internalYearMonth = targetMonth
        self.position = CalendarConstants.centerPage
        self.objectWillChange.send()
    }
}

extension CalendarController {
    func navigateToMonth(year: Int, month: Int) {
        self.setYearMonth(year: year, month: month)
    }
}
