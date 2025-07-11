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

    // MARK: - Drag State
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false

    private let menuWidth: CGFloat = 280
    private let closeThreshold: CGFloat = 0.3
    private let topOffset: CGFloat = 100

    var body: some View {
        GeometryReader { geometry in
            let tabBarHeight = getTabBarHeight(geometry: geometry)
            let menuHeight = geometry.size.height - topOffset - tabBarHeight

            ZStack {
                Color.black.opacity(backgroundOpacity)
                    .ignoresSafeArea(.all)
                    .onTapGesture {
                        closeMenu()
                    }

                HStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 0) {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 0) {
                                VStack(spacing: 0) {
                                    HStack {
                                        Text("Calendar")
                                            .font(.system(size: 28, weight: .bold))
                                            .foregroundColor(.white)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.top, 32)
                                    .padding(.bottom, 24)

                                    VStack(spacing: 0) {
                                        MenuListItem(
                                            icon: "doc.text",
                                            title: "Agenda"
                                        ) {
                                            closeMenu()
                                        }

                                        MenuListItem(
                                            icon: "calendar",
                                            title: "Day"
                                        ) {
                                            closeMenu()
                                        }

                                        MenuListItem(
                                            icon: "doc.text",
                                            title: "Week"
                                        ) {
                                            closeMenu()
                                        }

                                        MenuListItem(
                                            icon: "doc.text",
                                            title: "Month"
                                        ) {
                                            closeMenu()
                                        }

                                        MenuListItem(
                                            icon: "calendar.badge.plus",
                                            title: "Year"
                                        ) {
                                            closeMenu()
                                        }
                                    }
                                    .padding(.bottom, 40)
                                }

                                VStack(spacing: 0) {
                                    HStack {
                                        Text("Events")
                                            .font(.system(size: 28, weight: .bold))
                                            .foregroundColor(.white)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.bottom, 24)

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
                                            closeMenu()
                                        }

                                        MenuListItem(
                                            icon: "square.and.arrow.down",
                                            title: "匯出資料"
                                        ) {
                                            closeMenu()
                                        }

                                        MenuListItem(
                                            icon: "chart.bar",
                                            title: "統計分析"
                                        ) {
                                            closeMenu()
                                        }

                                        MenuListItem(
                                            icon: "bell",
                                            title: "提醒設定"
                                        ) {
                                            closeMenu()
                                        }
                                    }
                                    .padding(.bottom, 32)
                                }

                                Button(action: {
                                    closeMenu()
                                }) {
                                    HStack {
                                        Spacer()
                                        Text("Show More")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(.white)
                                        Spacer()
                                    }
                                    .padding(.vertical, 17)
                                    .background(
                                        RoundedRectangle(cornerRadius: 28)
                                            .fill(Color.blue)
                                    )
                                }
                                .padding(.horizontal, 24)

                                Color.clear
                                    .frame(height: 30)
                            }
                        }
                        .disabled(isDragging)
                    }
                    .frame(width: menuWidth)
                    .frame(height: menuHeight)
                    .background(
                        Rectangle()
                            .fill(Color(.systemGray6).opacity(0.98))
                            .background(Color.black.opacity(0.9))
                    )
                    .cornerRadius(20, corners: [.topLeft, .bottomLeft])
                    .shadow(color: .black.opacity(0.25), radius: 15, x: -5, y: 0)
                    .offset(x: totalOffset, y: 0)
                    .clipped()
                    .gesture(
                        DragGesture(coordinateSpace: .global)
                            .onChanged { value in
                                handleDragChanged(value)
                            }
                            .onEnded { value in
                                handleDragEnded(value)
                            }
                    )
                }
                .padding(.top, topOffset)
            }
        }
        .onChange(of: isPresented) { oldValue, newValue in
            if newValue && !oldValue {
                dragOffset = 0
                isDragging = false
            }
        }
    }

    private var totalOffset: CGFloat {
        if !isPresented {
            return menuWidth
        }
        return max(0, dragOffset)
    }

    private var backgroundOpacity: Double {
        if !isPresented { return 0 }
        let progress = 1.0 - (totalOffset / menuWidth)
        return Double(max(0, min(0.6, 0.6 * progress)))
    }

    // MARK: Drag
    private func handleDragChanged(_ value: DragGesture.Value) {
        isDragging = true
        let translation = value.translation.width

        if translation > 0 {
            dragOffset = translation
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        isDragging = false

        let translation = value.translation.width
        let velocity = value.velocity.width

        // 判斷是否應該關閉
        let shouldClose = shouldCloseMenu(translation: translation, velocity: velocity)

        if shouldClose {
            closeMenu()
        } else {
            snapBackToOpen()
        }
    }

    private func shouldCloseMenu(translation: CGFloat, velocity: CGFloat) -> Bool {
        let distanceThreshold = translation > menuWidth * closeThreshold
        let velocityThreshold = velocity > 600
        return distanceThreshold || velocityThreshold
    }

    private func closeMenu() {
        isPresented = false
        dragOffset = 0
    }

    private func snapBackToOpen() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            dragOffset = 0
        }
    }

    // MARK: Calculate Tab bar height
    private func getTabBarHeight(geometry: GeometryProxy) -> CGFloat {
        // TabBar 的基本高度 = tab items (44) + top padding (5) + bottom padding
        let baseHeight: CGFloat = 44 + 5

        // 檢查是否有 home indicator
        let bottomSafeArea = geometry.safeAreaInsets.bottom
        let bottomPadding: CGFloat = bottomSafeArea > 0 ? 8 : 12

        return baseHeight + bottomPadding
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
