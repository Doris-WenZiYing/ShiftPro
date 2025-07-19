//
//  VacationModel.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/19.
//

import Foundation

// MARK: - 休假類型
public enum VacationType: String, CaseIterable, Codable {
    case weekly   = "週休"
    case monthly  = "月休"
    case flexible = "彈性"
    public var displayName: String { rawValue }
}

// MARK: - 員工端排休模式
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
        case .weekly:                  return "每週可排休指定天數"
        case .monthly:                 return "每月可排休指定天數，無週限制"
        case .monthlyWithWeeklyLimit:  return "每月可排休指定天數，且每週有天數限制"
        }
    }
    public var icon: String {
        switch self {
        case .weekly:                  return "calendar.day.timeline.leading"
        case .monthly:                 return "calendar"
        case .monthlyWithWeeklyLimit:  return "calendar.badge.clock"
        }
    }
}

// MARK: - 老闆發佈用設定
public struct VacationSetting: Codable {
    public let type: VacationType
    public let allowedDays: Int
    public let year: Int
    public let month: Int
    public let publishDate: Date

    public init(
        type: VacationType,
        allowedDays: Int,
        year: Int,
        month: Int,
        publishDate: Date = Date()
    ) {
        self.type = type
        self.allowedDays = allowedDays
        self.year = year
        self.month = month
        self.publishDate = publishDate
    }
}

// MARK: - 員工本地快取的排休資料
public struct VacationData: Codable {
    public var selectedDates: Set<String> = []
    public var isSubmitted: Bool = false
    public var currentMonth: String = ""   // "YYYY-MM"
    public init() {}

    /// 檢查日期是否已選擇
    func isDateSelected(_ dateString: String) -> Bool {
        return selectedDates.contains(dateString)
    }

    /// 添加日期
    mutating func addDate(_ dateString: String) {
        selectedDates.insert(dateString)
    }

    /// 移除日期
    mutating func removeDate(_ dateString: String) {
        selectedDates.remove(dateString)
    }

    /// 清除所有日期
    mutating func clearAllDates() {
        selectedDates.removeAll()
    }

    /// 獲取已選擇的日期數量
    var selectedCount: Int {
        return selectedDates.count
    }
}

public struct VacationLimits: Codable {
    public let orgId: String
    public let month: String                    // "YYYY-MM"
    public let vacationType: String            // "weekly"/"monthly"/"flexible"
    public let monthlyLimit: Int?               // 月上限
    public let weeklyLimit: Int?                // 週上限
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

// MARK: - Schedule Models
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
    public let month: String                    // "YYYY-MM"

    public init(mode: ScheduleMode, selectedDates: Set<String>, month: String) {
        self.mode = mode
        self.selectedDates = selectedDates
        self.month = month
    }

    public var displayText: String {
        return "\(mode.displayName) - \(month) (\(selectedDates.count)天)"
    }
}

// MARK: - Notification Extensions
extension NSNotification.Name {
    static let vacationLimitsDidUpdate = NSNotification.Name("vacationLimitsDidUpdate")
}
