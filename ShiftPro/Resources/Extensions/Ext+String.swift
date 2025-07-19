//
//  Ext+String.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/17.
//

import Foundation

extension String {
    var swiftEnum: VacationMode {
        VacationMode(rawValue: self) ?? .monthly
    }
}
