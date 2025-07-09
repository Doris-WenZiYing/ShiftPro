//
//  CalendarDay.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/8.
//

import Foundation

struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date
    let isWithinDisplayedMonth: Bool
}
