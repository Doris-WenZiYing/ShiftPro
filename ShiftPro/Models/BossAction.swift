//
//  BossAction.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/19.
//

import Foundation
import SwiftUI

public enum BossAction: String, CaseIterable {
    case publishVacation = "publish_vacation"
    case unpublishVacation = "unpublish_vacation"
    case publishSchedule = "publish_schedule"
    case unpublishSchedule = "unpublish_schedule"
    case manageVacationLimits = "manage_vacation_limits"
    case viewReports = "view_reports"
    case manageEmployees = "manage_employees"

    public var displayName: String {
        switch self {
        case .publishVacation: return "發佈休假設定"
        case .unpublishVacation: return "取消發佈休假"
        case .publishSchedule: return "發佈班表"
        case .unpublishSchedule: return "取消發佈班表"
        case .manageVacationLimits: return "管理休假限制"
        case .viewReports: return "查看報表"
        case .manageEmployees: return "管理員工"
        }
    }

    public var icon: String {
        switch self {
        case .publishVacation: return "calendar.badge.checkmark"
        case .unpublishVacation: return "calendar.badge.minus"
        case .publishSchedule: return "calendar.badge.clock"
        case .unpublishSchedule: return "calendar.badge.exclamationmark"
        case .manageVacationLimits: return "gearshape.fill"
        case .viewReports: return "chart.bar.fill"
        case .manageEmployees: return "person.3.fill"
        }
    }

    // MARK: - Bottom Sheet 專用屬性

    public var title: String {
        return displayName
    }

    public var subtitle: String {
        switch self {
        case .publishVacation: return "設定員工排休規則並發佈"
        case .unpublishVacation: return "停止員工排休並收回設定"
        case .publishSchedule: return "發佈月班表供員工查看"
        case .unpublishSchedule: return "撤回已發佈的班表"
        case .manageVacationLimits: return "調整休假天數限制"
        case .viewReports: return "查看排班統計報表"
        case .manageEmployees: return "新增、編輯員工資料"
        }
    }

    public var iconName: String {
        return icon
    }

    public var color: ActionColor {
        switch self {
        case .publishVacation: return ActionColor(primary: "blue")
        case .unpublishVacation: return ActionColor(primary: "orange")
        case .publishSchedule: return ActionColor(primary: "green")
        case .unpublishSchedule: return ActionColor(primary: "red")
        case .manageVacationLimits: return ActionColor(primary: "purple")
        case .viewReports: return ActionColor(primary: "blue")
        case .manageEmployees: return ActionColor(primary: "gray")
        }
    }
}

// MARK: - 支援結構
public struct ActionColor {
    public let primary: String

    public init(primary: String) {
        self.primary = primary
    }
}
