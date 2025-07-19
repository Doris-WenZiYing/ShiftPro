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

extension Int {
    /// 將年份整數格式化為字串 (確保沒有千位分隔符)
    var yearString: String {
        let formatter = NumberFormatter()
        formatter.groupingSeparator = ""
        formatter.numberStyle = .none
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: self)) ?? String(self)
    }
}

extension CalendarMonth {
    /// 獲取年份字串（無千位分隔符）
    var yearString: String {
        return year.yearString
    }
}
