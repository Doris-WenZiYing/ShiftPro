//
//  FirebaseTestIntegration.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/17.
//

import SwiftUI
import Firebase

// MARK: - 在 ContentView 中添加 Firebase 測試按鈕
extension ContentView {

    // 🔥 新增：Firebase 測試按鈕覆蓋層
    func firebaseTestOverlay() -> some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                // 🔥 Firebase 測試按鈕（僅在 DEBUG 模式下顯示）
                #if DEBUG
                VStack(spacing: 12) {
                    Button(action: {
                        FirebaseDebugHelper.shared.testFirebaseConnection()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "cloud.fill")
                                .font(.system(size: 12))
                            Text("測試 Firebase")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .cornerRadius(16)
                    }

                    Button(action: {
                        FirebaseDebugHelper.shared.testVacationLimitsSync()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 12))
                            Text("同步測試")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(16)
                    }

                    Button(action: {
                        FirebaseDebugHelper.shared.listAllStoredLimits()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 12))
                            Text("列出數據")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.orange)
                        .cornerRadius(16)
                    }
                }
                #else
                EmptyView()
                #endif
            }
            .padding(.bottom, 100)
            .padding(.trailing, 20)
        }
    }
}

// MARK: - 在 BossSettingsView 中添加 Firebase 狀態顯示
extension BossSettingsView {

    // 🔥 新增：Firebase 狀態卡片
    func firebaseStatusCard() -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)

                Text("雲端同步狀態")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                // 🔥 Firebase 連接狀態指示器
                FirebaseConnectionIndicator()
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("自動同步到雲端")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))

                    Text("設定將即時同步給所有員工")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                #if DEBUG
                Button(action: {
                    FirebaseDebugHelper.shared.testFirebaseConnection()
                }) {
                    Text("測試連接")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
                #endif
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    // 🔥 修正：發佈按鈕使用 Firebase 同步
    func publishButtonFixed() -> some View {
        Button(action: {
            // 🔥 修正：使用正確的方法名
            publishVacationSettings()
        }) {
            HStack(spacing: 12) {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 18, weight: .semibold))

                Text("發佈到雲端")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: .blue.opacity(0.4), radius: 12, x: 0, y: 6)
        }
    }
}

// MARK: - Firebase 連接狀態指示器
struct FirebaseConnectionIndicator: View {
    @State private var isConnected = false
    @State private var isChecking = false

    var body: some View {
        HStack(spacing: 6) {
            if isChecking {
                ProgressView()
                    .scaleEffect(0.6)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Circle()
                    .fill(isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
            }

            Text(isConnected ? "已連接" : "未連接")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isConnected ? .green : .red)
        }
        .onAppear {
            checkConnection()
        }
    }

    private func checkConnection() {
        isChecking = true

        // 簡單的連接測試
        let db = Firestore.firestore()
        db.collection("test").document("connection").getDocument { document, error in
            DispatchQueue.main.async {
                isChecking = false
                isConnected = error == nil
            }
        }
    }
}

// MARK: - 在 EmployeeCalendarView 中添加 Firebase 同步狀態
extension EmployeeCalendarView {

    // 🔥 修正：Firebase 同步狀態指示器
    func firebaseSyncIndicatorFixed() -> some View {
        Group {
            if viewModel.isUsingBossSettings {
                HStack(spacing: 6) {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)

                    Text("已同步")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.2))
                .cornerRadius(8)
            } else {
                EmptyView()
            }
        }
    }
}
