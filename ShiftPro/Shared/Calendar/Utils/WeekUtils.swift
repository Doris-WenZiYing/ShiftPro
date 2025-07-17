//
//  WeekUtils.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/15.
//

import Foundation

struct WeekUtils {

    /// 獲取指定日期所在週的起始日和結束日（週一到週日）
    static func getWeekRange(for date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current

        // 設定週一為一週的開始
        var calendarConfig = calendar
        calendarConfig.firstWeekday = 2 // 2 = 週一

        let startOfWeek = calendarConfig.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        let endOfWeek = calendarConfig.date(byAdding: .day, value: 6, to: startOfWeek) ?? date

        return (start: startOfWeek, end: endOfWeek)
    }

    /// 獲取指定日期在當月的第幾週
    static func getWeekOfMonth(for date: Date) -> Int {
        let calendar = Calendar.current
        return calendar.component(.weekOfMonth, from: date)
    }

    /// 判斷兩個日期是否在同一週
    static func isSameWeek(_ date1: Date, _ date2: Date) -> Bool {
        let weekRange1 = getWeekRange(for: date1)
        let weekRange2 = getWeekRange(for: date2)

        return Calendar.current.isDate(weekRange1.start, inSameDayAs: weekRange2.start)
    }

    /// 獲取某月所有週的範圍
    static func getWeeksInMonth(year: Int, month: Int) -> [(weekNumber: Int, start: Date, end: Date)] {
        let calendar = Calendar.current
        guard let firstDayOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: firstDayOfMonth) else {
            return []
        }

        var weeks: [(weekNumber: Int, start: Date, end: Date)] = []
        var currentWeek = 1

        for day in 1...range.count {
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
                continue
            }

            let weekOfMonth = calendar.component(.weekOfMonth, from: date)
            if weekOfMonth != currentWeek {
                currentWeek = weekOfMonth
            }

            // 如果這是這週的第一天（在當月範圍內）
            if !weeks.contains(where: { $0.weekNumber == weekOfMonth }) {
                let weekRange = getWeekRange(for: date)
                weeks.append((weekNumber: weekOfMonth, start: weekRange.start, end: weekRange.end))
            }
        }

        return weeks.sorted { $0.weekNumber < $1.weekNumber }
    }

    /// 格式化週範圍顯示文字
    static func formatWeekRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"

        let startStr = formatter.string(from: start)
        let endStr = formatter.string(from: end)

        return "\(startStr) - \(endStr)"
    }

    /// 根據日期字符串獲取週數統計
    static func getWeeklyStats(for dateStrings: Set<String>, in monthString: String) -> [Int: Int] {
        var weeklyStats: [Int: Int] = [:]
        let calendar = Calendar.current

        let components = monthString.split(separator: "-")
        guard components.count >= 2,
              let year = Int(components[0]),
              let month = Int(components[1]) else {
            return weeklyStats
        }

        for dateString in dateStrings {
            let dateParts = dateString.split(separator: "-")
            if dateParts.count == 3,
               let dayNum = Int(dateParts[2]),
               let dateYear = Int(dateParts[0]),
               let dateMonth = Int(dateParts[1]),
               dateYear == year && dateMonth == month {

                if let date = calendar.date(from: DateComponents(year: year, month: month, day: dayNum)) {
                    let weekOfMonth = calendar.component(.weekOfMonth, from: date)
                    weeklyStats[weekOfMonth, default: 0] += 1
                }
            }
        }

        return weeklyStats
    }
}
