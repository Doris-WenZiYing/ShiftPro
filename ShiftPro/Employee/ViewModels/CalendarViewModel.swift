//
//  CalendarViewModel.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/8.
//

import Foundation
import SwiftUI

class CalendarViewModel: ObservableObject {
    @Published var currentMonth: Date = Date()
    @Published var selectedDate: Date = Date()
    @Published var currentMonthIndex: Int = 0
    @Published var days: [CalendarDay] = []
    @Published var previousMonthDays: [CalendarDay] = []
    @Published var nextMonthDays: [CalendarDay] = []

    private let calendar = Calendar.current

    init() {
        generateAllMonths()
    }

    func generateAllMonths() {
        generateDays(for: currentMonth, into: &days)

        if let prevMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            generateDays(for: prevMonth, into: &previousMonthDays)
        }

        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            generateDays(for: nextMonth, into: &nextMonthDays)
        }
    }

    func generateDays(for month: Date, into daysArray: inout [CalendarDay]) {
        daysArray.removeAll()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!
        let numDays = range.count

        var firstWeekday = calendar.component(.weekday, from: startOfMonth) - 1
        if firstWeekday == 0 { firstWeekday = 7 } // adjust for Sunday = 1

        let prevMonth = calendar.date(byAdding: .month, value: -1, to: month)!
        let prevMonthDays = calendar.range(of: .day, in: .month, for: prevMonth)!
        let prevMonthLastDay = prevMonthDays.count

        // Add days from previous month
        for i in stride(from: firstWeekday - 1, through: 0, by: -1) {
            let day = prevMonthLastDay - i
            if let date = calendar.date(bySetting: .day, value: day, of: prevMonth) {
                daysArray.append(CalendarDay(date: date, isWithinDisplayedMonth: false))
            }
        }

        // Add current month
        for day in 1...numDays {
            if let date = calendar.date(bySetting: .day, value: day, of: month) {
                daysArray.append(CalendarDay(date: date, isWithinDisplayedMonth: true))
            }
        }

        // Fill next month until total days = 42 (7 x 6)
        while daysArray.count < 42 {
            let lastDay = daysArray.last?.date ?? Date()
            if let nextDate = calendar.date(byAdding: .day, value: 1, to: lastDay) {
                daysArray.append(CalendarDay(date: nextDate, isWithinDisplayedMonth: false))
            }
        }
    }

    func getDaysForOffset(_ offset: Int) -> [CalendarDay] {
        // Calculate the target month based on offset
        guard let targetMonth = calendar.date(byAdding: .month, value: offset, to: currentMonth) else {
            return []
        }

        // Generate days for this specific month
        var monthDays: [CalendarDay] = []
        generateDays(for: targetMonth, into: &monthDays)
        return monthDays
    }

    func generateDays() {
        generateDays(for: currentMonth, into: &days)
    }

    func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    // Fix the selection bug: only allow selection of dates within current month
    func isSameDayInCurrentMonth(_ date: Date) -> Bool {
        let selectedComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let currentMonthComponents = calendar.dateComponents([.year, .month], from: currentMonth)

        // Check if it's the same day AND in the current displayed month
        return selectedComponents.year == dateComponents.year &&
               selectedComponents.month == dateComponents.month &&
               selectedComponents.day == dateComponents.day &&
               dateComponents.year == currentMonthComponents.year &&
               dateComponents.month == currentMonthComponents.month
    }

    func handleMonthChange(_ newIndex: Int) {
        if newIndex == 1 {
            // Swiped up - go to next month
            nextMonth()
        } else if newIndex == -1 {
            // Swiped down - go to previous month
            previousMonth()
        }
    }

    // Add month navigation functions
    func nextMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
                currentMonth = newMonth
                generateAllMonths()
            }
        }
    }

    func previousMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
                currentMonth = newMonth
                generateAllMonths()
            }
        }
    }
}
