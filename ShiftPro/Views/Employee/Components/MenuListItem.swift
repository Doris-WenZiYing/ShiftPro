//
//  MenuListItem.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/11.
//

import SwiftUI

struct MenuListItem: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // 圖標
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 24, height: 24)

                // 文字內容
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(
                Rectangle()
                    .fill(isPressed ? Color.white.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

#Preview {
    MenuListItem(icon: "", title: "", action: {})
}
