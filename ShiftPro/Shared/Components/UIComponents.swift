//
//  UIComponents.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/8/8.
//

import SwiftUI

// MARK: - 🎨 Design System Components

// MARK: - Buttons
struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let isLoading: Bool
    let isEnabled: Bool

    init(
        title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                }

                Text(title)
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        isEnabled ? Color.blue : Color.gray,
                        isEnabled ? Color.blue.opacity(0.8) : Color.gray.opacity(0.8)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(
                color: isEnabled ? Color.blue.opacity(0.4) : Color.clear,
                radius: 12,
                x: 0,
                y: 6
            )
        }
        .disabled(!isEnabled || isLoading)
        .scaleEffect(isEnabled ? 1.0 : 0.95)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

struct SecondaryButton: View {
    let title: String
    let icon: String?
    let color: Color
    let action: () -> Void

    init(title: String, icon: String? = nil, color: Color = .blue, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                }

                Text(title)
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FloatingActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void

    init(icon: String, color: Color = .blue, action: @escaping () -> Void) {
        self.icon = icon
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [color, color.opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: color.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: color)
    }
}

// MARK: - Cards
struct InfoCard: View {
    let title: String
    let icon: String
    let iconColor: Color
    let content: AnyView

    init<Content: View>(
        title: String,
        icon: String,
        iconColor: Color = .blue,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = AnyView(content())
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)

                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()
            }

            content
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(iconColor.opacity(0.1), lineWidth: 1)
        )
    }
}

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

// MARK: - Input Fields
struct CustomTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let isSecure: Bool

    init(
        title: String,
        placeholder: String? = nil,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default,
        isSecure: Bool = false
    ) {
        self.title = title
        self.placeholder = placeholder ?? title
        self._text = text
        self.keyboardType = keyboardType
        self.isSecure = isSecure
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .keyboardType(keyboardType)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            .foregroundColor(.white)
        }
    }
}

// MARK: - Loading States
struct LoadingView: View {
    let message: String
    let size: CGFloat

    init(message: String = "載入中...", size: CGFloat = 1.2) {
        self.message = message
        self.size = size
    }

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(size)

            Text(message)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(24)
        .background(Color.black.opacity(0.8))
        .cornerRadius(16)
    }
}

struct LoadingOverlay: View {
    let message: String

    init(message: String = "處理中...") {
        self.message = message
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            LoadingView(message: message)
        }
    }
}

// MARK: - Headers
struct SectionHeader: View {
    let title: String
    let subtitle: String?
    let icon: String
    let iconColor: Color
    let action: (() -> Void)?
    let actionTitle: String?

    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        iconColor: Color = .blue,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.action = action
        self.actionTitle = actionTitle
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 12) {
                        Image(systemName: icon)
                            .font(.system(size: 20))
                            .foregroundColor(iconColor)

                        Text(title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                if let action = action, let actionTitle = actionTitle {
                    SecondaryButton(title: actionTitle, color: iconColor, action: action)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 45)
        .padding(.bottom, 16)
    }
}

// MARK: - Lists
struct MenuRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let color: Color
    let action: () -> Void
    let showChevron: Bool

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        color: Color = .blue,
        showChevron: Bool = true,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.color = color
        self.showChevron = showChevron
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Animations
struct ShakeAnimation: AnimatableModifier {
    var shakes: CGFloat = 0

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func body(content: Content) -> some View {
        content
            .offset(x: sin(shakes * .pi * 2) * 5)
    }
}

struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Extensions
extension View {
    func shake(with shakes: CGFloat) -> some View {
        self.modifier(ShakeAnimation(shakes: shakes))
    }

    func pulse() -> some View {
        self.modifier(PulseAnimation())
    }

    func cardStyle(color: Color = .blue) -> some View {
        self
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.1), lineWidth: 1)
            )
    }
}
