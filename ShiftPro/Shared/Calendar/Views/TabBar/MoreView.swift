//
//  MoreView.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/11.
//

import SwiftUI

struct MoreView: View {
    @AppStorage("isBoss") private var isBoss: Bool = false
    @State private var showingRoleChangeAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    headerView()

                    ScrollView {
                        VStack(spacing: 16) {
                            // Current Role Card
                            currentRoleCard()

                            // Role Switch Card
                            roleSwitchCard()

                            // Settings Section
                            settingsSection()

                            // About Section
                            aboutSection()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .alert("切換身分", isPresented: $showingRoleChangeAlert) {
            Button("取消", role: .cancel) { }
            Button("確認切換") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isBoss.toggle()
                }
            }
        } message: {
            Text(isBoss ? "確定要切換到員工身分嗎？" : "確定要切換到管理者身分嗎？")
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

    // MARK: - Current Role Card
    private func currentRoleCard() -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: isBoss ? "crown.fill" : "person.fill")
                    .font(.system(size: 24))
                    .foregroundColor(isBoss ? .yellow : .blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("目前身分")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))

                    Text(isBoss ? "管理者" : "員工")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                // Status Badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(isBoss ? Color.yellow : Color.blue)
                        .frame(width: 8, height: 8)

                    Text(isBoss ? "BOSS" : "STAFF")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isBoss ? .yellow : .blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background((isBoss ? Color.yellow : Color.blue).opacity(0.2))
                .cornerRadius(20)
            }

            // Role Description
            Text(isBoss ? "您可以設定員工的休假限制和管理相關規則" : "您可以申請休假並查看個人排班資訊")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    // MARK: - Role Switch Card
    private func roleSwitchCard() -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)

                Text("身分切換")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()
            }

            Button(action: {
                showingRoleChangeAlert = true
            }) {
                HStack {
                    Image(systemName: isBoss ? "person.fill" : "crown.fill")
                        .font(.system(size: 18))
                        .foregroundColor(isBoss ? .blue : .yellow)

                    Text(isBoss ? "切換到員工身分" : "切換到管理者身分")
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

                if isBoss {
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
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
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
