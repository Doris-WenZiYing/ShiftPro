//
//  TabBarView.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/8.
//

import SwiftUI

struct TabBarView: View {
    @Binding var selectedTab: Tab

    var body: some View {
        HStack {
            tabItem("calendar", label: "Calendar", tab: .calendar)
            tabItem("chart.bar", label: "Reports", tab: .reports)
            tabItem("doc.text", label: "Templates", tab: .templates)
            tabItem("line.3.horizontal", label: "More", tab: .more)
        }
        .padding(.top, 5)
        .padding(.bottom, hasHomeIndicator() ? 8 : 12)
        .background(Color.black)
    }

    func tabItem(_ icon: String, label: String, tab: Tab) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(selectedTab == tab ? .white : .gray)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(selectedTab == tab ? .white : .gray)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .onTapGesture {
            selectedTab = tab
        }
    }

    private func hasHomeIndicator() -> Bool {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return false
        }
        return window.safeAreaInsets.bottom > 0
    }
}

#Preview {
    TabBarView(selectedTab: .constant(.calendar))
}
