//
//  ToastType.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/11.
//

import SwiftUI

enum ToastType {
    case success
    case error
    case info
    case warning
    case weeklySuccess
    case weeklyWarning
    case weeklyLimit

    var color: Color {
        switch self {
        case .success, .weeklySuccess: return .green
        case .error: return .red
        case .info: return .blue
        case .warning, .weeklyWarning, .weeklyLimit: return .orange
        }
    }

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .weeklySuccess: return "calendar.badge.checkmark"
        case .weeklyWarning: return "calendar.badge.exclamationmark"
        case .weeklyLimit: return "calendar.day.timeline.leading"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .success, .weeklySuccess: return .green.opacity(0.1)
        case .error: return .red.opacity(0.1)
        case .info: return .blue.opacity(0.1)
        case .warning, .weeklyWarning, .weeklyLimit: return .orange.opacity(0.1)
        }
    }
}
