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
        case .disconnected: return "cloud.slash"
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

    private init() {
        startNetworkMonitoring()
    }

    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    self?.currentStatus = .connected
                    self?.lastSyncTime = Date()
                } else {
                    self?.currentStatus = .disconnected
                }
            }
        }
        monitor.start(queue: queue)
    }

    func setSyncing() {
        currentStatus = .syncing
    }

    func setSyncSuccess() {
        currentStatus = .connected
        lastSyncTime = Date()
    }

    func setSyncError() {
        currentStatus = .error
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

            // 最後同步時間
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

    private func formatSyncTime(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "剛剛"
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

// MARK: - SyncStatusManager 在 ViewModel 中的使用示例
// 注意：實際的同步狀態管理應該在各自的 ViewModel 內部實現

#Preview {
    VStack(spacing: 20) {
        SyncStatusView()

        // 不同狀態的預覽
        HStack(spacing: 6) {
            Image(systemName: "cloud.bolt")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.blue)
            Text("同步中")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.blue)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    .padding()
    .background(Color.black)
}
