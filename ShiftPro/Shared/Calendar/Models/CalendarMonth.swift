//
//  CalendarMonth.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/9.
//

import Foundation

public struct CalendarMonth: Equatable, Hashable {
    public let year: Int
    public let month: Int

    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    public static var current: CalendarMonth {
        let today = Date()
        return CalendarMonth(
            year: Calendar.current.component(.year, from: today),
            month: Calendar.current.component(.month, from: today)
        )
    }

    public static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.year == rhs.year && lhs.month == rhs.month
    }

    public var monthName: String {
        var components = DateComponents()
        components.year = self.year
        components.month = self.month
        components.day = 1

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: Calendar.current.date(from: components)!)
    }

    public var shortMonthName: String {
        var components = DateComponents()
        components.year = self.year
        components.month = self.month
        components.day = 1

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: Calendar.current.date(from: components)!)
    }

    public func addMonths(_ value: Int) -> CalendarMonth {
        var components = DateComponents()
        components.year = self.year
        components.month = self.month
        components.day = 1

        let date = Calendar.current.date(from: components)!
        let newDate = Calendar.current.date(byAdding: .month, value: value, to: date)!

        return CalendarMonth(
            year: Calendar.current.component(.year, from: newDate),
            month: Calendar.current.component(.month, from: newDate)
        )
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.year)
        hasher.combine(self.month)
    }

    internal func getDaysInMonth(offset: Int) -> [CalendarDate] {
        let targetMonth = self.addMonths(offset)
        var components = DateComponents()
        components.year = targetMonth.year
        components.month = targetMonth.month
        components.day = 1

        let startOfMonth = Calendar.current.date(from: components)!
        let range = Calendar.current.range(of: .day, in: .month, for: startOfMonth)!
        let daysInMonth = range.count

        var firstWeekday = Calendar.current.component(.weekday, from: startOfMonth) - 1
        if firstWeekday == 0 { firstWeekday = 7 }

        var dates: [CalendarDate] = []

        // Previous month days
        let prevMonth = targetMonth.addMonths(-1)
        let prevMonthStart = Calendar.current.date(from: DateComponents(year: prevMonth.year, month: prevMonth.month, day: 1))!
        let prevMonthDays = Calendar.current.range(of: .day, in: .month, for: prevMonthStart)!.count

        for i in stride(from: firstWeekday - 1, through: 0, by: -1) {
            let day = prevMonthDays - i
            dates.append(CalendarDate(year: prevMonth.year, month: prevMonth.month, day: day, isCurrentMonth: false))
        }

        // Current month days
        for day in 1...daysInMonth {
            dates.append(CalendarDate(year: targetMonth.year, month: targetMonth.month, day: day, isCurrentMonth: true))
        }

        // Next month days
        let nextMonth = targetMonth.addMonths(1)
        var nextMonthDay = 1
        while dates.count < 42 {
            dates.append(CalendarDate(year: nextMonth.year, month: nextMonth.month, day: nextMonthDay, isCurrentMonth: false))
            nextMonthDay += 1
        }

        return dates
    }
}
