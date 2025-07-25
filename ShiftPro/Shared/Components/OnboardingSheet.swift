//
//  OnboardingSheet.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/25.
//

import SwiftUI

struct OnboardingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userManager = UserManager.shared
    @State private var selectedRole: UserRole = .employee
    @State private var userName: String = ""
    @State private var orgName: String = ""
    @State private var inviteCode: String = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                welcomeHeader()
                rolePicker()
                inputFields()
                startButton()
                Spacer()
            }
            .padding()
            .navigationTitle("設定身分")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("跳過") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Welcome Header
    private func welcomeHeader() -> some View {
        VStack(spacing: 12) {
            Text("歡迎使用 ShiftPro")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("請選擇您的身分以開始使用")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Role Picker
    private func rolePicker() -> some View {
        Picker("身分", selection: $selectedRole) {
            Text("我是員工").tag(UserRole.employee)
            Text("我是老闆").tag(UserRole.boss)
        }
        .pickerStyle(SegmentedPickerStyle())
    }

    // MARK: - Input Fields
    private func inputFields() -> some View {
        VStack(spacing: 16) {
            TextField("您的姓名", text: $userName)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            if selectedRole == .boss {
                TextField("組織名稱", text: $orgName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            } else {
                TextField("邀請碼 (選填)", text: $inviteCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
    }

    // MARK: - Start Button
    private func startButton() -> some View {
        Button("開始使用") {
            setupUser()
            dismiss()
        }
        .disabled(userName.isEmpty || (selectedRole == .boss && orgName.isEmpty))
        .buttonStyle(.borderedProminent)
    }

    // MARK: - Setup User
    private func setupUser() {
        let timestamp = Int(Date().timeIntervalSince1970)

        if selectedRole == .boss {
            let orgId = "org_\(timestamp)"
            userManager.setCurrentBoss(
                orgId: orgId,
                bossName: userName,
                orgName: orgName.isEmpty ? "我的組織" : orgName
            )
            print("🎯 新手引導：設定老闆身分 - \(userName)")
        } else {
            let employeeId = "emp_\(timestamp)"
            let defaultOrgId = inviteCode.isEmpty ? "demo_store_01" : "org_from_invite"
            let defaultOrgName = inviteCode.isEmpty ? "Demo Store" : "邀請組織"

            userManager.setCurrentEmployee(
                employeeId: employeeId,
                employeeName: userName,
                orgId: defaultOrgId,
                orgName: defaultOrgName
            )
            print("🎯 新手引導：設定員工身分 - \(userName)")
        }
    }
}

#Preview {
    OnboardingSheet()
}
