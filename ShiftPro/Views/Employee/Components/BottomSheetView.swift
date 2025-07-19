//
//  BottomSheetView.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/9.
//

import SwiftUI

struct BottomSheetView: View {
    @Binding var isPresented: Bool
    @Binding var selectedAction: ShiftAction?

    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 16)

            VStack(spacing: 20) {
                // Title
                Text("選擇動作")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.bottom, 8)

                // Action buttons
                VStack(spacing: 16) {
                    actionButton(
                        title: "編輯排休日",
                        subtitle: "選擇需要排休的日期",
                        icon: "calendar.badge.minus",
                        color: .blue,
                        action: .editVacation
                    )

                    actionButton(
                        title: "清除排休日",
                        subtitle: "重置所有排休資料 (Debug)",
                        icon: "trash.circle",
                        color: .red,
                        action: .clearVacation
                    )
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: -5)
                .ignoresSafeArea(.all)
        )
        .ignoresSafeArea(.all)
    }

    private func actionButton(title: String, subtitle: String, icon: String, color: Color, action: ShiftAction) -> some View {
        Button(action: {
            selectedAction = action
            isPresented = false
        }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 50, height: 50)

                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(color)
                }

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6).opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    BottomSheetView(
        isPresented: .constant(true),
        selectedAction: .constant(.editVacation)
    )
}
