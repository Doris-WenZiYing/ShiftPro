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

    // MARK: - 🔥 統一的初始化狀態管理
    @State private var initializationState: InitializationState = .starting
    @State private var initializationProgress: String = "正在啟動..."
    @State private var cancellables = Set<AnyCancellable>()

    enum InitializationState: Equatable {
        case starting
        case checkingAuth
        case loadingUserData
        case ready
        case error(String)

        static func == (lhs: InitializationState, rhs: InitializationState) -> Bool {
            switch (lhs, rhs) {
            case (.starting, .starting),
                 (.checkingAuth, .checkingAuth),
                 (.loadingUserData, .loadingUserData),
                 (.ready, .ready):
                return true
            case (.error(let lhsMessage), .error(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 🔥 根據初始化狀態顯示不同內容
            switch initializationState {
            case .starting, .checkingAuth, .loadingUserData:
                initializingView()

            case .ready:
                if shouldShowLogin {
                    loginPromptView()
                } else {
                    mainContentView()
                }

            case .error(let message):
                errorView(message: message)
            }
        }
        .fullScreenCover(isPresented: $showingLoginView) {
            LoginView()
        }
        .onAppear {
            startInitialization()
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            handleAuthenticationChange(isAuthenticated)
        }
        .onChange(of: userManager.userRole) { _, newRole in
            handleRoleChange(newRole)
        }
        .animation(.easeInOut(duration: 0.5), value: initializationState)
    }

    // MARK: - 🔥 改進的初始化載入畫面
    private func initializingView() -> some View {
        VStack(spacing: 30) {
            // Logo 動畫
            VStack(spacing: 20) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .pulse() // 脈衝動畫

                Text("ShiftPro")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: initializationProgress)
            }

            // 進度指示
            VStack(spacing: 16) {
                Text(initializationProgress)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)

                // 動態進度條
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(1.2)

                // 載入步驟指示
                HStack(spacing: 8) {
                    progressDot(isActive: true) // 啟動
                    progressDot(isActive: initializationState != .starting)
                    progressDot(isActive: initializationState == .ready)
                }
            }

            // 提示文字
            VStack(spacing: 8) {
                Text("智能排班管理系統")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))

                Text("初始化中，請稍候...")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .transition(.opacity)
    }

    private func progressDot(isActive: Bool) -> some View {
        Circle()
            .fill(isActive ? Color.blue : Color.white.opacity(0.3))
            .frame(width: 8, height: 8)
            .scaleEffect(isActive ? 1.2 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: isActive)
    }

    // MARK: - 🔥 錯誤狀態顯示
    private func errorView(message: String) -> some View {
        VStack(spacing: 30) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)

            VStack(spacing: 16) {
                Text("初始化失敗")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                PrimaryButton(
                    title: "重新嘗試",
                    icon: "arrow.clockwise"
                ) {
                    startInitialization()
                }
                .padding(.horizontal, 32)
            }
        }
        .transition(.opacity)
    }

    // MARK: - 🔥 統一的初始化流程
    private func startInitialization() {
        print("🚀 ContentView 開始初始化流程")
        initializationState = .starting
        initializationProgress = "正在啟動 ShiftPro..."

        // 步驟 1: 基本延遲確保載入畫面顯示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.checkAuthentication()
        }
    }

    private func checkAuthentication() {
        initializationState = .checkingAuth
        initializationProgress = "檢查登入狀態..."

        // 步驟 2: 檢查認證狀態
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.authService.isAuthenticated {
                self.loadUserData()
            } else {
                self.initializationProgress = "準備就緒"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.completeInitialization()
                }
            }
        }
    }

    private func loadUserData() {
        initializationState = .loadingUserData
        initializationProgress = "載入用戶資料..."

        // 步驟 3: 載入用戶數據
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.userManager.currentUser != nil {
                self.initializationProgress = "載入完成"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.completeInitialization()
                }
            } else {
                // 如果載入失敗，提供重試選項
                self.initializationState = .error("無法載入用戶資料")
            }
        }
    }

    private func completeInitialization() {
        print("✅ ContentView 初始化完成")
        initializationState = .ready
    }

    // MARK: - 登入提示畫面（保持原有邏輯）
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

    // MARK: - 主要內容視圖（保持原有邏輯）
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
//            if menuState.isMenuPresented {
//                CustomMenuOverlay(
//                    isPresented: $menuState.isMenuPresented,
//                    currentVacationMode: $menuState.currentVacationMode,
//                    isVacationModeMenuPresented: $menuState.isVacationModeMenuPresented
//                )
//                .zIndex(999)
//                .ignoresSafeArea(.all)
//                .transition(.move(edge: .trailing))
//            }
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

    // MARK: - Calendar View 路由
    @ViewBuilder
    private func calendarView() -> some View {
        if userManager.userRole == .boss {
            BossCalendarView(menuState: menuState)
        } else {
            EmployeeCalendarView(menuState: menuState)
        }
    }

    // MARK: - 佔位符視圖（保持原有）
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

    // MARK: - 🔥 簡化的狀態邏輯
    private var shouldShowLogin: Bool {
        return !userManager.isGuest && !authService.isAuthenticated
    }

    // MARK: - 事件處理（簡化版）
    private func handleAuthenticationChange(_ isAuthenticated: Bool) {
        print("🔐 ContentView 認證狀態變化: \(isAuthenticated)")

        // 🔥 如果在初始化完成後認證狀態變化，直接處理
        if initializationState == .ready {
            withAnimation(.easeInOut(duration: 0.3)) {
                if isAuthenticated {
                    selectedTab = .calendar
                    menuState.isMenuPresented = false
                } else {
                    selectedTab = .calendar
                    menuState.isMenuPresented = false
                }
            }
        }
    }

    private func handleRoleChange(_ newRole: UserRole) {
        print("🔄 ContentView 角色變化: \(newRole)")

        if initializationState == .ready {
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedTab = .calendar
                menuState.isMenuPresented = false
            }
        }
    }
}

#Preview {
    ContentView()
}
