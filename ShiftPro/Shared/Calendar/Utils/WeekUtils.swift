//
//  WeekUtils.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/15.
//

import Foundation

/// 提供週次與統計的工具
struct WeekUtils {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// 計算某個 yyyy-MM-dd 在當月第幾週
    static func weekIndex(of dateString: String, in month: String) -> Int {
        guard let date = dateFormatter.date(from: dateString) else { return 1 }
        return Calendar.current.component(.weekOfMonth, from: date)
    }

    /// 計算某週已選的天數
    static func count(in selected: Set<String>, week: Int) -> Int {
        selected.compactMap { dateFormatter.date(from: $0) }
            .filter { Calendar.current.component(.weekOfMonth, from: $0) == week }
            .count
    }

    /// 回傳每週各有多少天
    static func weeklyStats(for selected: Set<String>, in month: String) -> [Int:Int] {
        var stats: [Int:Int] = [:]
        selected.forEach {
            let w = weekIndex(of: $0, in: month)
            stats[w, default: 0] += 1
        }
        return stats
    }

    /// 將第 n 週的範圍顯示成 "M/d-M/d"
    static func formatWeekRange(_ week: Int, in month: String) -> String {
        // 先找到本月第一天
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy-MM"
        guard let firstOfMonth = monthFormatter.date(from: month) else { return "" }

        // 收集當月所有屬於該週的日期
        var dates: [Date] = []
        let range = Calendar.current.range(of: .day, in: .month, for: firstOfMonth)!
        for day in range {
            if let d = Calendar.current.date(byAdding: .day, value: day-1, to: firstOfMonth),
               Calendar.current.component(.weekOfMonth, from: d) == week {
                dates.append(d)
            }
        }
        guard let start = dates.first, let end = dates.last else { return "" }

        let display = DateFormatter()
        display.dateFormat = "M/d"
        return "\(display.string(from: start))-\(display.string(from: end))"
    }
}
