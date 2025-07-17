//
//  BossScheduleModel.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/11.
//

import Foundation

enum ScheduleMode: Codable {
    case auto
    case manual

    var displayName: String {
        switch self {
        case .auto:
            return "自動排班"
        case .manual:
            return "自定義排班"
        }
    }
}

struct ScheduleData: Codable {
    let mode: ScheduleMode
    let selectedDates: Set<String>
    let month: String
    let createdAt: Date

    init(mode: ScheduleMode, selectedDates: Set<String>, month: String) {
        self.mode = mode
        self.selectedDates = selectedDates
        self.month = month
        self.createdAt = Date()
    }

    var displayText: String {
        return "\(mode.displayName) - \(selectedDates.count) 個工作日"
    }
}
