//
//  UIModels.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/8/7.
//

import SwiftUI

public enum ToastType: CaseIterable {
    case success
    case error
    case info
    case warning
    case weeklySuccess
    case weeklyWarning
    case weeklyLimit

    public var color: Color {
        switch self {
        case .success, .weeklySuccess:
            return .green
        case .error:
            return .red
        case .info:
            return .blue
        case .warning, .weeklyWarning, .weeklyLimit:
            return .orange
        }
    }

    public var icon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.circle.fill"
        case .weeklySuccess:
            return "calendar.badge.checkmark"
        case .weeklyWarning:
            return "calendar.badge.exclamationmark"
        case .weeklyLimit:
            return "calendar.day.timeline.leading"
        }
    }

    public var backgroundColor: Color {
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

    /// Toast 顯示時長（秒）
    public var duration: Double {
        switch self {
        case .error, .weeklyLimit:
            return 5.0 // 錯誤訊息顯示更久
        case .weeklySuccess:
            return 4.0 // 週休成功訊息顯示久一點
        default:
            return 3.0 // 一般訊息
        }
    }

    /// 是否顯示關閉按鈕
    public var showCloseButton: Bool {
        switch self {
        case .error, .weeklyLimit:
            return true
        default:
            return false
        }
    }
}

// MARK: - 🎭 Loading & Status Models

public enum SyncStatus {
    case connected
    case disconnected
    case syncing
    case error

    public var color: Color {
        switch self {
        case .connected: return .green
        case .disconnected: return .gray
        case .syncing: return .blue
        case .error: return .red
        }
    }

    public var icon: String {
        switch self {
        case .connected: return "cloud.fill"
        case .disconnected: return "icloud.slash"
        case .syncing: return "cloud.bolt"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    public var text: String {
        switch self {
        case .connected: return "已同步"
        case .disconnected: return "離線"
        case .syncing: return "同步中"
        case .error: return "同步錯誤"
        }
    }
}

// MARK: - 📊 Status Badge Models

public struct StatusBadgeConfig {
    public let title: String
    public let status: String
    public let color: Color
    public let icon: String

    public init(title: String, status: String, color: Color, icon: String) {
        self.title = title
        self.status = status
        self.color = color
        self.icon = icon
    }
}

// MARK: - 🎪 Presentation Models

public enum PresentationStyle {
    case sheet
    case fullScreen
    case popover

    public var detent: PresentationDetent {
        switch self {
        case .sheet: return .medium
        case .fullScreen: return .large
        case .popover: return .fraction(0.3)
        }
    }
}
