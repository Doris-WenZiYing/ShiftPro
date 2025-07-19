//
//  SchedulePublishView.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/11.
//

import SwiftUI

struct SchedulePublishView: View {
    @Binding var isPresented: Bool
    @State private var scheduleMode: ScheduleMode = .auto
    @State private var selectedDates: Set<String> = []
    @State private var currentDate = Date()

    let onPublish: (ScheduleData) -> Void

    private let calendar = Calendar.current
    private var currentMonthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: currentDate)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    headerSection()

                    // Mode Selection
                    modeSelectionCard()

                    // Calendar View
                    calendarSection()

                    // Bottom Action
                    publishButton()
                }
            }
            .navigationTitle("發佈班表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            if scheduleMode == .auto {
                generateAutoSchedule()
            }
        }
    }

    // MARK: - Header Section
    private func headerSection() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40))
                .foregroundColor(.green)

            Text("排班設定")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text(currentMonthName)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    private var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月"
        return formatter.string(from: currentDate)
    }

    // MARK: - Mode Selection Card
    private func modeSelectionCard() -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("排班模式")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }

            HStack(spacing: 16) {
                // Auto Mode
                modeButton(
                    mode: .auto,
                    title: "自動排班",
                    icon: "wand.and.stars",
                    description: "系統自動分配"
                )

                // Manual Mode
                modeButton(
                    mode: .manual,
                    title: "自定義排班",
                    icon: "hand.point.up",
                    description: "手動選擇日期"
                )
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .padding(.horizontal, 24)
    }

    private func modeButton(mode: ScheduleMode, title: String, icon: String, description: String) -> some View {
        Button(action: {
            scheduleMode = mode
            if mode == .auto {
                generateAutoSchedule()
            } else {
                selectedDates.removeAll()
            }
        }) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(scheduleMode == mode ? .green : .gray)

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(scheduleMode == mode ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(scheduleMode == mode ? Color.green : Color.gray.opacity(0.3), lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Calendar Section
    private func calendarSection() -> some View {
        VStack(spacing: 16) {
            // Month Header
            monthHeader()

            // Weekday Headers
            weekdayHeaders()

            // Calendar Grid
            calendarGrid()

            // Info
            scheduleInfo()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private func monthHeader() -> some View {
        HStack {
            Button(action: {
                currentDate = calendar.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
                if scheduleMode == .auto {
                    generateAutoSchedule()
                }
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .font(.system(size: 18, weight: .medium))
            }

            Spacer()

            Text(currentMonthName)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Button(action: {
                currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
                if scheduleMode == .auto {
                    generateAutoSchedule()
                }
            }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.white)
                    .font(.system(size: 18, weight: .medium))
            }
        }
    }

    private func weekdayHeaders() -> some View {
        HStack {
            ForEach(0..<7, id: \.self) { dayIndex in
                Text(DateFormatter().shortWeekdaySymbols[dayIndex].prefix(1))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .textCase(.uppercase)
            }
        }
    }

    private func calendarGrid() -> some View {
        let days = getDaysInMonth()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(days) { day in
                calendarCell(day: day)
            }
        }
    }

    private func calendarCell(day: CalendarDay) -> some View {
        let dayString = String(format: "%@-%02d", currentMonthString, calendar.component(.day, from: day.date))
        let isSelected = selectedDates.contains(dayString)
        let isCurrentMonth = day.isWithinDisplayedMonth

        return Button(action: {
            if scheduleMode == .manual && isCurrentMonth {
                if isSelected {
                    selectedDates.remove(dayString)
                } else {
                    selectedDates.insert(dayString)
                }
            }
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.green : Color.gray.opacity(0.1))
                    .frame(height: 50)

                if isCurrentMonth {
                    VStack(spacing: 2) {
                        Text("\(calendar.component(.day, from: day.date))")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isSelected ? .white : .white)

                        if isSelected {
                            Text("班")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.green.opacity(0.8))
                                .cornerRadius(2)
                        }
                    }
                } else {
                    Text("\(calendar.component(.day, from: day.date))")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray.opacity(0.4))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(scheduleMode == .auto || !isCurrentMonth)
    }

    private func scheduleInfo() -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.green)

                Text("已選擇 \(selectedDates.count) 個工作日")
                    .font(.system(size: 16))
                    .foregroundColor(.white)

                Spacer()
            }

            if scheduleMode == .auto {
                Text("系統已自動分配工作日程")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            } else {
                Text("點擊日期來選擇工作日")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(16)
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Publish Button
    private func publishButton() -> some View {
        Button(action: {
            let scheduleData = ScheduleData(
                mode: scheduleMode,
                selectedDates: selectedDates,
                month: currentMonthString
            )
            onPublish(scheduleData)
            isPresented = false
        }) {
            HStack(spacing: 12) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18, weight: .semibold))

                Text("發佈班表")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.green,
                        Color.green.opacity(0.8)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: .green.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 30)
        .disabled(selectedDates.isEmpty)
    }

    // MARK: - Helper Methods
    private func generateAutoSchedule() {
        selectedDates.removeAll()
        let days = getDaysInMonth()

        // 自動選擇工作日（週一到週五）
        for day in days {
            if day.isWithinDisplayedMonth {
                let weekday = calendar.component(.weekday, from: day.date)
                // 週一到週五 (weekday: 2-6)
                if weekday >= 2 && weekday <= 6 {
                    let dayString = String(format: "%@-%02d", currentMonthString, calendar.component(.day, from: day.date))
                    selectedDates.insert(dayString)
                }
            }
        }
    }

    private func getDaysInMonth() -> [CalendarDay] {
        let year = calendar.component(.year, from: currentDate)
        let month = calendar.component(.month, from: currentDate)

        guard let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
            return []
        }

        let range = calendar.range(of: .day, in: .month, for: firstDay)!
        let daysInMonth = range.count
        let startingWeekday = calendar.component(.weekday, from: firstDay) - 1

        var days: [CalendarDay] = []

        // Previous month days
        if startingWeekday > 0 {
            let prevMonth = calendar.date(byAdding: .month, value: -1, to: firstDay)!
            let prevRange = calendar.range(of: .day, in: .month, for: prevMonth)!
            let prevDaysCount = prevRange.count

            for day in (prevDaysCount - startingWeekday + 1)...prevDaysCount {
                if let date = calendar.date(from: DateComponents(year: calendar.component(.year, from: prevMonth), month: calendar.component(.month, from: prevMonth), day: day)) {
                    days.append(CalendarDay(date: date, isWithinDisplayedMonth: false))
                }
            }
        }

        // Current month days
        for day in 1...daysInMonth {
            if let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) {
                days.append(CalendarDay(date: date, isWithinDisplayedMonth: true))
            }
        }

        // Next month days - 只添加需要的數量來填滿42格
        let totalCellsNeeded = 42
        let remainingCells = totalCellsNeeded - days.count
        if remainingCells > 0 {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstDay)!
            for day in 1...remainingCells {
                if let date = calendar.date(from: DateComponents(year: calendar.component(.year, from: nextMonth), month: calendar.component(.month, from: nextMonth), day: day)) {
                    days.append(CalendarDay(date: date, isWithinDisplayedMonth: false))
                }
            }
        }

        return days
    }
}

#Preview {
    SchedulePublishView(
        isPresented: Binding.constant(true),
        onPublish: { scheduleData in
            print("Published: \(scheduleData.displayText)")
        }
    )
}
