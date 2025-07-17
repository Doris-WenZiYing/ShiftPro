//
//  BossPublishStatus.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/11.
//

import Foundation

struct BossPublishStatus: Codable {
    let vacationPublished: Bool
    let schedulePublished: Bool
    let month: String
    let createdAt: Date

    init(vacationPublished: Bool, schedulePublished: Bool, month: String) {
        self.vacationPublished = vacationPublished
        self.schedulePublished = schedulePublished
        self.month = month
        self.createdAt = Date()
    }
}
