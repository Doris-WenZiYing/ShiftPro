//
//  CalendarDate.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/9.
//

import Foundation

public struct CalendarDate: Equatable, Hashable {
    public let year: Int
    public let month: Int
    public let day: Int
    public let isCurrentMonth: Bool?

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
        self.isCurrentMonth = nil
    }

    public init(year: Int, month: Int, day: Int, isCurrentMonth: Bool) {
        self.year = year
        self.month = month
        self.day = day
        self.isCurrentMonth = isCurrentMonth
    }

    public static var today: CalendarDate {
        let date = Date()
        return CalendarDate(
            year: Calendar.current.component(.year, from: date),
            month: Calendar.current.component(.month, from: date),
            day: Calendar.current.component(.day, from: date)
        )
    }

    public static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.year == rhs.year && lhs.month == rhs.month && lhs.day == rhs.day
    }

    public var isToday: Bool {
        let today = Date()
        let year = Calendar.current.component(.year, from: today)
        let month = Calendar.current.component(.month, from: today)
        let day = Calendar.current.component(.day, from: today)
        return self.year == year && self.month == month && self.day == day
    }

    public var date: Date? {
        var components = DateComponents()
        components.year = self.year
        components.month = self.month
        components.day = self.day
        return Calendar.current.date(from: components)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.year)
        hasher.combine(self.month)
        hasher.combine(self.day)
    }
}
