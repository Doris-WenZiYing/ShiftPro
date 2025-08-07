//
//  CoreModels.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/8/7.
//

import Foundation

// MARK: - 🏢 Core Domain Models

// MARK: - User & Organization Models
public enum UserRole: String, CaseIterable, Codable {
    case boss = "boss"
    case employee = "employee"

    public var displayName: String {
        switch self {
        case .boss: return "管理者"
        case .employee: return "員工"
        }
    }

    public var icon: String {
        switch self {
        case .boss: return "crown.fill"
        case .employee: return "person.fill"
        }
    }
}

public struct UserProfile: Codable, Identifiable {
    public let id: String
    public let name: String
    public let role: UserRole
    public let orgId: String
    public let employeeId: String?

    public init(id: String, name: String, role: UserRole, orgId: String, employeeId: String?) {
        self.id = id
        self.name = name
        self.role = role
        self.orgId = orgId
        self.employeeId = employeeId
    }
}

public struct OrganizationProfile: Codable, Identifiable {
    public let id: String
    public let name: String
    public let bossId: String?
    public let createdAt: Date

    public init(id: String, name: String, bossId: String?, createdAt: Date) {
        self.id = id
        self.name = name
        self.bossId = bossId
        self.createdAt = createdAt
    }
}

// MARK: - 📅 Calendar Models

public struct CalendarDate: Equatable, Hashable, Codable {
    public let year: Int
    public let month: Int
    public let day: Int
    public let isCurrentMonth: Bool?

    public init(year: Int, month: Int, day: Int, isCurrentMonth: Bool? = nil) {
        self.year = year
        self.month = month
        self.day = day
        self.isCurrentMonth = isCurrentMonth
    }

    public static var today: CalendarDate {
        let date = Date()
        let calendar = Calendar.current
        return CalendarDate(
            year: calendar.component(.year, from: date),
            month: calendar.component(.month, from: date),
            day: calendar.component(.day, from: date)
        )
    }

    public var isToday: Bool {
        let today = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: today)
        let month = calendar.component(.month, from: today)
        let day = calendar.component(.day, from: today)
        return self.year == year && self.month == month && self.day == day
    }

    public var date: Date? {
        var components = DateComponents()
        components.year = self.year
        components.month = self.month
        components.day = self.day
        return Calendar.current.date(from: components)
    }

    /// 格式化為 "yyyy-MM-dd" 字串
    public var dateString: String {
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

public struct CalendarMonth: Equatable, Hashable, Codable {
    public let year: Int
    public let month: Int

    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    public static var current: CalendarMonth {
        let today = Date()
        let calendar = Calendar.current
        return CalendarMonth(
            year: calendar.component(.year, from: today),
            month: calendar.component(.month, from: today)
        )
    }

    public var monthName: String {
        var components = DateComponents()
        components.year = self.year
        components.month = self.month
        components.day = 1

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: Calendar.current.date(from: components)!)
    }

    public func addMonths(_ value: Int) -> CalendarMonth {
        var components = DateComponents()
        components.year = self.year
        components.month = self.month
        components.day = 1

        let date = Calendar.current.date(from: components)!
        let newDate = Calendar.current.date(byAdding: .month, value: value, to: date)!

        return CalendarMonth(
            year: Calendar.current.component(.year, from: newDate),
            month: Calendar.current.component(.month, from: newDate)
        )
    }

    internal func getDaysInMonth(offset: Int) -> [CalendarDate] {
        let targetMonth = self.addMonths(offset)
        var components = DateComponents()
        components.year = targetMonth.year
        components.month = targetMonth.month
        components.day = 1

        let startOfMonth = Calendar.current.date(from: components)!
        let range = Calendar.current.range(of: .day, in: .month, for: startOfMonth)!
        let daysInMonth = range.count

        var firstWeekday = Calendar.current.component(.weekday, from: startOfMonth) - 1
        if firstWeekday == 0 { firstWeekday = 7 }

        var dates: [CalendarDate] = []

        // Previous month days
        let prevMonth = targetMonth.addMonths(-1)
        let prevMonthStart = Calendar.current.date(from: DateComponents(year: prevMonth.year, month: prevMonth.month, day: 1))!
        let prevMonthDays = Calendar.current.range(of: .day, in: .month, for: prevMonthStart)!.count

        for i in stride(from: firstWeekday - 1, through: 0, by: -1) {
            let day = prevMonthDays - i
            dates.append(CalendarDate(year: prevMonth.year, month: prevMonth.month, day: day, isCurrentMonth: false))
        }

        // Current month days
        for day in 1...daysInMonth {
            dates.append(CalendarDate(year: targetMonth.year, month: targetMonth.month, day: day, isCurrentMonth: true))
        }

        // Next month days
        let nextMonth = targetMonth.addMonths(1)
        var nextMonthDay = 1
        while dates.count < 42 {
            dates.append(CalendarDate(year: nextMonth.year, month: nextMonth.month, day: nextMonthDay, isCurrentMonth: false))
            nextMonthDay += 1
        }

        return dates
    }
}

// MARK: - 🏖️ Vacation & Schedule Models

public enum VacationType: String, CaseIterable, Codable {
    case weekly = "週休"
    case monthly = "月休"
    case flexible = "彈性"

    public var displayName: String { rawValue }

    public var description: String {
        switch self {
        case .weekly: return "每週固定休假天數"
        case .monthly: return "每月總休假天數"
        case .flexible: return "彈性休假安排"
        }
    }
}

