//
//  VacationModeCard.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/10.
//

import SwiftUI

struct VacationModeCard: View {
    let mode: VacationMode
    let isSelected: Bool
    let weeklyLimit: Int
    let monthlyLimit: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // 圖示
                Image(systemName: mode.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(isSelected ? .white : .blue)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.blue : Color.blue.opacity(0.1))
                    )

                // 內容
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .primary)

                    Text(mode.description)
                        .font(.system(size: 13))
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                        .multilineTextAlignment(.leading)

                    // 顯示當前設定
                    if mode == .weekly {
                        Text("每週最多 \(weeklyLimit) 天")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .green)
                    } else if mode == .monthly {
                        Text("每月最多 \(monthlyLimit) 天")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .blue)
                    } else if mode == .monthlyWithWeeklyLimit {
                        Text("每月 \(monthlyLimit) 天，每週最多 \(weeklyLimit) 天")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .orange)
                    }
                }

                Spacer()

                // 選中指示器
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VacationModeCard(mode: .monthly, isSelected: true, weeklyLimit: 4, monthlyLimit: 4, onTap: {})
}
