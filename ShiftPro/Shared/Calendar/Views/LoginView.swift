//
//  LoginView.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/8/3.
//

import SwiftUI
import Combine

struct LoginView: View {
    @StateObject private var userManager = UserManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var displayName = ""
    @State private var selectedRole: UserRole = .employee

    // 組織相關
    @State private var organizationName = ""
    @State private var inviteCode = ""

    // UI 狀態
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false

    // 🔥 修復：將 cancellables 改為 @State
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerView()

                        if isSignUp {
                            signUpForm()
                        } else {
                            signInForm()
                        }

                        authButtons()
                        dividerView()
                        guestModeButton()
                        switchModeButton()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
            }
            .navigationBarHidden(true)
        }
        .alert("錯誤", isPresented: $showError) {
            Button("確定") { }
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if isLoading {
                loadingOverlay()
            }
        }
    }

    // MARK: - Header
    private func headerView() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("ShiftPro")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)

            Text(isSignUp ? "建立您的排班帳號" : "歡迎回來")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.top, 40)
    }

    // MARK: - 登入表單
    private func signInForm() -> some View {
        VStack(spacing: 16) {
            inputField("電子郵件", text: $email, keyboardType: .emailAddress)
            inputField("密碼", text: $password, isSecure: true)
        }
    }

    // MARK: - 註冊表單
    private func signUpForm() -> some View {
        VStack(spacing: 20) {
            // 基本資訊
            VStack(spacing: 16) {
                inputField("顯示名稱", text: $displayName)
                inputField("電子郵件", text: $email, keyboardType: .emailAddress)
                inputField("密碼", text: $password, isSecure: true)
                inputField("確認密碼", text: $confirmPassword, isSecure: true)
            }

            // 角色選擇
            roleSelectionCard()

            // 組織資訊
            if selectedRole == .boss {
                bossOrganizationCard()
            } else {
                employeeInviteCard()
            }
        }
    }

    // MARK: - 角色選擇
    private func roleSelectionCard() -> some View {
        VStack(spacing: 16) {
            Text("選擇您的身分")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            HStack(spacing: 16) {
                roleButton(.boss, "我是老闆", "創建組織")
                roleButton(.employee, "我是員工", "加入組織")
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private func roleButton(_ role: UserRole, _ title: String, _ subtitle: String) -> some View {
        Button(action: { selectedRole = role }) {
            VStack(spacing: 8) {
                Image(systemName: role == .boss ? "crown.fill" : "person.fill")
                    .font(.system(size: 24))
                    .foregroundColor(selectedRole == role ? .white : .gray)

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(selectedRole == role ? Color.blue : Color.gray.opacity(0.2))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 老闆組織設定
    private func bossOrganizationCard() -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundColor(.orange)
                Text("組織資訊")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }

            inputField("組織名稱", text: $organizationName, placeholder: "例：我的咖啡廳")
        }
        .padding(20)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(16)
    }

    // MARK: - 員工邀請碼
    private func employeeInviteCard() -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.green)
                Text("加入組織")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }

            inputField("邀請碼", text: $inviteCode, placeholder: "輸入老闆提供的邀請碼")

            Text("請向您的老闆索取邀請碼")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(20)
        .background(Color.green.opacity(0.1))
        .cornerRadius(16)
    }

    // MARK: - 輸入欄位
    private func inputField(_ title: String, text: Binding<String>, keyboardType: UIKeyboardType = .default, isSecure: Bool = false, placeholder: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)

            Group {
                if isSecure {
                    SecureField(placeholder ?? title, text: text)
                } else {
                    TextField(placeholder ?? title, text: text)
                }
            }
            .keyboardType(keyboardType)
            .textFieldStyle(CustomTextFieldStyle())
        }
    }

    // MARK: - 按鈕
    private func authButtons() -> some View {
        VStack(spacing: 16) {
            Button(action: handleAuth) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: isSignUp ? "person.badge.plus" : "person.badge.key")
                            .font(.system(size: 16))
                    }

                    Text(isSignUp ? "註冊" : "登入")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isFormValid ? Color.blue : Color.gray)
                .cornerRadius(12)
            }
            .disabled(!isFormValid || isLoading)
        }
    }

    private func dividerView() -> some View {
        HStack {
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(height: 1)

            Text("或")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 16)

            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(height: 1)
        }
    }

    private func guestModeButton() -> some View {
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
        .disabled(isLoading)
    }

    private func switchModeButton() -> some View {
        Button(action: { isSignUp.toggle() }) {
            HStack {
                Text(isSignUp ? "已有帳號？" : "還沒有帳號？")
                    .foregroundColor(.white.opacity(0.7))

                Text(isSignUp ? "立即登入" : "立即註冊")
                    .foregroundColor(.blue)
                    .fontWeight(.semibold)
            }
            .font(.system(size: 16))
        }
        .disabled(isLoading)
    }

    // MARK: - Loading Overlay
    private func loadingOverlay() -> some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)

                Text(isSignUp ? "註冊中..." : "登入中...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(Color.black.opacity(0.8))
            .cornerRadius(16)
        }
    }

    // MARK: - Logic
    private var isFormValid: Bool {
        if isSignUp {
            return !email.isEmpty &&
                   !password.isEmpty &&
                   !confirmPassword.isEmpty &&
                   !displayName.isEmpty &&
                   password == confirmPassword &&
                   (selectedRole == .boss ? !organizationName.isEmpty : !inviteCode.isEmpty)
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }

    private func handleAuth() {
        guard isFormValid else { return }

        isLoading = true
        errorMessage = ""

        let authPublisher: AnyPublisher<Void, Error>

        if isSignUp {
            if selectedRole == .boss {
                authPublisher = userManager.signUpAsBoss(
                    email: email,
                    password: password,
                    name: displayName,
                    orgName: organizationName
                )
            } else {
                authPublisher = userManager.signUpAsEmployee(
                    email: email,
                    password: password,
                    name: displayName,
                    inviteCode: inviteCode
                )
            }
        } else {
            authPublisher = userManager.signIn(email: email, password: password)
        }

        authPublisher
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    // 🔥 修復：移除 capture list，直接使用 self
                    self.isLoading = false
                    switch completion {
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                        self.showError = true
                    case .finished:
                        break
                    }
                },
                receiveValue: {
                    // 🔥 修復：移除 capture list，直接使用 self
                    self.dismiss()
                }
            )
            .store(in: &cancellables)  // 🔥 現在可以正確使用了
    }

    private func enterGuestMode() {
        isLoading = true

        userManager.enterGuestMode()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    // 🔥 修復：移除 capture list，直接使用 self
                    self.isLoading = false
                    switch completion {
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                        self.showError = true
                    case .finished:
                        break
                    }
                },
                receiveValue: {
                    // 🔥 修復：移除 capture list，直接使用 self
                    self.dismiss()
                }
            )
            .store(in: &cancellables)  // 🔥 現在可以正確使用了
    }
}

// MARK: - Custom TextField Style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            .foregroundColor(.white)
    }
}

#Preview {
    LoginView()
}
