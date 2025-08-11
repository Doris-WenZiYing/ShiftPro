//
//  Ext+Date.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/19.
//

import Foundation

extension CalendarMonth {
    var yearString: String {
        return String(self.year)
    }

    /// 獲取完整的年月顯示字串
    var displayString: String {
        return "\(String(self.year))年\(String(format: "%02d", self.month))月"
    }

    /// 🔥 新增：獲取當前實際月份
    static var currentActual: CalendarMonth {
        let now = Date()
        return CalendarMonth(
            year: Calendar.current.component(.year, from: now),
            month: Calendar.current.component(.month, from: now)
        )
    }

    /// 🔥 新增：轉換為 yyyy-MM 格式字串
    var monthKey: String {
        return String(format: "%04d-%02d", self.year, self.month)
    }
}
