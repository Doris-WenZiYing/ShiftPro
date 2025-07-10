//
//  CustomMenuOverlay.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/10.
//

import SwiftUI

struct CustomMenuOverlay: View {
    @Binding var isPresented: Bool
    @Binding var currentVacationMode: VacationMode
    @Binding var isVacationModeMenuPresented: Bool

    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPresented = false
                    }
                }

            VStack {
                HStack {
                    Spacer()

                    // 菜單內容
                    VStack(spacing: 0) {
                        // 排休模式區域
                        VStack(spacing: 0) {
                            // 區域標題
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                Text("排休模式")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 16)

                            // 模式選項
                            VStack(spacing: 0) {
                                ForEach(VacationMode.allCases, id: \.self) { mode in
                                    menuItem(
                                        icon: mode.icon,
                                        title: mode.rawValue,
                                        isSelected: currentVacationMode == mode
                                    ) {
                                        currentVacationMode = mode
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isPresented = false
                                        }
                                    }

                                    if mode != VacationMode.allCases.last {
                                        Divider()
                                            .background(Color.white.opacity(0.1))
                                            .padding(.leading, 60)
                                    }
                                }
                            }

                            Divider()
                                .background(Color.white.opacity(0.2))
                                .padding(.vertical, 8)

                            // 排休設定按鈕
                            menuItem(
                                icon: "gear",
                                title: "排休設定",
                                isSelected: false
                            ) {
                                isVacationModeMenuPresented = true
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isPresented = false
                                }
                            }
                        }

                        Divider()
                            .background(Color.white.opacity(0.3))
                            .padding(.vertical, 8)

                        // 其他功能區域
                        VStack(spacing: 0) {
                            menuItem(icon: "square.and.arrow.up", title: "分享排班表", isSelected: false) {
                                // TODO: 分享功能
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isPresented = false
                                }
                            }

                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.leading, 60)

                            menuItem(icon: "square.and.arrow.down", title: "匯出資料", isSelected: false) {
                                // TODO: 匯出功能
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isPresented = false
                                }
                            }

                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.leading, 60)

                            menuItem(icon: "questionmark.circle", title: "關於", isSelected: false) {
                                // TODO: 關於頁面
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isPresented = false
                                }
                            }
                        }
                        .padding(.bottom, 16)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .background(Color.black.opacity(0.8))
                    )
                    .frame(width: 280)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                }
                .padding(.horizontal, 24)
                .padding(.top, 80)

                Spacer()
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
    }

    // MARK: - 菜單項目
    private func menuItem(
        icon: String,
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? .blue : .white.opacity(0.9))
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .blue : .white)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                isSelected ?
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.15))
                        .padding(.horizontal, 8) :
                    nil
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    CustomMenuOverlay(isPresented: .constant(true), currentVacationMode: .constant(.monthly), isVacationModeMenuPresented: .constant(true))
}
