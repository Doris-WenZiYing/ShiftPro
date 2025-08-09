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
    @State private var autoHideTimer: Timer?

    var body: some View {
        if isShowing {
            VStack {
                Spacer()

                HStack(spacing: 12) {
                    // 🎨 圖標區域
                    VStack {
                        Image(systemName: type.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(type.color)
                            .scaleEffect(animationScale)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0.3), value: animationScale)
                    }
                    .frame(width: 30)

                    // 📝 內容區域
                    VStack(alignment: .leading, spacing: 4) {
                        Text(message)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        // 額外信息
                        if let extraInfo = getExtraInfo() {
                            Text(extraInfo)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // ❌ 關閉按鈕（對於需要手動關閉的類型）
                    if type.showCloseButton {
                        Button(action: {
                            dismissToast()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(toastBackground)
                .scaleEffect(animationScale)
                .opacity(animationOpacity)
                .offset(y: animationOffset)
                .padding(.horizontal, 20)
                .padding(.bottom, getBottomPadding())
            }
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            ))
            .onAppear {
                showToast()
            }
            .onDisappear {
                cancelAutoHide()
            }
            .onTapGesture {
                // 允許點擊關閉
                dismissToast()
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.height > 50 {
                            dismissToast()
                        }
                    }
            )
        }
    }

    // MARK: - 🎨 UI 組件

    private var toastBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(type.color.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: type.color.opacity(0.2), radius: 10, x: 0, y: 5)
            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
    }

    // MARK: - 🔧 輔助方法

    private func getExtraInfo() -> String? {
        switch type {
        case .weeklySuccess, .weeklyWarning, .weeklyLimit:
            return "週一～週日為一週"
        case .error:
            return "點擊或向下滑動可關閉"
        default:
            return nil
        }
    }

    private func getBottomPadding() -> CGFloat {
        // 根據設備類型調整底部間距
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 160 // iPad
        } else {
            return 140 // iPhone
        }
    }

    // MARK: - 🎬 動畫控制

    private func showToast() {
        // 入場動畫
        withAnimation(.easeOut(duration: 0.3)) {
            animationScale = 1.0
            animationOpacity = 1.0
            animationOffset = 0
        }

        // 圖標彈跳動畫
        withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
            animationScale = 1.1
        }

        withAnimation(.easeOut(duration: 0.2).delay(0.5)) {
            animationScale = 1.0
        }

        // 設定自動隱藏
        setupAutoHide()
    }

    private func setupAutoHide() {
        cancelAutoHide()

        let hideDelay = type.duration

        autoHideTimer = Timer.scheduledTimer(withTimeInterval: hideDelay, repeats: false) { _ in
            dismissToast()
        }
    }

    private func dismissToast() {
        cancelAutoHide()

        withAnimation(.easeInOut(duration: 0.3)) {
            isShowing = false
        }
    }

    private func cancelAutoHide() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
    }
}

// MARK: - 🎨 Toast 類型擴展
extension ToastType {
    var toastBackgroundColor: Color {
        switch self {
        case .success, .weeklySuccess:
            return .green.opacity(0.1)
        case .error:
            return .red.opacity(0.1)
        case .info:
            return .blue.opacity(0.1)
        case .warning, .weeklyWarning, .weeklyLimit:
            return .orange.opacity(0.1)
        }
    }

    /// 是否顯示進度條（對於長時間顯示的 Toast）
    var showProgressBar: Bool {
        switch self {
        case .error, .weeklyLimit:
            return true
        default:
            return false
        }
    }
}

// MARK: - 🎯 Toast 管理器
class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published var currentToast: (message: String, type: ToastType)?
    @Published var isShowing = false

    private var toastQueue: [(String, ToastType)] = []
    private var isProcessingQueue = false

    private init() {}

    /// 顯示 Toast
    func show(_ message: String, type: ToastType) {
        DispatchQueue.main.async {
            if self.isShowing {
                // 如果正在顯示 Toast，加入佇列
                self.toastQueue.append((message, type))
            } else {
                self.showImmediately(message, type: type)
            }
        }
    }

    /// 立即顯示 Toast
    private func showImmediately(_ message: String, type: ToastType) {
        currentToast = (message, type)
        isShowing = true

        // 自動隱藏
        let delay = type.duration
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.hide()
        }
    }

    /// 隱藏 Toast
    func hide() {
        isShowing = false
        currentToast = nil

        // 處理佇列中的下一個 Toast
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.processQueue()
        }
    }

    /// 處理佇列
    private func processQueue() {
        guard !toastQueue.isEmpty, !isShowing else { return }

        let next = toastQueue.removeFirst()
        showImmediately(next.0, type: next.1)
    }

    /// 清除所有 Toast
    func clearAll() {
        toastQueue.removeAll()
        hide()
    }
}

// MARK: - 🔧 便利方法
extension View {
    /// 添加 Toast 支援
    func toast(message: String, type: ToastType, isShowing: Binding<Bool>) -> some View {
        self.overlay {
            ToastView(message: message, type: type, isShowing: isShowing)
                .zIndex(1000)
        }
    }

    /// 使用全域 Toast 管理器
    func globalToast() -> some View {
        self.overlay {
            GlobalToastView()
                .zIndex(1000)
        }
    }
}

// MARK: - 🌍 全域 Toast View
struct GlobalToastView: View {
    @StateObject private var toastManager = ToastManager.shared

    var body: some View {
        Group {
            if let toast = toastManager.currentToast {
                ToastView(
                    message: toast.message,
                    type: toast.type,
                    isShowing: $toastManager.isShowing
                )
            }
        }
    }
}

// MARK: - 📱 預覽
#Preview {
    VStack(spacing: 20) {
        Button("Success Toast") {
            ToastManager.shared.show("操作成功！", type: .success)
        }

        Button("Error Toast") {
            ToastManager.shared.show("發生錯誤，請重試", type: .error)
        }

        Button("Weekly Success") {
            ToastManager.shared.show("排休成功！還可排休 3 天（總計），1 天（本週）", type: .weeklySuccess)
        }

        Button("Weekly Limit") {
            ToastManager.shared.show("已超過第 2 週最多可排 2 天的限制", type: .weeklyLimit)
        }
    }
    .padding()
    .background(Color.black)
    .globalToast()
}
