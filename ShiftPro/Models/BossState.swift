//
//  BossState.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/25.
//

import Foundation

struct BossPublishStatus: Codable {
    let vacationPublished: Bool
    let schedulePublished: Bool
    let month: String
    let orgId: String
}
