//
//  ErrorHandling.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/8/9.
//

import Foundation
import SwiftUI

// MARK: - 🚨 基本錯誤類型
enum ShiftProError: Error, LocalizedError {
    case networkConnection
    case firebaseError(String)
    case invalidData
    case authenticationFailed
    case noPermission
    case dataNotFound
    case validationFailed(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .networkConnection:
            return "網路連線異常，請檢查您的網路設定"
        case .firebaseError(let message):
            return "資料同步失敗：\(message)"
        case .invalidData:
            return "資料格式不正確"
        case .authenticationFailed:
            return "登入驗證失敗"
        case .noPermission:
            return "您沒有執行此操作的權限"
        case .dataNotFound:
            return "找不到相關資料"
        case .validationFailed(let message):
            return "資料驗證失敗：\(message)"
        case .unknown(let message):
            return "未知錯誤：\(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkConnection:
            return "請檢查網路連線並重試"
        case .firebaseError:
            return "請稍後再試，或聯繫技術支援"
        case .invalidData:
            return "請檢查輸入的資料是否正確"
        case .authenticationFailed:
            return "請重新登入"
        case .noPermission:
            return "請聯繫管理員獲取權限"
        case .dataNotFound:
            return "請確認資料是否存在"
        case .validationFailed:
            return "請檢查並修正輸入的資料"
        case .unknown:
            return "請重新嘗試或聯繫技術支援"
        }
    }
}

// MARK: - 🛡️ 錯誤處理工具
class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()

    @Published var currentError: ShiftProError?
    @Published var showingError = false

    private init() {}

    /// 處理錯誤並顯示給用戶
    func handle(_ error: Error, context: String = "") {
        DispatchQueue.main.async {
            let shiftProError = self.mapToShiftProError(error, context: context)
            self.currentError = shiftProError
            self.showingError = true

            // 記錄錯誤
            self.logError(shiftProError, context: context)
        }
    }

    /// 顯示特定的錯誤
    func show(_ error: ShiftProError) {
        DispatchQueue.main.async {
            self.currentError = error
            self.showingError = true
            self.logError(error, context: "Manual")
        }
    }

    /// 清除當前錯誤
    func clearError() {
        currentError = nil
        showingError = false
    }

    /// 將一般錯誤映射為 ShiftProError
    private func mapToShiftProError(_ error: Error, context: String) -> ShiftProError {
        if let shiftProError = error as? ShiftProError {
            return shiftProError
        }

        // Firebase 錯誤處理
        if error.localizedDescription.contains("network") ||
           error.localizedDescription.contains("connection") {
            return .networkConnection
        }

        if error.localizedDescription.contains("permission") ||
           error.localizedDescription.contains("unauthorized") {
            return .noPermission
        }

        if error.localizedDescription.contains("not found") {
            return .dataNotFound
        }

        // 預設為未知錯誤
        return .unknown(error.localizedDescription)
    }

    /// 記錄錯誤（簡單版本）
    private func logError(_ error: ShiftProError, context: String) {
        print("🚨 ShiftPro Error [\(context)]: \(error.errorDescription ?? "Unknown")")
        if let suggestion = error.recoverySuggestion {
            print("💡 Suggestion: \(suggestion)")
        }
    }
}

// MARK: - 🎨 錯誤顯示 View
struct ErrorView: View {
    let error: ShiftProError
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void

    init(error: ShiftProError, onRetry: (() -> Void)? = nil, onDismiss: @escaping () -> Void) {
        self.error = error
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(spacing: 20) {
            // 錯誤圖標
            Image(systemName: getErrorIcon())
                .font(.system(size: 48))
                .foregroundColor(.red)

            // 錯誤標題
            Text("發生錯誤")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            // 錯誤描述
            Text(error.errorDescription ?? "未知錯誤")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            // 恢復建議
            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            // 動作按鈕
            VStack(spacing: 12) {
                if let onRetry = onRetry {
                    PrimaryButton(
                        title: "重試",
                        icon: "arrow.clockwise"
                    ) {
                        onRetry()
                        onDismiss()
                    }
                }

                SecondaryButton(
                    title: "確定",
                    color: .gray
                ) {
                    onDismiss()
                }
            }
            .padding(.horizontal, 40)
        }
        .padding(30)
        .background(Color.black.opacity(0.9))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }

    private func getErrorIcon() -> String {
        switch error {
        case .networkConnection:
            return "wifi.slash"
        case .firebaseError:
            return "icloud.slash"
        case .authenticationFailed:
            return "person.badge.key.fill"
        case .noPermission:
            return "lock.fill"
        case .dataNotFound:
            return "doc.questionmark"
        case .validationFailed:
            return "exclamationmark.triangle.fill"
        default:
            return "exclamationmark.circle.fill"
        }
    }
}

// MARK: - 🔧 View Modifier
struct ErrorHandlingModifier: ViewModifier {
    @StateObject private var errorHandler = ErrorHandler.shared
    let onRetry: (() -> Void)?

    init(onRetry: (() -> Void)? = nil) {
        self.onRetry = onRetry
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                if errorHandler.showingError, let error = errorHandler.currentError {
                    ZStack {
                        Color.black.opacity(0.5)
                            .ignoresSafeArea()

                        ErrorView(
                            error: error,
                            onRetry: onRetry
                        ) {
                            errorHandler.clearError()
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                    .zIndex(1000)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: errorHandler.showingError)
    }
}

// MARK: - 🎯 便利方法
extension View {
    func errorHandling(onRetry: (() -> Void)? = nil) -> some View {
        self.modifier(ErrorHandlingModifier(onRetry: onRetry))
    }
}

// MARK: - 🔄 Combine 錯誤處理
import Combine

extension Publisher {
    func handleShiftProErrors() -> Publishers.Catch<Self, Just<Self.Output>> {
        self.catch { error in
            ErrorHandler.shared.handle(error)
            // 返回一個不會發出任何值的 Publisher（只是為了類型匹配）
            return Just(Output.self as! Self.Output)
        }
    }
}
