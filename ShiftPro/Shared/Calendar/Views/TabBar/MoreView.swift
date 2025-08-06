//
//  MoreView.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/11.
//

import SwiftUI
import Combine

struct MoreView: View {
    @StateObject private var userManager = UserManager.shared
    @StateObject private var authService = AuthManager.shared
    @StateObject private var orgManager = OrganizationManager.shared
    @StateObject private var firebaseInitializer = FirebaseInitializer.shared

    @State private var showingLoginView = false
    @State private var showingLogoutAlert = false
    @State private var showingInviteCodeSheet = false
    @State private var organizationInviteCode = ""
    @State private var isLoadingInviteCode = false
    @State private var showingRoleChangeAlert = false
    @State private var showingFirebaseInitAlert = false

    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerView()

                    ScrollView {
                        contentView()
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingLoginView) {
            LoginView()
        }
        .sheet(isPresented: $showingInviteCodeSheet) {
            InviteCodeSheet(inviteCode: organizationInviteCode)
        }
        .alert("登出確認", isPresented: $showingLogoutAlert) {
            Button("取消", role: .cancel) { }
            Button("確認登出", role: .destructive) {
                performLogout()
            }
        } message: {
            Text("確定要登出嗎？")
        }
        .alert("切換身分", isPresented: $showingRoleChangeAlert) {
            Button("取消", role: .cancel) { }
            Button("確認切換") {
                performRoleSwitch()
            }
        } message: {
            Text("這是測試功能，僅在訪客模式下可用")
        }
        .alert("初始化 Firebase", isPresented: $showingFirebaseInitAlert) {
            Button("取消", role: .cancel) { }
            Button("確認初始化") {
                firebaseInitializer.initializeAllTestData()
            }
        } message: {
            Text("這將在 Firebase 中建立測試數據")
        }
    }

    // MARK: - Header View
    private func headerView() -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("更多設定")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text("個人資訊與應用設定")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                // 登入狀態指示器
                authStatusBadge()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 45)
        .padding(.bottom, 16)
    }

    private func authStatusBadge() -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(getAuthStatusColor())
                .frame(width: 8, height: 8)

            Text(userManager.authStatus)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(getAuthStatusColor())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(getAuthStatusColor().opacity(0.2))
        .cornerRadius(20)
    }

    private func getAuthStatusColor() -> Color {
        if userManager.isGuest {
            return .orange
        } else if userManager.isLoggedIn {
            return .green
        } else {
            return .gray
        }
    }

    // MARK: - Content View
    private func contentView() -> some View {
        VStack(spacing: 16) {
            // 登入/用戶資訊區域
            if userManager.isLoggedIn || userManager.isGuest {
                userIdentityCard()
                organizationInfoCard()
            } else {
                loginPromptCard()
            }

            // 功能設定區域
            if userManager.isLoggedIn || userManager.isGuest {
                settingsSection()
            }

            aboutSection()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    // MARK: - 登入提示卡片
    private func loginPromptCard() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            VStack(spacing: 8) {
                Text("歡迎使用 ShiftPro")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text("登入以享受完整功能")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
            }

            Button(action: { showingLoginView = true }) {
                HStack {
                    Image(systemName: "person.badge.key")
                        .font(.system(size: 16))

                    Text("立即登入")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
        .padding(24)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    // MARK: - User Identity Card
    private func userIdentityCard() -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: userManager.roleIcon)
                    .font(.system(size: 24))
                    .foregroundColor(userManager.userRole == .boss ? .yellow : .blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("當前身分")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))

                    Text(userManager.displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        Text(userManager.roleDisplayText)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(userManager.userRole == .boss ? .yellow : .blue)

                        if userManager.isGuest {
                            Text("(測試模式)")
                                .font(.system(size: 14))
                                .foregroundColor(.orange)
                        }
                    }
                }

                Spacer()

                statusBadge()
            }

            identityDescription()

            if userManager.isLoggedIn {
                identityDetails()
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private func statusBadge() -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(userManager.userRole == .boss ? Color.yellow : Color.blue)
                .frame(width: 8, height: 8)

            Text(userManager.userRole == .boss ? "BOSS" : "STAFF")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(userManager.userRole == .boss ? .yellow : .blue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background((userManager.userRole == .boss ? Color.yellow : Color.blue).opacity(0.2))
        .cornerRadius(20)
    }

    private func identityDescription() -> some View {
        Text(userManager.userRole == .boss ?
             "您可以建立組織、設定員工排休限制和管理排班" :
                "您可以申請排休、查看排班並管理個人時程")
        .font(.system(size: 14))
        .foregroundColor(.white.opacity(0.7))
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func identityDetails() -> some View {
        VStack(spacing: 8) {
            if let user = userManager.currentUser {
                identityDetailRow("用戶 ID", user.id)
                identityDetailRow("電子郵件", authService.currentUser?.email ?? "未設定")
            }
            if userManager.userRole == .employee {
                identityDetailRow("員工編號", userManager.currentEmployeeId)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Organization Info Card
    private func organizationInfoCard() -> some View {
        VStack(spacing: 16) {
            organizationHeader()
            organizationContent()
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private func organizationHeader() -> some View {
        HStack {
            Image(systemName: "building.2.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)

            Text("組織資訊")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            // 邀請碼按鈕（僅老闆可見）
            if userManager.userRole == .boss && userManager.isLoggedIn {
                Button("邀請碼") {
                    loadInviteCode()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.2))
                .cornerRadius(16)
            }
        }
    }

    private func organizationContent() -> some View {
        Group {
            if userManager.currentOrganization != nil {
                VStack(spacing: 12) {
                    organizationDetailRow("組織名稱", userManager.organizationName)
                    organizationDetailRow("組織 ID", userManager.currentOrgId)

                    if let org = userManager.currentOrganization {
                        organizationDetailRow("建立時間", DateFormatter.localizedString(from: org.createdAt, dateStyle: .medium, timeStyle: .none))
                    }

                    if userManager.isLoggedIn {
                        organizationDetailRow("身分", userManager.roleDisplayText)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Text("尚未加入任何組織")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))

                    if !userManager.isLoggedIn {
                        Button("立即註冊") {
                            showingLoginView = true
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(16)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Settings Section
    private func settingsSection() -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)

                Text("功能設定")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()
            }

            VStack(spacing: 16) {
                // 測試功能（僅訪客模式）
                if userManager.isGuest {
                    testFeaturesCard()
                }

                // 老闆專用功能
                if userManager.userRole == .boss {
                    bossSettingsCard()
                }

                // 通用設定
                generalSettingsCard()

                // 登出按鈕
                if userManager.isLoggedIn {
                    logoutButton()
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    // MARK: - 測試功能卡片
    private func testFeaturesCard() -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "testtube.2")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)

                Text("測試功能")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()
            }

            VStack(spacing: 8) {
                Button(action: { showingRoleChangeAlert = true }) {
                    settingRowContent(
                        icon: "arrow.triangle.2.circlepath",
                        title: "切換身分",
                        subtitle: "在老闆和員工身分間切換",
                        color: .orange
                    )
                }
                .buttonStyle(PlainButtonStyle())

                if userManager.userRole == .boss {
                    Button(action: { showingFirebaseInitAlert = true }) {
                        settingRowContent(
                            icon: "server.rack",
                            title: "初始化測試數據",
                            subtitle: "建立 Firebase 測試數據",
                            color: .purple
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - 老闆設定卡片
    private func bossSettingsCard() -> some View {
        VStack(spacing: 8) {
            NavigationLink(destination: BossSettingsView()) {
                settingRowContent(
                    icon: "gearshape.2.fill",
                    title: "排休限制設定",
                    subtitle: "設定員工排休規則",
                    color: .blue
                )
            }
            .buttonStyle(PlainButtonStyle())

            settingRow(
                icon: "person.3.fill",
                title: "員工管理",
                subtitle: "管理團隊成員",
                color: .green
            )
        }
    }

    // MARK: - 通用設定卡片
    private func generalSettingsCard() -> some View {
        VStack(spacing: 8) {
            settingRow(
                icon: "bell.fill",
                title: "通知設定",
                subtitle: "管理推送通知偏好",
                color: .red
            )

            settingRow(
                icon: "moon.fill",
                title: "深色模式",
                subtitle: "已啟用",
                color: .purple
            )

            settingRow(
                icon: "globe",
                title: "語言設定",
                subtitle: "繁體中文",
                color: .green
            )
        }
    }

    // MARK: - 登出按鈕
    private func logoutButton() -> some View {
        Button(action: { showingLogoutAlert = true }) {
            settingRowContent(
                icon: "rectangle.portrait.and.arrow.right",
                title: "登出",
                subtitle: userManager.isGuest ? "切換到未登入狀態" : "登出您的帳號",
                color: .red
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - About Section
    private func aboutSection() -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)

                Text("關於應用程式")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()
            }

            VStack(spacing: 12) {
                aboutRow(
                    icon: "doc.text.fill",
                    title: "版本資訊",
                    subtitle: "ShiftPro v1.0.0 (Firebase 版)",
                    color: .indigo
                )

                aboutRow(
                    icon: "questionmark.circle.fill",
                    title: "幫助與支援",
                    subtitle: "常見問題與使用指南",
                    color: .orange
                )
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    // MARK: - Helper Views
    private func identityDetailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
        }
    }

    private func organizationDetailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.green.opacity(0.9))
        }
    }

    private func settingRowContent(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.vertical, 8)
    }

    private func settingRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.vertical, 8)
    }

    private func aboutRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.vertical, 8)
    }

    // MARK: - Actions
    private func performRoleSwitch() {
        // Option 1: If switchRole is a simple method
        userManager.switchRole()

        // Option 2: If switchRole returns a publisher (uncomment if needed)
        /*
        userManager.switchRole()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ 切換身分失敗: \(error)")
                    }
                },
                receiveValue: { _ in
                    print("✅ 切換身分成功")
                }
            )
            .store(in: &cancellables)
        */

        // Option 3: If it's an async method (uncomment if needed)
        /*
        Task {
            do {
                await userManager.switchRole()
                print("✅ 切換身分成功")
            } catch {
                print("❌ 切換身分失敗: \(error)")
            }
        }
        */
    }

    private func loadInviteCode() {
        guard userManager.isLoggedIn, userManager.userRole == .boss else { return }

        isLoadingInviteCode = true

        orgManager.getOrganizationInviteCode(orgId: userManager.currentOrgId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    self.isLoadingInviteCode = false
                    if case .failure(let error) = completion {
                        print("❌ 載入邀請碼失敗: \(error)")
                    }
                },
                receiveValue: { inviteCode in
                    self.organizationInviteCode = inviteCode
                    self.showingInviteCodeSheet = true
                }
            )
            .store(in: &cancellables)
    }

    private func performLogout() {
        userManager.logout()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ 登出失敗: \(error)")
                    }
                },
                receiveValue: { _ in
                    print("✅ 登出成功")
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - Invite Code Sheet
struct InviteCodeSheet: View {
    let inviteCode: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "key.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)

                VStack(spacing: 12) {
                    Text("組織邀請碼")
                        .font(.system(size: 24, weight: .bold))

                    Text("分享此邀請碼給員工，讓他們加入您的組織")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Text(inviteCode)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)

                Button("複製邀請碼") {
                    UIPasteboard.general.string = inviteCode
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding()
            .navigationTitle("邀請碼")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    MoreView()
}
