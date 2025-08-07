//
//  UIModels.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/8/7.
//

import SwiftUI

// MARK: - 🎨 Toast & Alert Models

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

// MARK: - 🎨 Theme & Design Models

public struct AppTheme {
    // Colors
    public static let background = Color.black
    public static let textPrimary = Color.white
    public static let accentBlue = Color(hex: "#3F8CFF")

    // Spacing
    public static let paddingSmall: CGFloat = 8
    public static let paddingMedium: CGFloat = 16
    public static let paddingLarge: CGFloat = 24

    // Corner Radius
    public static let cornerRadiusSmall: CGFloat = 8
    public static let cornerRadiusMedium: CGFloat = 12
    public static let cornerRadiusLarge: CGFloat = 16
}

// MARK: - 🎯 Animation Models

public struct AnimationPresets {
    public static let quickFade = Animation.easeInOut(duration: 0.2)
    public static let standardFade = Animation.easeInOut(duration: 0.3)
    public static let slowFade = Animation.easeInOut(duration: 0.5)

    public static let quickSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)
    public static let standardSpring = Animation.spring(response: 0.5, dampingFraction: 0.8)
    public static let bouncySpring = Animation.spring(response: 0.6, dampingFraction: 0.6)
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

// MARK: - 📐 Layout Models

public struct ViewDimensions {
    public static let tabBarHeight: CGFloat = 44
    public static let topSafeArea: CGFloat = 45
    public static let calendarCellMinHeight: CGFloat = 70
    public static let menuWidth: CGFloat = 280
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
