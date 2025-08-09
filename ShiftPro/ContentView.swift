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
    @State private var showingError = false

    // 🔥 修復：錯誤處理
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 🔥 修復：根據初始化和認證狀態顯示不同內容
            if userManager.isInitializing {
                initializingView()
            } else if shouldShowLoginPrompt {
                loginPromptView()
            } else {
                mainContentView()
            }
        }
        .sheet(isPresented: $showingLoginView) {
            LoginView()
        }
        .onAppear {
            print("🚀 ContentView 啟動")
            // 🔥 移除手動初始化，讓 UserManager 自行處理
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            handleAuthenticationChange(isAuthenticated)
        }
        .onChange(of: userManager.userRole) { _, newRole in
            handleRoleChange(newRole)
        }
        .errorHandling {
            // 重試邏輯 - 如果需要的話
        }
        .onReceive(userManager.$lastError) { error in
            if error != nil {
                showingError = true
            }
        }
        .onReceive(authService.$lastError) { error in
            if error != nil {
                showingError = true
            }
        }
    }

    // MARK: - 🔄 初始化載入畫面

    private func initializingView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .pulse()

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
        .transition(.opacity)
    }

    // MARK: - 🔑 登入提示畫面

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
                PrimaryButton(
                    title: "登入 / 註冊",
                    icon: "person.badge.key",
                    isLoading: authService.isLoading
                ) {
                    showingLoginView = true
                }

                SecondaryButton(
                    title: "訪客體驗",
                    icon: "person.crop.circle.dashed",
                    color: .white.opacity(0.8)
                ) {
                    enterGuestMode()
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
        .transition(.move(edge: .bottom))
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

    // MARK: - 🏠 主要內容視圖

    private func mainContentView() -> some View {
        VStack(spacing: 0) {
            // 主要內容區域
            Group {
                switch selectedTab {
                case .calendar:
                    calendarView()
                case .reports:
                    reportsView()
                case .templates:
                    templatesView()
                case .more:
                    MoreView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

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
        .transition(.opacity)
    }

    // MARK: - 📅 Calendar View 路由

    @ViewBuilder
    private func calendarView() -> some View {
        if userManager.userRole == .boss {
            BossCalendarView(menuState: menuState)
        } else {
            EmployeeCalendarView(menuState: menuState)
        }
    }

    // MARK: - 📊 佔位符視圖

    private func reportsView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Reports")
                .font(.largeTitle)
                .foregroundColor(.white)

            Text("統計報表功能開發中...")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func templatesView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Templates")
                .font(.largeTitle)
                .foregroundColor(.white)

            Text("排班範本功能開發中...")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 🔧 狀態邏輯

    // 🔥 修復：更精確的登入提示判斷邏輯
    private var shouldShowLoginPrompt: Bool {
        // 🔥 修復：首先檢查是否還在初始化
        if userManager.isInitializing {
            print("🔄 ContentView: 用戶管理器還在初始化中")
            return false
        }

        // 🔥 修復：檢查認證狀態
        let isAuthenticated = authService.isAuthenticated
        let isGuest = userManager.isGuest
        let hasUserData = userManager.currentUser != nil

        print("🔍 ContentView 登入狀態檢查:")
        print("  - isAuthenticated: \(isAuthenticated)")
        print("  - isGuest: \(isGuest)")
        print("  - hasUserData: \(hasUserData)")
        print("  - isInitializing: \(userManager.isInitializing)")

        // 如果是訪客模式，不顯示登入提示
        if isGuest {
            print("👤 ContentView: 訪客模式，不顯示登入提示")
            return false
        }

        // 如果已認證且有用戶資料，不顯示登入提示
        if isAuthenticated && hasUserData {
            print("✅ ContentView: 已登入且有用戶資料，不顯示登入提示")
            return false
        }

        // 如果已認證但沒有用戶資料，表示正在載入，不顯示登入提示
        if isAuthenticated && !hasUserData {
            print("🔄 ContentView: 已認證但正在載入用戶資料，不顯示登入提示")
            return false
        }

        // 其他情況顯示登入提示
        print("🔑 ContentView: 顯示登入提示")
        return true
    }

    // MARK: - 🔄 處理認證狀態變化

    private func handleAuthenticationChange(_ isAuthenticated: Bool) {
        print("🔐 ContentView 認證狀態變化: \(isAuthenticated)")
        print("  - 當前用戶: \(userManager.currentUser?.name ?? "nil")")
        print("  - 是否訪客: \(userManager.isGuest)")

        withAnimation(.easeInOut(duration: 0.3)) {
            if isAuthenticated {
                selectedTab = .calendar
                menuState.isMenuPresented = false
                menuState.isVacationModeMenuPresented = false
            } else {
                // 🔥 修復：登出時重置狀態
                selectedTab = .calendar
                menuState.isMenuPresented = false
                menuState.isVacationModeMenuPresented = false

                // 🔥 新增：如果需要的話，可以強制重置 AuthManager
                // authService.forceSignOutForDevelopment()
            }
        }
    }

    // MARK: - 🔄 處理角色變化

    private func handleRoleChange(_ newRole: UserRole) {
        print("🔄 ContentView 角色變化: \(newRole)")
        print("  - 當前用戶: \(userManager.currentUser?.name ?? "nil")")
        print("  - 登入狀態: \(userManager.isLoggedIn)")
        print("  - 訪客模式: \(userManager.isGuest)")

        withAnimation(.easeInOut(duration: 0.3)) {
            selectedTab = .calendar
            menuState.isMenuPresented = false
            menuState.isVacationModeMenuPresented = false
        }
    }

    // MARK: - 👤 進入訪客模式

    private func enterGuestMode() {
        print("👤 ContentView 進入訪客模式")

        userManager.enterGuestMode()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        print("❌ 進入訪客模式失敗: \(error)")
                        ErrorHandler.shared.handle(error, context: "Guest Mode")
                    case .finished:
                        break
                    }
                },
                receiveValue: { _ in
                    print("✅ 成功進入訪客模式")
                }
            )
            .store(in: &cancellables)
    }
}

#Preview {
    ContentView()
}
