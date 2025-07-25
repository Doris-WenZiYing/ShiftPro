//
//  MoreView.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/11.
//

import SwiftUI

struct MoreView: View {
    @AppStorage("isBoss") private var isBoss: Bool = false
    @StateObject private var userManager = UserManager.shared
    @StateObject private var firebaseInitializer = FirebaseInitializer.shared
    @State private var showingRoleChangeAlert = false
    @State private var showingOnboardingSheet = false
    @State private var showingFirebaseInitAlert = false
    
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
        .moreViewAlerts(
            showingFirebaseInitAlert: $showingFirebaseInitAlert,
            showingRoleChangeAlert: $showingRoleChangeAlert,
            firebaseInitializer: firebaseInitializer,
            userManager: userManager,
            isBoss: $isBoss
        )
        .sheet(isPresented: $showingOnboardingSheet) {
            OnboardingSheet()
        }
        .onAppear {
            isBoss = (userManager.userRole == .boss)
        }
        .onChange(of: userManager.userRole) { _, newRole in
            isBoss = (newRole == .boss)
        }
    }
    
    // MARK: - Content View
    private func contentView() -> some View {
        VStack(spacing: 16) {
            userIdentityCard()
            organizationInfoCard()
            roleSwitchCard()
            settingsSection()
            aboutSection()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
    
    // MARK: - Header View
    private func headerView() -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("更多設定")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("個人化設定與偏好")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 45)
        .padding(.bottom, 16)
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
                    
                    Text(userManager.roleDisplayText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(userManager.userRole == .boss ? .yellow : .blue)
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
             "您可以設定員工的休假限制和管理相關規則" :
                "您可以申請休假並查看個人排班資訊")
        .font(.system(size: 14))
        .foregroundColor(.white.opacity(0.7))
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func identityDetails() -> some View {
        VStack(spacing: 8) {
            identityDetailRow("ID", userManager.currentUser?.id ?? "未設定")
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
            
            if !userManager.isLoggedIn {
                Button("加入組織") {
                    showingOnboardingSheet = true
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
            if userManager.isLoggedIn {
                VStack(spacing: 12) {
                    organizationDetailRow("組織名稱", userManager.organizationName)
                    organizationDetailRow("組織ID", userManager.currentOrgId)
                    if let org = userManager.currentOrganization {
                        organizationDetailRow("建立時間", DateFormatter.localizedString(from: org.createdAt, dateStyle: .medium, timeStyle: .none))
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Text("尚未加入任何組織")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("請聯繫管理者獲取邀請碼")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - Role Switch Card
    private func roleSwitchCard() -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                
                Text("身分切換 (測試)")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            Button(action: {
                showingRoleChangeAlert = true
            }) {
                HStack {
                    Image(systemName: userManager.userRole == .boss ? "person.fill" : "crown.fill")
                        .font(.system(size: 18))
                        .foregroundColor(userManager.userRole == .boss ? .blue : .yellow)
                    
                    Text(userManager.userRole == .boss ? "切換到員工身分" : "切換到管理者身分")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - Settings Section
    private func settingsSection() -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
                
                Text("應用程式設定")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(spacing: 16) {
                if userManager.userRole == .boss {
                    firebaseInitializationCard()
                }
                
                settingsItems()
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private func settingsItems() -> some View {
        VStack(spacing: 12) {
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
            
            if userManager.userRole == .boss {
                NavigationLink(destination: BossSettingsView()) {
                    settingRowContent(
                        icon: "gearshape.2.fill",
                        title: "休假限制設定",
                        subtitle: "設定員工休假規則",
                        color: .orange
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                settingRow(
                    icon: "person.3.fill",
                    title: "員工管理",
                    subtitle: "管理團隊成員",
                    color: .blue
                )
            }
            
            if userManager.isLoggedIn {
                Button(action: {
                    userManager.logout()
                    isBoss = false
                }) {
                    settingRowContent(
                        icon: "rectangle.portrait.and.arrow.right",
                        title: "登出",
                        subtitle: "切換到訪客模式",
                        color: .red
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Firebase Initialization Card
    private func firebaseInitializationCard() -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "server.rack")
                    .font(.system(size: 20))
                    .foregroundColor(.purple)
                
                Text("Firebase 管理")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                initializeButton()
                
                if firebaseInitializer.isInitializing || !firebaseInitializer.initializationProgress.isEmpty {
                    progressText()
                }
                
                checkDataButton()
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private func initializeButton() -> some View {
        Button(action: {
            showingFirebaseInitAlert = true
        }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("初始化測試數據")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("建立組織、員工和排休範例數據")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                if firebaseInitializer.isInitializing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(firebaseInitializer.isInitializing)
        .buttonStyle(PlainButtonStyle())
    }
    
    private func progressText() -> some View {
        Text(firebaseInitializer.initializationProgress)
            .font(.system(size: 12))
            .foregroundColor(.purple.opacity(0.8))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
    }
    
    private func checkDataButton() -> some View {
        Button(action: {
            firebaseInitializer.checkDataIntegrity()
        }) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
                
                Text("檢查數據完整性")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
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
                    subtitle: "ShiftPro v1.0.0",
                    color: .indigo
                )
                
                aboutRow(
                    icon: "questionmark.circle.fill",
                    title: "幫助與支援",
                    subtitle: "常見問題與使用指南",
                    color: .orange
                )
                
                aboutRow(
                    icon: "heart.fill",
                    title: "評價應用程式",
                    subtitle: "在 App Store 留下評價",
                    color: .pink
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
}

#Preview {
    MoreView()
}
