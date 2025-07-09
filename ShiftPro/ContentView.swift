//
//  ContentView.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/8.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .calendar

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Main content area
                switch selectedTab {
                case .calendar:
                    EmployeeCalendarView()
                case .reports:
                    ReportsView()
                case .templates:
                    TemplatesView()
                case .more:
                    MoreView()
                }

                // Tab bar
                TabBarView(selectedTab: $selectedTab)
            }
        }
    }
}

// Placeholder views for other tabs
struct ReportsView: View {
    var body: some View {
        VStack {
            Text("Reports")
                .font(.largeTitle)
                .foregroundColor(.white)
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
}

struct TemplatesView: View {
    var body: some View {
        VStack {
            Text("Templates")
                .font(.largeTitle)
                .foregroundColor(.white)
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
}

struct MoreView: View {
    var body: some View {
        VStack {
            Text("More")
                .font(.largeTitle)
                .foregroundColor(.white)
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
}

#Preview {
    ContentView()
}
