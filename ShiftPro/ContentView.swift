//
//  ContentView.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/8.
//

import SwiftUI
import Combine

struct ContentView: View {
    @State private var selectedTab: Tab = .calendar
    @StateObject private var menuState = MenuState()
    @StateObject private var userManager = UserManager.shared
    @StateObject private var authService = AuthManager.shared
    @State private var showingLoginView = false
    @State private var isInitializing = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isInitializing {
                // 初始化載入畫面
                initializingView()
            } else if !authService.isAuthenticated {
                // 未登入狀態 - 顯示登入提示
                loginPromptView()
            } else {
                // 已登入狀態 - 顯示主要內容
                mainContentView()
            }
        }
        .sheet(isPresented: $showingLoginView) {
            LoginView()
        }
        .onAppear {
            initializeApp()
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            handleAuthenticationChange(isAuthenticated)
        }
        .onChange(of: userManager.userRole) { _, newRole in
            handleRoleChange(newRole)
        }
    }

    // MARK: - 初始化載入畫面
    private func initializingView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("ShiftPro")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)

            Text("正在初始化...")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
        }
    }

    // MARK: - 登入提示畫面
    private func loginPromptView() -> some View {
        VStack(spacing: 30) {
            Spacer()

            // Logo 和標題
            VStack(spacing: 20) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 100))
                    .foregroundColor(.blue)

                VStack(spacing: 8) {
                    Text("ShiftPro")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)

                    Text("智能排班管理系統")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            // 功能介紹
            VStack(spacing: 16) {
                featureRow("👑", "老闆", "建立組織，設定排休規則")
                featureRow("👤", "員工", "申請排休，查看班表")
                featureRow("📊", "報表", "統計分析，薪資計算")
            }

            Spacer()

            // 登入按鈕
            VStack(spacing: 16) {
                Button(action: { showingLoginView = true }) {
                    HStack {
                        Image(systemName: "person.badge.key")
                            .font(.system(size: 18))

                        Text("登入 / 註冊")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(12)
                }

                Button(action: enterGuestMode) {
                    HStack {
                        Image(systemName: "person.crop.circle.dashed")
                            .font(.system(size: 16))

                        Text("訪客體驗")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
    }

    private func featureRow(_ icon: String, _ title: String, _ description: String) -> some View {
        HStack(spacing: 16) {
            Text(icon)
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - 主要內容視圖
    private func mainContentView() -> some View {
        VStack(spacing: 0) {
            // 主要內容區域
            switch selectedTab {
            case .calendar:
                if userManager.userRole == .boss {
                    BossCalendarView(menuState: menuState)
                } else {
                    EmployeeCalendarView(menuState: menuState)
                }
            case .reports:
                reportsView()
            case .templates:
                templatesView()
            case .more:
                MoreView()
            }

            // Tab bar
            TabBarView(selectedTab: $selectedTab)
        }
        .overlay {
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
    }

    // MARK: - 佔位符視圖
    private func reportsView() -> some View {
        VStack {
            Text("Reports")
                .font(.largeTitle)
                .foregroundColor(.white)

            Text("統計報表功能開發中...")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private func templatesView() -> some View {
        VStack {
            Text("Templates")
                .font(.largeTitle)
                .foregroundColor(.white)

            Text("排班範本功能開發中...")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: - 初始化應用
    private func initializeApp() {
        print("🚀 ContentView 初始化應用")

        // 延遲一下讓 Firebase 初始化完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
                isInitializing = false
            }
        }
    }

    // MARK: - 處理認證狀態變化
    private func handleAuthenticationChange(_ isAuthenticated: Bool) {
        print("🔐 ContentView 認證狀態變化: \(isAuthenticated)")

        if isAuthenticated {
            // 已登入 - 確保顯示正確的標籤頁
            selectedTab = .calendar
            menuState.isMenuPresented = false
            menuState.isVacationModeMenuPresented = false
        } else {
            // 已登出 - 重置狀態
            selectedTab = .calendar
            menuState.isMenuPresented = false
            menuState.isVacationModeMenuPresented = false
        }
    }

    // MARK: - 處理角色變化
    private func handleRoleChange(_ newRole: UserRole) {
        print("🔄 ContentView 角色變化: \(newRole)")

        // 角色變化時回到首頁
        selectedTab = .calendar
        menuState.isMenuPresented = false
        menuState.isVacationModeMenuPresented = false
    }

    // MARK: - 進入訪客模式
    private func enterGuestMode() {
        print("👤 ContentView 進入訪客模式")

        userManager.enterGuestMode()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ 進入訪客模式失敗: \(error)")
                    }
                },
                receiveValue: { _ in
                    print("✅ 成功進入訪客模式")
                }
            )
            .store(in: &cancellables)
    }

    @State private var cancellables = Set<AnyCancellable>()
}

#Preview {
    ContentView()
}
