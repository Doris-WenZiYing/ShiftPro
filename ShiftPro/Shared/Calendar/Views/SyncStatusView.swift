//
//  SyncStatusView.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/25.
//

import SwiftUI
import Network

enum SyncStatus {
    case connected
    case disconnected
    case syncing
    case error

    var color: Color {
        switch self {
        case .connected: return .green
        case .disconnected: return .gray
        case .syncing: return .blue
        case .error: return .red
        }
    }

    var icon: String {
        switch self {
        case .connected: return "cloud.fill"
        case .disconnected: return "icloud.slash"
        case .syncing: return "cloud.bolt"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    var text: String {
        switch self {
        case .connected: return "已同步"
        case .disconnected: return "離線"
        case .syncing: return "同步中"
        case .error: return "同步錯誤"
        }
    }
}

class SyncStatusManager: ObservableObject {
    static let shared = SyncStatusManager()

    @Published var currentStatus: SyncStatus = .disconnected
    @Published var lastSyncTime: Date?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    // 🔥 優化：防止過度更新
    private var lastStatusUpdate: Date = Date.distantPast
    private let minUpdateInterval: TimeInterval = 1.0 // 最少1秒間隔

    private init() {
        startNetworkMonitoring()
    }

    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    self?.updateStatus(.connected)
                } else {
                    self?.updateStatus(.disconnected)
                }
            }
        }
        monitor.start(queue: queue)
    }

    // 🔥 優化：控制更新頻率
    private func updateStatus(_ newStatus: SyncStatus) {
        let now = Date()
        guard now.timeIntervalSince(lastStatusUpdate) >= minUpdateInterval else {
            return
        }

        currentStatus = newStatus
        if newStatus == .connected {
            lastSyncTime = now
        }
        lastStatusUpdate = now
    }

    func setSyncing() {
        updateStatus(.syncing)
    }

    func setSyncSuccess() {
        updateStatus(.connected)
        lastSyncTime = Date()
    }

    func setSyncError() {
        updateStatus(.error)
    }
}

struct SyncStatusView: View {
    @StateObject private var syncManager = SyncStatusManager.shared

    var body: some View {
        HStack(spacing: 6) {
            // 狀態圖標
            Image(systemName: syncManager.currentStatus.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(syncManager.currentStatus.color)

            // 狀態文字
            Text(syncManager.currentStatus.text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(syncManager.currentStatus.color)

            // 🔥 優化：最後同步時間顯示
            if let lastSync = syncManager.lastSyncTime {
                Text("• \(formatSyncTime(lastSync))")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(syncManager.currentStatus.color.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(syncManager.currentStatus.color.opacity(0.3), lineWidth: 1)
        )
    }

    // 🔥 優化：更精確的時間格式化
    private func formatSyncTime(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 10 {
            return "剛剛"
        } else if interval < 60 {
            return "\(Int(interval))秒前"
        } else if interval < 3600 {
            return "\(Int(interval / 60))分鐘前"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))小時前"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: date)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        SyncStatusView()
    }
    .padding()
    .background(Color.black)
}
