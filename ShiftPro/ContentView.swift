//
//  ContentView.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/8.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .calendar
    @StateObject private var menuState = MenuState()
    @AppStorage("isBoss") private var isBoss: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Main content
                switch selectedTab {
                case .calendar:
                    if isBoss {
                        BossCalendarView(menuState: menuState)
                    } else {
                        EmployeeCalendarView(menuState: menuState)
                    }
                case .reports:
//                    ReportsView()
                    Text("")
                case .templates:
                    Text("")
//                    TemplatesView()
                case .more:
                    MoreView()
                }

                // Tab bar
                TabBarView(selectedTab: $selectedTab)
            }

            // Menu overlay
            if menuState.isMenuPresented {
                CustomMenuOverlay(
                    isPresented: $menuState.isMenuPresented,
                    currentVacationMode: $menuState.currentVacationMode,
                    isVacationModeMenuPresented: $menuState.isVacationModeMenuPresented
                )
                .zIndex(999)
                .ignoresSafeArea(.all)
                .transition(.move(edge: .trailing))
            }
        }
        .sheet(isPresented: $menuState.isVacationModeMenuPresented) {
            VacationModeSelectionSheet(
                currentMode: $menuState.currentVacationMode,
                weeklyLimit: .constant(2),
                monthlyLimit: .constant(8),
                isPresented: $menuState.isVacationModeMenuPresented
            )
        }
        .onChange(of: isBoss) { _, newValue in
            selectedTab = .calendar
            menuState.isMenuPresented = false
            menuState.isVacationModeMenuPresented = false
        }
    }
}

#Preview {
    ContentView()
}
