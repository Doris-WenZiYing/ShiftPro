//
//  VacationMode.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/10.
//

import Foundation

enum VacationMode: String, CaseIterable {
    case monthly = "月排休"
    case weekly = "週排休"
    case monthlyWithWeeklyLimit = "月排休(週限制)"

    var description: String {
        switch self {
        case .monthly:
            return "每月可排休指定天數，無週限制"
        case .weekly:
            return "每週可排休指定天數"
        case .monthlyWithWeeklyLimit:
            return "每月可排休指定天數，且每週有天數限制"
        }
    }

    var icon: String {
        switch self {
        case .monthly:
            return "calendar"
        case .weekly:
            return "calendar.day.timeline.leading"
        case .monthlyWithWeeklyLimit:
            return "calendar.badge.clock"
        }
    }
}
