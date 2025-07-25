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
    @StateObject private var userManager = UserManager.shared
    @AppStorage("isBoss") private var isBoss: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Main content
                switch selectedTab {
                case .calendar:
                    // 🔥 根據用戶真實身分決定顯示的 View
                    if userManager.userRole == .boss {
                        BossCalendarView(menuState: menuState)
                    } else {
                        EmployeeCalendarView(menuState: menuState)
                    }
                case .reports:
                    Text("Reports")
                        .foregroundColor(.white)
                case .templates:
                    Text("Templates")
                        .foregroundColor(.white)
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
        // 🔥 監聽用戶身分變化
        .onChange(of: userManager.userRole) { _, newRole in
            print("🔄 ContentView 收到身分變化: \(newRole)")
            selectedTab = .calendar
            menuState.isMenuPresented = false
            menuState.isVacationModeMenuPresented = false

            // 同步 AppStorage
            isBoss = (newRole == .boss)
        }
        .onChange(of: isBoss) { _, newValue in
            // 當 AppStorage 變化時，也要同步 UserManager
            if newValue != (userManager.userRole == .boss) {
                print("🔄 AppStorage 變化，同步身分: \(newValue ? "Boss" : "Employee")")
                if !userManager.isLoggedIn {
                    // 如果還沒登入，先設定預設身分
                    if newValue {
                        userManager.setCurrentBoss(
                            orgId: "demo_store_01",
                            bossName: "測試老闆",
                            orgName: "Demo Store"
                        )
                    } else {
                        userManager.setCurrentEmployee(
                            employeeId: "emp_001",
                            employeeName: "測試員工",
                            orgId: "demo_store_01",
                            orgName: "Demo Store"
                        )
                    }
                }
                selectedTab = .calendar
                menuState.isMenuPresented = false
                menuState.isVacationModeMenuPresented = false
            }
        }
        .onAppear {
            // 初始化時同步身分狀態
            if !userManager.isLoggedIn {
                print("👋 首次啟動，設定預設身分")
                if isBoss {
                    userManager.setCurrentBoss(
                        orgId: "demo_store_01",
                        bossName: "測試老闆",
                        orgName: "Demo Store"
                    )
                } else {
                    userManager.setCurrentEmployee(
                        employeeId: "emp_001",
                        employeeName: "測試員工",
                        orgId: "demo_store_01",
                        orgName: "Demo Store"
                    )
                }
            }

            // 確保 AppStorage 和 UserManager 同步
            isBoss = (userManager.userRole == .boss)
            print("📱 ContentView 載入完成 - 身分: \(userManager.roleDisplayText)")
        }
    }
}

#Preview {
    ContentView()
}