public enum VacationMode: String, CaseIterable, Codable {
    case weekly
    case monthly
    case monthlyWithWeeklyLimit = "monthlyWithWeeklyLimit"

    public var displayName: String {
        switch self {
        case .weekly: return "週休"
        case .monthly: return "月休"
        case .monthlyWithWeeklyLimit: return "月休(含週限制)"
        }
    }

    public var description: String {
        switch self {
        case .weekly: return "每週可排休指定天數"
        case .monthly: return "每月可排休指定天數，無週限制"
        case .monthlyWithWeeklyLimit: return "每月可排休指定天數，且每週有天數限制"
        }
    }

    public var icon: String {
        switch self {
        case .weekly: return "calendar.day.timeline.leading"
        case .monthly: return "calendar"
        case .monthlyWithWeeklyLimit: return "calendar.badge.clock"
        }
    }
}

/// 老闆發佈的排休設定
public struct VacationSetting: Codable {
    public let type: VacationType
    public let allowedDays: Int
    public let year: Int
    public let month: Int
    public let publishDate: Date

    public init(type: VacationType, allowedDays: Int, year: Int, month: Int, publishDate: Date = Date()) {
        self.type = type
        self.allowedDays = allowedDays
        self.year = year
        self.month = month
        self.publishDate = publishDate
    }
}

/// 員工的排休資料
public struct VacationData: Codable {
    public var selectedDates: Set<String>
    public var isSubmitted: Bool
    public var currentMonth: String

    public init() {
        self.selectedDates = []
        self.isSubmitted = false
        self.currentMonth = ""
    }

    public init(selectedDates: Set<String>, isSubmitted: Bool, currentMonth: String) {
        self.selectedDates = selectedDates
        self.isSubmitted = isSubmitted
        self.currentMonth = currentMonth
    }

    /// 檢查日期是否已選擇
    public func isDateSelected(_ dateString: String) -> Bool {
        return selectedDates.contains(dateString)
    }

    /// 添加日期
    public mutating func addDate(_ dateString: String) {
        selectedDates.insert(dateString)
    }

    /// 移除日期
    public mutating func removeDate(_ dateString: String) {
        selectedDates.remove(dateString)
    }

    /// 清除所有日期
    public mutating func clearAllDates() {
        selectedDates.removeAll()
    }

    /// 獲取已選擇的日期數量
    public var selectedCount: Int {
        return selectedDates.count
    }
}

/// 排休限制設定
public struct VacationLimits: Codable {
    public let orgId: String
    public let month: String
    public let vacationType: String
    public let monthlyLimit: Int?
    public let weeklyLimit: Int?
    public let isPublished: Bool
    public let publishedDate: Date?

    public init(
        orgId: String,
        month: String,
        vacationType: String,
        monthlyLimit: Int? = nil,
        weeklyLimit: Int? = nil,
        isPublished: Bool = false,
        publishedDate: Date? = nil
    ) {
        self.orgId = orgId
        self.month = month
        self.vacationType = vacationType
        self.monthlyLimit = monthlyLimit
        self.weeklyLimit = weeklyLimit
        self.isPublished = isPublished
        self.publishedDate = publishedDate
    }
}

// MARK: - 📋 Schedule Models

public enum ScheduleMode: String, CaseIterable, Codable {
    case auto = "auto"
    case manual = "manual"

    public var displayName: String {
        switch self {
        case .auto: return "自動排班"
        case .manual: return "手動排班"
        }
    }
}

public struct ScheduleData: Codable {
    public let mode: ScheduleMode
    public let selectedDates: Set<String>
    public let month: String

    public init(mode: ScheduleMode, selectedDates: Set<String>, month: String) {
        self.mode = mode
        self.selectedDates = selectedDates
        self.month = month
    }

    public var displayText: String {
        return "\(mode.displayName) - \(month) (\(selectedDates.count)天)"
    }
}

// MARK: - 👑 Boss Models

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

public struct ActionColor: Codable {
    public let primary: String

    public init(primary: String) {
        self.primary = primary
    }
}

public struct BossPublishStatus: Codable {
    public let vacationPublished: Bool
    public let schedulePublished: Bool
    public let month: String
    public let orgId: String

    public init(vacationPublished: Bool, schedulePublished: Bool, month: String, orgId: String) {
        self.vacationPublished = vacationPublished
        self.schedulePublished = schedulePublished
        self.month = month
        self.orgId = orgId
    }
}

// MARK: - 🎨 UI Models

public enum ShiftAction {
    case editVacation
    case clearVacation
}

// MARK: - 📱 Internal Models

public struct CalendarDay: Identifiable {
    public let id = UUID()
    public let date: Date
    public let isWithinDisplayedMonth: Bool

    public init(date: Date, isWithinDisplayedMonth: Bool) {
        self.date = date
        self.isWithinDisplayedMonth = isWithinDisplayedMonth
    }
}

public struct MonthSection: Identifiable {
    public let id = UUID()
    public let date: Date
    public let days: [CalendarDay]

    public init(date: Date, days: [CalendarDay]) {
        self.date = date
        self.days = days
    }
}

// MARK: - 🔗 Extensions

extension Notification.Name {
    public static let vacationLimitsDidUpdate = Notification.Name("vacationLimitsDidUpdate")
    public static let vacationRulePublished = Notification.Name("VacationRulePublished")
    public static let vacationRuleUnpublished = Notification.Name("VacationRuleUnpublished")
    public static let bossSettingsPublished = Notification.Name("BossSettingsPublished")
}
