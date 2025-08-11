//
//  CalendarComponents.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/8/7.
//

import SwiftUI

// MARK: - 📅 Calendar UI Components

// MARK: - Month Title Component
struct CalendarMonthTitle: View {
    let month: CalendarMonth
    let onDatePickerTap: () -> Void
    let loadingState: LoadingState
    let statusInfo: [StatusInfo]

    enum LoadingState {
        case idle
        case loading(String)
    }

    struct StatusInfo {
        let title: String
        let status: String
        let color: Color
        let icon: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: onDatePickerTap) {
                    HStack(spacing: 8) {
                        Text(month.monthName)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Text("\(month.yearString)年")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))

                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                // 載入狀態指示器
                if case .loading(let message) = loadingState {
                    HStack(spacing: 6) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.8)

                        Text(message)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(12)
                }
            }

            // 狀態顯示區
            if !statusInfo.isEmpty {
                HStack(spacing: 12) {
                    ForEach(statusInfo, id: \.title) { info in
                        StatusCard(
                            title: info.title,
                            status: info.status,
                            color: info.color,
                            icon: info.icon
                        )
                    }

                    SyncStatusView()
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
}

// MARK: - Calendar Cell Component
struct CalendarCell: View {
    let date: CalendarDate
    let cellHeight: CGFloat
    let state: CellState
    let action: () -> Void

    enum CellState: Equatable {
        case normal
        case selected
        case vacationSelected
        case disabled
        case today

        var backgroundColor: Color {
            switch self {
            case .normal: return Color.gray.opacity(0.05)
            case .selected: return Color.white.opacity(0.2)
            case .vacationSelected: return Color.orange.opacity(0.3)
            case .disabled: return Color.gray.opacity(0.05)
            case .today: return Color.blue.opacity(0.2)
            }
        }

        var textColor: Color {
            switch self {
            case .normal: return .white
            case .selected: return .black
            case .vacationSelected: return .orange
            case .disabled: return .gray
            case .today: return .blue
            }
        }

        var borderColor: Color? {
            switch self {
            case .selected: return .blue
            case .vacationSelected: return .orange
            case .today: return .blue
            default: return nil
            }
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(state.backgroundColor)
                    .frame(height: cellHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(state.borderColor ?? Color.clear, lineWidth: 2)
                    )

                VStack(spacing: 4) {
                    Text("\(date.day)")
                        .font(.system(size: min(cellHeight / 5, 14), weight: .medium))
                        .foregroundColor(state.textColor)
                        .padding(.top, 8)

                    // 指示器
                    indicatorsView()

                    Spacer()
                }

                // 禁用遮罩
                if state == .disabled {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.3))
                        .frame(height: cellHeight)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(state == .disabled)
        .opacity(date.isCurrentMonth == true ? 1.0 : 0.3)
        .scaleEffect(state == .selected ? 1.05 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: state)
    }

    private func indicatorsView() -> some View {
        HStack(spacing: 2) {
            if state == .selected {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 6, height: 6)
            }

            if state == .vacationSelected {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
            }

            if date.isToday {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
            }
        }
    }
}

// MARK: - Calendar Grid Component
struct CalendarGrid: View {
    let month: CalendarMonth
    let cellHeight: CGFloat
    let onCellTap: (CalendarDate) -> Void
    let cellStateProvider: (CalendarDate) -> CalendarCell.CellState

    private let gridItems = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        LazyVGrid(columns: gridItems, alignment: .center, spacing: 2) {
            ForEach(0..<42, id: \.self) { index in
                let dates = month.getDaysInMonth(offset: 0)
                let date = dates[index]

                CalendarCell(
                    date: date,
                    cellHeight: cellHeight,
                    state: cellStateProvider(date)
                ) {
                    onCellTap(date)
                }
            }
        }
        .background(Color.black)
        .padding(.horizontal, 8)
        .animation(.easeInOut(duration: 0.2), value: month)
    }
}

// MARK: - Weekday Headers Component
struct WeekdayHeaders: View {
    private let weekdays: [String] = {
        let formatter = DateFormatter()
        return formatter.shortWeekdaySymbols.map { String($0.prefix(1)) }
    }()

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<7, id: \.self) { index in
                Text(weekdays[index])
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .textCase(.uppercase)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 12)
    }
}

// MARK: - Calendar Navigation Component
struct CalendarNavigation: View {
    let currentMonth: CalendarMonth
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onDatePicker: () -> Void

    var body: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }

            Spacer()

            Button(action: onDatePicker) {
                VStack(spacing: 2) {
                    Text(currentMonth.monthName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Text("\(currentMonth.year)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            Spacer()

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: 0.2), value: currentMonth)
    }
}

