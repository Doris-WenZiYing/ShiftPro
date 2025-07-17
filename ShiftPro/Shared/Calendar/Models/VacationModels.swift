//
//  VacationModels.swift
//  ShiftPro
//
//  統一的休假相關模型
//

import Foundation

// MARK: - 休假類型
enum VacationType: String, CaseIterable, Codable {
    case weekly = "週休"
    case monthly = "月休"
    case flexible = "彈性"

    var displayName: String {
        return self.rawValue
    }
}

// MARK: - 休假模式（員工端使用）
enum VacationMode: String, CaseIterable, Codable {
    case weekly = "週休"
    case monthly = "月休"
    case monthlyWithWeeklyLimit = "月休(含週限制)"

    var displayName: String {
        return self.rawValue
    }

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

// MARK: - 休假限制（老闆端設定）
struct VacationLimits: Codable {
    let monthlyLimit: Int?
    let weeklyLimit: Int?
    let year: Int
    let month: Int
    let isPublished: Bool
    let publishedDate: Date?
    let vacationType: VacationType

    init(monthlyLimit: Int? = nil,
         weeklyLimit: Int? = nil,
         year: Int,
         month: Int,
         isPublished: Bool = false,
         publishedDate: Date? = nil,
         vacationType: VacationType = .monthly) {
        self.monthlyLimit = monthlyLimit
        self.weeklyLimit = weeklyLimit
        self.year = year
        self.month = month
        self.isPublished = isPublished
        self.publishedDate = publishedDate
        self.vacationType = vacationType
    }

    var displayText: String {
        let monthStr = String(format: "%04d年%02d月", year, month)
        if let monthly = monthlyLimit {
            return "\(monthStr) - \(vacationType.displayName): \(monthly)天"
        } else if let weekly = weeklyLimit {
            return "\(monthStr) - \(vacationType.displayName): 每週\(weekly)天"
        }
        return monthStr
    }
}

// MARK: - 休假設定（老闆發佈用）
struct VacationSetting: Codable {
    let type: VacationType
    let allowedDays: Int
    let year: Int
    let month: Int
    let publishDate: Date

    init(type: VacationType, allowedDays: Int, year: Int, month: Int, publishDate: Date = Date()) {
        self.type = type
        self.allowedDays = allowedDays
        self.year = year
        self.month = month
        self.publishDate = publishDate
    }

    var displayText: String {
        return String(format: "%04d年%02d月 - %@: %d天", year, month, type.displayName, allowedDays)
    }

    // 轉換為 VacationLimits
    func toVacationLimits() -> VacationLimits {
        return VacationLimits(
            monthlyLimit: type == .monthly ? allowedDays : nil,
            weeklyLimit: type == .weekly ? allowedDays : 2, // 默認週休2天
            year: year,
            month: month,
            isPublished: true,
            publishedDate: publishDate,
            vacationType: type
        )
    }
}

// MARK: - 休假資料（員工端使用）
struct VacationData: Codable {
    var selectedDates: Set<String> = []
    var isSubmitted: Bool = false
    var currentMonth: String = ""

    mutating func addDate(_ dateString: String) {
        selectedDates.insert(dateString)
    }

    mutating func removeDate(_ dateString: String) {
        selectedDates.remove(dateString)
    }

    func isDateSelected(_ dateString: String) -> Bool {
        return selectedDates.contains(dateString)
    }
}

// MARK: - 通知擴展
extension Notification.Name {
    static let vacationLimitsDidUpdate = Notification.Name("vacationLimitsDidUpdate")
    static let vacationSettingPublished = Notification.Name("vacationSettingPublished")
}
