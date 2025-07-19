//
//  VacationModeSelectionSheet.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/10.
//

import SwiftUI

struct VacationModeSelectionSheet: View {
    @Binding var currentMode: VacationMode
    @Binding var weeklyLimit: Int
    @Binding var monthlyLimit: Int
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 說明文字
                VStack(spacing: 8) {
                    Text("選擇排休模式")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)

                    Text("選擇適合的排休規則來測試不同的UI效果")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                .padding(.bottom, 30)

                // 模式選擇
                VStack(spacing: 16) {
                    ForEach(VacationMode.allCases, id: \.self) { mode in
                        VacationModeCard(
                            mode: mode,
                            isSelected: currentMode == mode,
                            weeklyLimit: weeklyLimit,
                            monthlyLimit: monthlyLimit
                        ) {
                            currentMode = mode
                        }
                    }
                }
                .padding(.horizontal, 20)

                // 設定區域
                VStack(spacing: 20) {
                    Divider()
                        .padding(.vertical, 10)

                    VStack(spacing: 16) {
                        // 月排休天數設定
                        HStack {
                            Text("月排休天數")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)

                            Spacer()

                            Stepper(value: $monthlyLimit, in: 1...31) {
                                Text("\(monthlyLimit) 天")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                        }

                        // 週排休天數設定（僅在相關模式下顯示）
                        if currentMode == .weekly || currentMode == .monthlyWithWeeklyLimit {
                            HStack {
                                Text("週排休上限")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)

                                Spacer()

                                Stepper(value: $weeklyLimit, in: 1...7) {
                                    Text("\(weeklyLimit) 天")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer()
            }
            .navigationTitle("排休設定")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        isPresented = false
                    }
                    .foregroundColor(.blue)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.fraction(0.8)])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    VacationModeSelectionSheet(currentMode: .constant(.monthly), weeklyLimit: .constant(4), monthlyLimit: .constant(4), isPresented: .constant(true))
}
