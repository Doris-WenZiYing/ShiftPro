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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Main content area
                switch selectedTab {
                case .calendar:
                    EmployeeCalendarView(menuState: menuState)
                case .reports:
                    ReportsView()
                case .templates:
                    TemplatesView()
                case .more:
                    MoreView()
                }

                // Tab bar
                TabBarView(selectedTab: $selectedTab)
            }

            // 全局 Menu Overlay - 能夠覆蓋整個應用包括 TabBar
            if menuState.isMenuPresented {
                CustomMenuOverlay(
                    isPresented: $menuState.isMenuPresented,
                    currentVacationMode: $menuState.currentVacationMode,
                    isVacationModeMenuPresented: $menuState.isVacationModeMenuPresented
                )
                .zIndex(999) // 最高層級，確保覆蓋所有內容
                .ignoresSafeArea(.all)
            }
        }
        .sheet(isPresented: $menuState.isVacationModeMenuPresented) {
            VacationModeSelectionSheet(
                currentMode: $menuState.currentVacationMode,
                weeklyLimit: .constant(2), // 你可以根據需要調整
                monthlyLimit: .constant(8), // 你可以根據需要調整
                isPresented: $menuState.isVacationModeMenuPresented
            )
        }
    }
}

// Placeholder views for other tabs
struct ReportsView: View {
    var body: some View {
        VStack {
            Text("Reports")
                .font(.largeTitle)
                .foregroundColor(.white)
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
}

struct TemplatesView: View {
    var body: some View {
        VStack {
            Text("Templates")
                .font(.largeTitle)
                .foregroundColor(.white)
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
}

struct MoreView: View {
    var body: some View {
        VStack {
            Text("More")
                .font(.largeTitle)
                .foregroundColor(.white)
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
}

#Preview {
    ContentView()
}
