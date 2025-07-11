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
        GeometryReader { geometry in
            ZStack {
                // 半透明背景遮罩
                Color.black.opacity(0.4)
                    .ignoresSafeArea(.all)
                    .onTapGesture {
                        closeMenu()
                    }

                // 側邊菜單
                HStack(spacing: 0) {
                    Spacer()

                    // 菜單內容
                    VStack(spacing: 0) {
                        // Calendar 區域
                        VStack(spacing: 0) {
                            // 標題
                            HStack {
                                Text("Calendar")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 60) // 適應狀態欄
                            .padding(.bottom, 20)

                            // Calendar 選項
                            VStack(spacing: 0) {
                                MenuListItem(
                                    icon: "doc.text",
                                    title: "Agenda"
                                ) {
                                    // TODO: Agenda view
                                    closeMenu()
                                }

                                MenuListItem(
                                    icon: "calendar",
                                    title: "Day"
                                ) {
                                    // TODO: Day view
                                    closeMenu()
                                }

                                MenuListItem(
                                    icon: "doc.text",
                                    title: "Week"
                                ) {
                                    // TODO: Week view
                                    closeMenu()
                                }

                                MenuListItem(
                                    icon: "doc.text",
                                    title: "Month"
                                ) {
                                    // TODO: Month view
                                    closeMenu()
                                }

                                MenuListItem(
                                    icon: "calendar.badge.plus",
                                    title: "Year"
                                ) {
                                    // TODO: Year view
                                    closeMenu()
                                }
                            }
                            .padding(.bottom, 32)
                        }

                        // Events 區域
                        VStack(spacing: 0) {
                            // 標題
                            HStack {
                                Text("Events")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 20)

                            // Events 選項
                            VStack(spacing: 0) {
                                MenuListItem(
                                    icon: "checkmark.square",
                                    title: "排休模式",
                                    subtitle: currentVacationMode.rawValue
                                ) {
                                    closeMenu()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isVacationModeMenuPresented = true
                                    }
                                }

                                MenuListItem(
                                    icon: "gearshape",
                                    title: "排休設定"
                                ) {
                                    closeMenu()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isVacationModeMenuPresented = true
                                    }
                                }

                                MenuListItem(
                                    icon: "square.and.arrow.up",
                                    title: "分享排班表"
                                ) {
                                    // TODO: 分享功能
                                    closeMenu()
                                }

                                MenuListItem(
                                    icon: "square.and.arrow.down",
                                    title: "匯出資料"
                                ) {
                                    // TODO: 匯出功能
                                    closeMenu()
                                }
                            }
                            .padding(.bottom, 24)
                        }

                        Spacer()

                        // Show More 按鈕
                        Button(action: {
                            // TODO: Show more functionality
                            closeMenu()
                        }) {
                            HStack {
                                Spacer()
                                Text("Show More")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color.blue)
                            )
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 34) // 適應底部安全區域
                    }
                    .frame(width: 320)
                    .background(
                        Rectangle()
                            .fill(Color(.systemGray6).opacity(0.95))
                            .background(Color.black.opacity(0.85))
                    )
                    .shadow(color: .black.opacity(0.3), radius: 20, x: -5, y: 0)
                    .offset(x: isPresented ? 0 : 320) // 側邊滑動效果
                    .animation(.easeInOut(duration: 0.3), value: isPresented)
                }
            }
        }
        .transition(.identity) // 移除默認轉場，使用自定義動畫
    }

    private func closeMenu() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPresented = false
        }
    }
}

// MARK: - MenuListItem 組件
struct MenuListItem: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // 圖標
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 24, height: 24)

                // 文字內容
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                Rectangle()
                    .fill(isPressed ? Color.white.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onPressGesture(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
    }
}

// MARK: - 按壓手勢擴展
extension View {
    func onPressGesture(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        CustomMenuOverlay(
            isPresented: .constant(true),
            currentVacationMode: .constant(.monthly),
            isVacationModeMenuPresented: .constant(false)
        )
    }
}
