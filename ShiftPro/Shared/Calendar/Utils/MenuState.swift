//
//  MenuState.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/11.
//

import Foundation

class MenuState: ObservableObject {
    @Published var isMenuPresented: Bool = false
    @Published var currentVacationMode: VacationMode = .monthly
    @Published var isVacationModeMenuPresented: Bool = false
}
