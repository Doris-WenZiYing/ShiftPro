//
//  FirebaseTestView.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/17.
//

import SwiftUI

struct FirebaseTestView: View {
    @StateObject private var viewModel = VacationRulesFirebaseViewModel()
    @State private var selectedMonth = "2025-08"
    @State private var selectedType = "monthly"
    @State private var monthlyLimit = 9
    @State private var weeklyLimit = 2
    @State private var isPublished = true

    private let months = ["2025-08", "2025-09", "2025-10", "2025-11", "2025-12"]
    private let types = ["monthly", "weekly", "flexible"]

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    // 連接狀態
                    connectionStatusView()

                    // 新增規則表單
                    addRuleForm()

                    // 規則列表
                    rulesListView()

                    // 操作按鈕
                    actionButtons()
                }
                .padding()
            }
            .navigationTitle("Firebase 測試")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("錯誤", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("確定") {
                viewModel.clearError()
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - 連接狀態視圖
    private func connectionStatusView() -> some View {
        HStack {
            Image(systemName: viewModel.isConnected ? "wifi" : "wifi.slash")
                .foregroundColor(viewModel.isConnected ? .green : .red)

            Text(viewModel.isConnected ? "已連接 Firebase" : "未連接 Firebase")
                .foregroundColor(viewModel.isConnected ? .green : .red)

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }

    // MARK: - 新增規則表單
    private func addRuleForm() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新增休假規則")
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 12) {
                // 月份選擇
                HStack {
                    Text("月份:")
                        .foregroundColor(.white)
                    Spacer()
                    Picker("月份", selection: $selectedMonth) {
                        ForEach(months, id: \.self) { month in
                            Text(month).tag(month)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .foregroundColor(.blue)
                }

                // 類型選擇
                HStack {
                    Text("類型:")
                        .foregroundColor(.white)
                    Spacer()
                    Picker("類型", selection: $selectedType) {
                        ForEach(types, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .foregroundColor(.blue)
                }

                // 月限制
                HStack {
                    Text("月限制:")
                        .foregroundColor(.white)
                    Spacer()
                    Stepper(value: $monthlyLimit, in: 0...31) {
                        Text("\(monthlyLimit) 天")
                            .foregroundColor(.white)
                    }
                }

                // 週限制
                HStack {
                    Text("週限制:")
                        .foregroundColor(.white)
                    Spacer()
                    Stepper(value: $weeklyLimit, in: 0...7) {
                        Text("\(weeklyLimit) 天")
                            .foregroundColor(.white)
                    }
                }

                // 是否發佈
                HStack {
                    Text("已發佈:")
                        .foregroundColor(.white)
                    Spacer()
                    Toggle("", isOn: $isPublished)
                }
            }

            // 保存按鈕
            Button(action: {
                viewModel.saveVacationRule(
                    month: selectedMonth,
                    type: selectedType,
                    monthlyLimit: monthlyLimit,
                    weeklyLimit: weeklyLimit,
                    published: isPublished
                )
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("保存規則")
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(8)
            }
            .disabled(viewModel.isLoading)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }

    // MARK: - 規則列表視圖
    private func rulesListView() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("休假規則列表 (\(viewModel.vacationRules.count))")
                .font(.headline)
                .foregroundColor(.white)

            if viewModel.vacationRules.isEmpty {
                Text("暫無規則")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ForEach(viewModel.vacationRules, id: \.month) { rule in
                    ruleItemView(rule)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }

    // MARK: - 規則項目視圖
    private func ruleItemView(_ rule: VacationRuleFirebase) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(rule.month)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Text(rule.type)
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)

                // 發佈狀態
                Image(systemName: rule.published ? "checkmark.circle.fill" : "clock.circle")
                    .foregroundColor(rule.published ? .green : .orange)
            }

            HStack {
                Text("月限制: \(rule.monthlyLimit) 天")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)

                Spacer()

                Text("週限制: \(rule.weeklyLimit) 天")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }

            Text("更新時間: \(DateFormatter.shortDateTime.string(from: rule.updatedAt))")
                .font(.system(size: 12))
                .foregroundColor(.gray.opacity(0.8))
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }

    // MARK: - 操作按鈕
    private func actionButtons() -> some View {
        HStack(spacing: 16) {
            Button(action: {
                viewModel.createSampleData()
            }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("創建示範數據")
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.green)
                .cornerRadius(8)
            }

            Button(action: {
                viewModel.loadVacationRules()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("重新載入")
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.orange)
                .cornerRadius(8)
            }

            Button(action: {
                viewModel.clearAllData()
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("清除所有")
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.red)
                .cornerRadius(8)
            }
        }
        .disabled(viewModel.isLoading)
    }
}

// MARK: - DateFormatter 擴展
extension DateFormatter {
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    FirebaseTestView()
}
