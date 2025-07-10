//
//  VacationLimits.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/9.
//

import Foundation

enum VacationLimitType {
    case monthly(days: Int)
    case weekly(days: Int)
    case both(monthly: Int, weekly: Int)
}

struct VacationLimits {
    let type: VacationLimitType

    var monthlyLimit: Int? {
        switch type {
        case .monthly(let days):
            return days
        case .both(let monthly, _):
            return monthly
        case .weekly:
            return nil
        }
    }

    var weeklyLimit: Int? {
        switch type {
        case .weekly(let days):
            return days
        case .both(_, let weekly):
            return weekly
        case .monthly:
            return nil
        }
    }

    var displayText: String {
        switch type {
        case .monthly(let days):
            return "本月最多 \(days) 天"
        case .weekly(let days):
            return "每週最多 \(days) 天"
        case .both(let monthly, let weekly):
            return "本月最多 \(monthly) 天，每週最多 \(weekly) 天"
        }
    }

    // 預設配置 - 可以根據老闆設定調整
    static let monthlyOnly = VacationLimits(type: .monthly(days: 4))
    static let weeklyOnly = VacationLimits(type: .weekly(days: 1))
    static let bothLimits = VacationLimits(type: .both(monthly: 4, weekly: 1))
    static let `default` = monthlyOnly // 預設使用月限制
}
