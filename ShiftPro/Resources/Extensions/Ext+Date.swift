//
//  Ext+Date.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/19.
//

import Foundation

extension DateFormatter {
    /// 獲取年份格式化器 (確保顯示 2025 而不是 2,025)
    static var yearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }

    /// 獲取月份年份格式化器
    static var monthYearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月"
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        return formatter
    }

    /// 獲取年月格式化器 (用於 API)
    static var yearMonthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
}

// 🔥 修復：移除有問題的 yearString 擴展，改用簡單的字串轉換
extension CalendarMonth {
    /// 獲取年份字串（無千位分隔符）- 修復版本
    var yearString: String {
        return String(self.year) // 直接轉換，不使用格式化器
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
