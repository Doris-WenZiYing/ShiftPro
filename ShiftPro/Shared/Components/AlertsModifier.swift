//
//  AlertsModifier.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/25.
//

import SwiftUI

struct AlertsModifier: ViewModifier {
    @Binding var showingRoleChangeAlert: Bool
    let userManager: UserManager
    @Binding var isBoss: Bool

    func body(content: Content) -> some View {
        content
            .alert("切換身分", isPresented: $showingRoleChangeAlert) {
                roleChangeAlert()
            } message: {
                Text(userManager.userRole == .boss ? "確定要切換到員工身分嗎？" : "確定要切換到管理者身分嗎？")
            }
    }

    // MARK: - 身分切換 Alert
    @ViewBuilder
    private func roleChangeAlert() -> some View {
        Button("取消", role: .cancel) { }

        Button("確認切換") {
            // 🔥 修復：檢查是否在訪客模式，只有訪客模式才允許切換
            guard userManager.isGuest else {
                print("⚠️ 只有訪客模式下才能切換身分")
                return
            }

            let oldRole = userManager.userRole
            withAnimation(.easeInOut(duration: 0.3)) {
                // 🔥 修復：直接實現身分切換邏輯，而不是調用 switchRole 方法
                switchUserRole()
                isBoss = (userManager.userRole == .boss)
                print("🔄 身分切換：\(oldRole) → \(userManager.userRole)")
            }
        }
    }

    // MARK: - 🔥 新增：身分切換實現
    private func switchUserRole() {
        guard userManager.isGuest else {
            print("⚠️ 切換身分僅在訪客模式下可用")
            return
        }

        guard let user = userManager.currentUser, let org = userManager.currentOrganization else {
            print("❌ 缺少用戶或組織資訊，無法切換身分")
            return
        }

        if userManager.userRole == .boss {
            // 切換到員工
            userManager.setCurrentEmployee(
                employeeId: "demo_employee",
                employeeName: user.name,
                orgId: org.id,
                orgName: org.name
            )
        } else {
            // 切換到老闆
            userManager.setCurrentBoss(
                orgId: org.id,
                bossName: user.name,
                orgName: org.name
            )
        }

        print("🔄 身分切換完成: \(userManager.userRole.rawValue)")
    }
}

// MARK: - 便利擴展
extension View {
    func moreViewAlerts(
        showingRoleChangeAlert: Binding<Bool>,
        userManager: UserManager,
        isBoss: Binding<Bool>
    ) -> some View {
        self.modifier(
            AlertsModifier(
                showingRoleChangeAlert: showingRoleChangeAlert,
                userManager: userManager,
                isBoss: isBoss
            )
        )
    }
}
