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
                // Main content area
                switch selectedTab {
                case .calendar:
                    if isBoss {
                        BossCalendarView(menuState: menuState)
                    } else {
                        EmployeeCalendarView(menuState: menuState)
                    }
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

            // 全局 Menu Overlay - 老闆和員工都可以使用
            if menuState.isMenuPresented {
                CustomMenuOverlay(
                    isPresented: $menuState.isMenuPresented,
                    currentVacationMode: $menuState.currentVacationMode,
                    isVacationModeMenuPresented: $menuState.isVacationModeMenuPresented
                )
                .zIndex(999) // 最高層級，確保覆蓋所有內容
                .ignoresSafeArea(.all)
                .transition(.move(edge: .trailing))
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
        .onChange(of: isBoss) { _, newValue in
            // 當切換身分時，重置選中的 tab 到 calendar
            selectedTab = .calendar
            // 關閉任何開啟的 menu
            menuState.isMenuPresented = false
            menuState.isVacationModeMenuPresented = false
        }
    }
}

// Placeholder views for other tabs
struct ReportsView: View {
    @AppStorage("isBoss") private var isBoss: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            // Role indicator
            HStack {
                Image(systemName: isBoss ? "crown.fill" : "person.fill")
                    .font(.system(size: 16))
                    .foregroundColor(isBoss ? .yellow : .blue)

                Text(isBoss ? "管理者報表" : "個人報表")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 24)

            Text("Reports")
                .font(.largeTitle)
                .foregroundColor(.white)

            if isBoss {
                Text("團隊績效分析")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
            } else {
                Text("個人工作統計")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
        .padding(.top, 45)
    }
}

struct TemplatesView: View {
    @AppStorage("isBoss") private var isBoss: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            // Role indicator
            HStack {
                Image(systemName: isBoss ? "crown.fill" : "person.fill")
                    .font(.system(size: 16))
                    .foregroundColor(isBoss ? .yellow : .blue)

                Text(isBoss ? "管理模板" : "個人模板")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 24)

            Text("Templates")
                .font(.largeTitle)
                .foregroundColor(.white)

            if isBoss {
                Text("排班模板管理")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
            } else {
                Text("我的排班模板")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
        .padding(.top, 45)
    }
}

#Preview {
    ContentView()
}
