//
//  FormNavigationComponents.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/8/7.
//

import SwiftUI

// MARK: - 📋 Form Components

// MARK: - Stepper Component
struct CounterStepper: View {
    let title: String
    let subtitle: String?
    let icon: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let color: Color
    let unit: String

    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        value: Binding<Int>,
        range: ClosedRange<Int> = 1...100,
        color: Color = .blue,
        unit: String = "天"
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self._value = value
        self.range = range
        self.color = color
        self.unit = unit
    }

    var body: some View {
        VStack(spacing: 16) {
            // 標題區域
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()
            }

            // 控制區域
            HStack(spacing: 20) {
                Button(action: {
                    if value > range.lowerBound {
                        value -= 1
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(value > range.lowerBound ? color : .gray)
                }
                .disabled(value <= range.lowerBound)
                .scaleEffect(value > range.lowerBound ? 1.0 : 0.9)
                .animation(.spring(response: 0.2), value: value)

                VStack(spacing: 4) {
                    Text("\(value)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: value)

                    Text(unit)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(minWidth: 80)

                Button(action: {
                    if value < range.upperBound {
                        value += 1
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(value < range.upperBound ? color : .gray)
                }
                .disabled(value >= range.upperBound)
                .scaleEffect(value < range.upperBound ? 1.0 : 0.9)
                .animation(.spring(response: 0.2), value: value)
            }
        }
        .padding(20)
        .background(color.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Selection Card Component
struct SelectionCard<T: Hashable>: View {
    let item: T
    let isSelected: Bool
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // 圖標
                ZStack {
                    Circle()
                        .fill(isSelected ? color : color.opacity(0.1))
                        .frame(width: 50, height: 50)

                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? .white : color)
                }

                // 內容
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .primary)

                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                // 選中指示器
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .white : color.opacity(0.5))
                    .scaleEffect(isSelected ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3), value: isSelected)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? color : Color(.systemGray4), lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Date Picker Component
struct DatePickerCard: View {
    let title: String
    let icon: String
    let color: Color
    @Binding var selectedDate: Date
    let dateRange: ClosedRange<Date>?
    let displayFormat: String
    let onTap: () -> Void

    init(
        title: String,
        icon: String,
        color: Color = .orange,
        selectedDate: Binding<Date>,
        dateRange: ClosedRange<Date>? = nil,
        displayFormat: String = "yyyy年MM月",
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self._selectedDate = selectedDate
        self.dateRange = dateRange
        self.displayFormat = displayFormat
        self.onTap = onTap
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)

                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()
            }

            Button(action: onTap) {
                HStack {
                    Text(formattedDate)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(color.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(20)
        .cardStyle(color: color)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = displayFormat
        return formatter.string(from: selectedDate)
    }
}

// MARK: - 🧭 Navigation Components

// MARK: - Navigation Bar Component
struct CustomNavigationBar: View {
    let title: String
    let subtitle: String?
    let leadingAction: NavigationAction?
    let trailingActions: [NavigationAction]
    let style: NavigationStyle

    struct NavigationAction {
        let icon: String
        let title: String?
        let color: Color
        let action: () -> Void

        init(icon: String, title: String? = nil, color: Color = .white, action: @escaping () -> Void) {
            self.icon = icon
            self.title = title
            self.color = color
            self.action = action
        }
    }

    enum NavigationStyle {
        case standard
        case large
        case transparent

        var titleFont: Font {
            switch self {
            case .standard: return .system(size: 18, weight: .semibold)
            case .large: return .system(size: 28, weight: .bold)
            case .transparent: return .system(size: 18, weight: .semibold)
            }
        }

        var backgroundColor: Color {
            switch self {
            case .standard: return Color.black
            case .large: return Color.black
            case .transparent: return Color.clear
            }
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                // Leading Action
                if let leadingAction = leadingAction {
                    Button(action: leadingAction.action) {
                        HStack(spacing: 6) {
                            Image(systemName: leadingAction.icon)
                                .font(.system(size: 16, weight: .medium))

                            if let title = leadingAction.title {
                                Text(title)
                                    .font(.system(size: 16, weight: .medium))
                            }
                        }
                        .foregroundColor(leadingAction.color)
                    }
                } else {
                    Spacer()
                        .frame(width: 44)
                }

                Spacer()

                // Title
                VStack(spacing: 2) {
                    Text(title)
                        .font(style.titleFont)
                        .foregroundColor(.white)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                // Trailing Actions
                HStack(spacing: 8) {
                    ForEach(Array(trailingActions.enumerated()), id: \.offset) { index, action in
                        Button(action: action.action) {
                            HStack(spacing: 6) {
                                Image(systemName: action.icon)
                                    .font(.system(size: 16, weight: .medium))

                                if let title = action.title {
                                    Text(title)
                                        .font(.system(size: 16, weight: .medium))
                                }
                            }
                            .foregroundColor(action.color)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, style == .large ? 20 : 12)
            .background(style.backgroundColor)
        }
        .animation(.easeInOut(duration: 0.3), value: title)
    }
}

// MARK: - Tab Bar Component
struct CustomTabBar: View {
    @Binding var selectedTab: Tab
    let items: [TabItem]

    struct TabItem {
        let tab: Tab
        let icon: String
        let title: String
        let badge: Int?

        init(tab: Tab, icon: String, title: String, badge: Int? = nil) {
            self.tab = tab
            self.icon = icon
            self.title = title
            self.badge = badge
        }
    }

    var body: some View {
        HStack {
            ForEach(items, id: \.tab) { item in
                TabBarButton(
                    item: item,
                    isSelected: selectedTab == item.tab
                ) {
                    selectedTab = item.tab
                }
            }
        }
        .padding(.top, 5)
        .padding(.bottom, hasHomeIndicator() ? 8 : 12)
        .background(
            Rectangle()
                .fill(Color.black)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: -5)
        )
    }

    private func hasHomeIndicator() -> Bool {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return false
        }
        return window.safeAreaInsets.bottom > 0
    }
}

struct TabBarButton: View {
    let item: CustomTabBar.TabItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                ZStack {
                    Image(systemName: item.icon)
                        .font(.system(size: 16))
                        .foregroundColor(isSelected ? .white : .gray)
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3), value: isSelected)

                    // Badge
                    if let badge = item.badge, badge > 0 {
                        VStack {
                            HStack {
                                Spacer()
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        Text("\(badge)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            }
                            Spacer()
                        }
                        .offset(x: 8, y: -8)
                    }
                }

                Text(item.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .white : .gray)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .contentShape(Rectangle())
    }
}

// MARK: - Bottom Sheet Component
struct CustomBottomSheet<Content: View>: View {
    @Binding var isPresented: Bool
    let detent: PresentationDetent
    let dragIndicator: Bool
    let content: () -> Content

    init(
        isPresented: Binding<Bool>,
        detent: PresentationDetent = .medium,
        dragIndicator: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isPresented = isPresented
        self.detent = detent
        self.dragIndicator = dragIndicator
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            if dragIndicator {
                // Handle bar
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
            }

            content()
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: -5)
                .ignoresSafeArea(.all)
        )
        .ignoresSafeArea(.all)
    }
}

// MARK: - Action Sheet Component
struct ActionSheetItem {
    let title: String
    let subtitle: String?
    let icon: String
    let color: Color
    let destructive: Bool
    let action: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        color: Color = .blue,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.destructive = destructive
        self.action = action
    }
}

struct CustomActionSheet: View {
    let title: String
    let items: [ActionSheetItem]
    @Binding var isPresented: Bool

    var body: some View {
        CustomBottomSheet(isPresented: $isPresented, detent: .fraction(0.6)) {
            VStack(spacing: 20) {
                // Title
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.bottom, 8)

                // Action Items
                VStack(spacing: 16) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        ActionSheetRow(item: item) {
                            item.action()
                            isPresented = false
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

struct ActionSheetRow: View {
    let item: ActionSheetItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(item.color.opacity(0.1))
                        .frame(width: 50, height: 50)

                    Image(systemName: item.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(item.destructive ? .red : item.color)
                }

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(item.destructive ? .red : .primary)

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6).opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(item.color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
