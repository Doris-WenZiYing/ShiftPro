//
//  AlertsModifier.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/25.
//

import SwiftUI

struct AlertsModifier: ViewModifier {
    @Binding var showingFirebaseInitAlert: Bool
    @Binding var showingRoleChangeAlert: Bool
    let firebaseInitializer: FirebaseInitializer
    let userManager: UserManager
    @Binding var isBoss: Bool

    func body(content: Content) -> some View {
        content
            .alert("初始化 Firebase", isPresented: $showingFirebaseInitAlert) {
                firebaseInitAlert()
            } message: {
                Text("這將在 Firebase 中建立測試組織、員工和排休數據。確定要繼續嗎？")
            }
            .alert("切換身分", isPresented: $showingRoleChangeAlert) {
                roleChangeAlert()
            } message: {
                Text(userManager.userRole == .boss ? "確定要切換到員工身分嗎？" : "確定要切換到管理者身分嗎？")
            }
    }

    // MARK: - Firebase 初始化 Alert
    @ViewBuilder
    private func firebaseInitAlert() -> some View {
        Button("取消", role: .cancel) { }

        Button("確認初始化") {
            print("🚀 用戶確認初始化 Firebase 數據")
            firebaseInitializer.initializeAllTestData()
        }

        Button("檢查數據") {
            print("🔍 用戶要求檢查 Firebase 數據完整性")
            firebaseInitializer.checkDataIntegrity()
        }
    }

    // MARK: - 身分切換 Alert
    @ViewBuilder
    private func roleChangeAlert() -> some View {
        Button("取消", role: .cancel) { }

        Button("確認切換") {
            let oldRole = userManager.userRole
            withAnimation(.easeInOut(duration: 0.3)) {
                userManager.switchRole()
                isBoss = (userManager.userRole == .boss)
                print("🔄 身分切換：\(oldRole) → \(userManager.userRole)")
            }
        }
    }
}

// MARK: - 便利擴展
extension View {
    func moreViewAlerts(
        showingFirebaseInitAlert: Binding<Bool>,
        showingRoleChangeAlert: Binding<Bool>,
        firebaseInitializer: FirebaseInitializer,
        userManager: UserManager,
        isBoss: Binding<Bool>
    ) -> some View {
        self.modifier(
            AlertsModifier(
                showingFirebaseInitAlert: showingFirebaseInitAlert,
                showingRoleChangeAlert: showingRoleChangeAlert,
                firebaseInitializer: firebaseInitializer,
                userManager: userManager,
                isBoss: isBoss
            )
        )
    }
}
