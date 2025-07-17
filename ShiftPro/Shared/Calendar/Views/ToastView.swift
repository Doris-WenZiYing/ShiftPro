//
//  ToastView.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/9.
//

import SwiftUI

struct ToastView: View {
    let message: String
    let type: ToastType
    @Binding var isShowing: Bool

    @State private var animationScale: CGFloat = 0.8
    @State private var animationOpacity: Double = 0
    @State private var animationOffset: CGFloat = 50

    var body: some View {
        if isShowing {
            VStack {
                Spacer()

                HStack(spacing: 12) {
                    // 🔥 優化：圖標區域
                    VStack {
                        Image(systemName: type.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(type.color)
                            .scaleEffect(animationScale)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0.3), value: animationScale)
                    }
                    .frame(width: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(message)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        if type == .weeklySuccess || type == .weeklyWarning || type == .weeklyLimit {
                            Text("週一～週日為一週")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if type == .error || type == .weeklyLimit {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isShowing = false
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(type.color.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: type.color.opacity(0.2), radius: 10, x: 0, y: 5)
                        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                )
                .scaleEffect(animationScale)
                .opacity(animationOpacity)
                .offset(y: animationOffset)
                .padding(.horizontal, 20)
                .padding(.bottom, 140)
            }
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            ))
            .onAppear {
                // 🔥 優化：入場動畫
                withAnimation(.easeOut(duration: 0.3)) {
                    animationScale = 1.0
                    animationOpacity = 1.0
                    animationOffset = 0
                }

                // 🔥 優化：圖標彈跳動畫
                withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                    animationScale = 1.1
                }

                withAnimation(.easeOut(duration: 0.2).delay(0.5)) {
                    animationScale = 1.0
                }

                // 🔥 優化：自動隱藏時間根據類型調整
                let hideDelay: Double = {
                    switch type {
                    case .error, .weeklyLimit:
                        return 5.0 // 錯誤訊息顯示更久
                    case .weeklySuccess:
                        return 4.0 // 週休成功訊息顯示久一點
                    default:
                        return 3.0 // 一般訊息
                    }
                }()

                DispatchQueue.main.asyncAfter(deadline: .now() + hideDelay) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isShowing = false
                    }
                }
            }
            .onTapGesture {
                // 🔥 新增：點擊可關閉
                withAnimation(.easeInOut(duration: 0.3)) {
                    isShowing = false
                }
            }
        }
    }
}

// MARK: - 預覽
#Preview {
    VStack(spacing: 20) {
        ToastView(message: "排休成功！還可排休 3 天（總計），1 天（本週）", type: .weeklySuccess, isShowing: .constant(true))

        ToastView(message: "已超過第 2 週最多可排 2 天的限制", type: .weeklyLimit, isShowing: .constant(true))

        ToastView(message: "已達到本月可排休上限 8 天", type: .error, isShowing: .constant(true))
    }
    .background(Color.black)
}
