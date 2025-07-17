//
//  BossAction.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/11.
//

import Foundation

enum BossAction: CaseIterable {
    case publishVacation
    case publishSchedule
    case unpublishVacation
    case unpublishSchedule
    case manageVacationLimits

    var title: String {
        switch self {
        case .publishVacation:
            return "發佈排休"
        case .publishSchedule:
            return "發佈班表"
        case .unpublishVacation:
            return "取消發佈排休"
        case .unpublishSchedule:
            return "取消發佈班表"
        case .manageVacationLimits:
            return "管理休假限制"
        }
    }

    var subtitle: String {
        switch self {
        case .publishVacation:
            return "設定並發佈員工休假安排"
        case .publishSchedule:
            return "設定並發佈工作班表"
        case .unpublishVacation:
            return "撤回已發佈的休假安排"
        case .unpublishSchedule:
            return "撤回已發佈的工作班表"
        case .manageVacationLimits:
            return "設定休假天數限制規則"
        }
    }

    var iconName: String {
        switch self {
        case .publishVacation:
            return "calendar.badge.checkmark"
        case .publishSchedule:
            return "calendar.badge.clock"
        case .unpublishVacation:
            return "calendar.badge.minus"
        case .unpublishSchedule:
            return "calendar.badge.exclamationmark"
        case .manageVacationLimits:
            return "gearshape.fill"
        }
    }

    var color: (primary: String, secondary: String) {
        switch self {
        case .publishVacation:
            return ("blue", "blue")
        case .publishSchedule:
            return ("green", "green")
        case .unpublishVacation:
            return ("orange", "orange")
        case .unpublishSchedule:
            return ("red", "red")
        case .manageVacationLimits:
            return ("gray", "gray")
        }
    }
}
