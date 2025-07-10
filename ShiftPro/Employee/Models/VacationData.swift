//
//  VacationData.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/9.
//

import Foundation

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