// MARK: - Complete Calendar View Component
struct UnifiedCalendarView: View {
    let month: CalendarMonth
    let onCellTap: (CalendarDate) -> Void
    let cellStateProvider: (CalendarDate) -> CalendarCell.CellState
    let monthTitleConfig: CalendarMonthTitle.LoadingState
    let statusInfo: [CalendarMonthTitle.StatusInfo]
    let onDatePickerTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            CalendarMonthTitle(
                month: month,
                onDatePickerTap: onDatePickerTap,
                loadingState: monthTitleConfig,
                statusInfo: statusInfo
            )

            WeekdayHeaders()

            GeometryReader { geometry in
                let availableHeight = geometry.size.height
                let cellHeight = max((availableHeight - 20) / 6, 70)

                CalendarGrid(
                    month: month,
                    cellHeight: cellHeight,
                    onCellTap: onCellTap,
                    cellStateProvider: cellStateProvider
                )
            }
        }
    }
}

// MARK: - Calendar Action Bar Component
struct CalendarActionBar: View {
    let mode: ActionBarMode
    let isEnabled: Bool
    let onPrimaryAction: () -> Void
    let onSecondaryAction: (() -> Void)?
    let onTertiaryAction: (() -> Void)?

    enum ActionBarMode: Equatable {
        case edit(hasSelection: Bool)
        case submit
        case view
        case disabled(reason: String)

        var primaryTitle: String {
            switch self {
            case .edit(let hasSelection):
                return hasSelection ? "提交排休" : "開始排休"
            case .submit:
                return "確認提交"
            case .view:
                return "查看詳情"
            case .disabled(let reason):
                return reason
            }
        }

        var primaryIcon: String {
            switch self {
            case .edit:
                return "calendar.badge.plus"
            case .submit:
                return "paperplane.fill"
            case .view:
                return "eye.fill"
            case .disabled:
                return "exclamationmark.triangle.fill"
            }
        }

        var primaryColor: Color {
            switch self {
            case .edit:
                return .blue
            case .submit:
                return .green
            case .view:
                return .purple
            case .disabled:
                return .gray
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 次要按鈕
            if let secondaryAction = onSecondaryAction {
                SecondaryButton(
                    title: "取消",
                    icon: "xmark.circle",
                    color: .red
                ) {
                    secondaryAction()
                }
            }

            // 第三按鈕
            if let tertiaryAction = onTertiaryAction {
                SecondaryButton(
                    title: "清除",
                    icon: "trash",
                    color: .orange
                ) {
                    tertiaryAction()
                }
            }

            // 主要按鈕
            FloatingActionButton(
                icon: mode.primaryIcon,
                color: mode.primaryColor
            ) {
                onPrimaryAction()
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 30)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: mode)
    }
}

// MARK: - Status Card Component
struct StatusCard: View {
    let title: String
    let status: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)

                Text(status)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)
            }

            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(color.opacity(0.2))
        .cornerRadius(12)
    }
}

// MARK: - Calendar Statistics Component
struct CalendarStatistics: View {
    let stats: [StatItem]

    struct StatItem {
        let title: String
        let value: String
        let color: Color
        let icon: String
    }

    var body: some View {
        HStack(spacing: 16) {
            ForEach(stats, id: \.title) { stat in
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: stat.icon)
                            .font(.system(size: 12))
                            .foregroundColor(stat.color)

                        Text(stat.value)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(stat.color)
                    }

                    Text(stat.title)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(stat.color.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: stats.count)
    }
}

// MARK: - Menu List Item Component
struct MenuListItem: View {
    let icon: String
    let title: String
    let subtitle: String?
    let action: () -> Void

    init(icon: String, title: String, subtitle: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17))
                        .foregroundColor(.white)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Vacation Mode Card Component
struct VacationModeCard: View {
    let mode: VacationMode
    let isSelected: Bool
    let weeklyLimit: Int
    let monthlyLimit: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? mode.iconColor : Color.gray.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: mode.icon)
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? .white : .gray)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(mode.description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)

                    // Limits display
                    HStack(spacing: 12) {
                        if mode == .weekly || mode == .monthlyWithWeeklyLimit {
                            limitBadge("週", "\(weeklyLimit)", .green)
                        }
                        if mode == .monthly || mode == .monthlyWithWeeklyLimit {
                            limitBadge("月", "\(monthlyLimit)", .blue)
                        }
                    }
                    .padding(.top, 4)
                }

                Spacer()

                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? mode.iconColor : .gray.opacity(0.5))
                    .scaleEffect(isSelected ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3), value: isSelected)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? mode.iconColor.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? mode.iconColor : Color.gray.opacity(0.3), lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
    }

    private func limitBadge(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Extensions
extension VacationMode {
    var iconColor: Color {
        switch self {
        case .weekly: return .green
        case .monthly: return .blue
        case .monthlyWithWeeklyLimit: return .purple
        }
    }
}
