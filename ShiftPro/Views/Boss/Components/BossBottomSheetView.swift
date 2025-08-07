//
//  BossBottomSheetView.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/11.
//

import SwiftUI

struct BossBottomSheetView: View {
    @Binding var isPresented: Bool
    @Binding var selectedAction: BossAction?

    let isVacationPublished: Bool
    let isSchedulePublished: Bool

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
                HStack {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.yellow)

                    Text("管理者動作")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Spacer()
                }
                .padding(.bottom, 8)

                // Action buttons
                VStack(spacing: 16) {
                    // Vacation Actions
                    VStack(spacing: 12) {
                        sectionHeader(title: "排休管理", icon: "calendar.badge.checkmark", color: .blue)

                        if !isVacationPublished {
                            actionButton(
                                action: .publishVacation,
                                isEnabled: true
                            )
                        } else {
                            actionButton(
                                action: .unpublishVacation,
                                isEnabled: true
                            )
                        }
                    }

                    // Schedule Actions
                    VStack(spacing: 12) {
                        sectionHeader(title: "班表管理", icon: "calendar.badge.clock", color: .green)

                        if !isSchedulePublished {
                            actionButton(
                                action: .publishSchedule,
                                isEnabled: true
                            )
                        } else {
                            actionButton(
                                action: .unpublishSchedule,
                                isEnabled: true
                            )
                        }
                    }

                    // Settings
                    VStack(spacing: 12) {
                        sectionHeader(title: "系統設定", icon: "gearshape.fill", color: .gray)

                        actionButton(
                            action: .manageVacationLimits,
                            isEnabled: true
                        )
                    }
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

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()
        }
    }

    private func actionButton(action: BossAction, isEnabled: Bool) -> some View {
        Button(action: {
            selectedAction = action
            isPresented = false
        }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(colorFromString(action.color.primary).opacity(0.1))
                        .frame(width: 50, height: 50)

                    Image(systemName: action.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(colorFromString(action.color.primary))
                }

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(action.displayName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isEnabled ? .primary : .secondary)

                    Text(action.subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                // Status indicator or chevron
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
                    .stroke(colorFromString(action.color.primary).opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func colorFromString(_ colorString: String) -> Color {
        switch colorString {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "yellow": return .yellow
        case "purple": return .purple
        case "gray": return .gray
        default: return .gray
        }
    }
}

#Preview {
    BossBottomSheetView(
        isPresented: .constant(true),
        selectedAction: .constant(.publishVacation),
        isVacationPublished: false,
        isSchedulePublished: true
    )
}
