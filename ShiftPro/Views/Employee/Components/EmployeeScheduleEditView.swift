//
//  EmployeeScheduleEditView.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/29.
//

import SwiftUI

struct EmployeeScheduleEditView: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: EmployeeCalendarViewModel

    // 🔥 修復問題2：固定顯示當前月份，不允許切換
    private var currentDate: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.date(from: viewModel.currentDisplayMonth) ?? Date()
    }

    private let calendar = Calendar.current

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                // 🔥 修復問題1：添加 ScrollView 確保可以滾動
                ScrollView {
                    VStack(spacing: 0) {
                        headerSection()
                        limitsInfoCard()
                        calendarSection()
                        bottomActions()
                    }
                    .padding(.bottom, 30) // 確保底部有足夠空間
                }
            }
            .navigationTitle("排休設定")
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
    }

    // MARK: - Header Section
    private func headerSection() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 40))
                .foregroundColor(.blue)

            Text("排休設定")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            // 🔥 修復問題2：只顯示當前月份，不可切換
            Text(getCurrentMonthName())
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    // MARK: - Limits Info Card
    private func limitsInfoCard() -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("排休限制")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }

            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(viewModel.availableVacationDays)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.blue)
                    Text("月上限")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }

                if viewModel.currentVacationMode != .monthly {
                    VStack(spacing: 4) {
                        Text("\(viewModel.weeklyVacationLimit)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.green)
                        Text("週上限")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                VStack(spacing: 4) {
                    Text("\(viewModel.vacationData.selectedDates.count)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.orange)
                    Text("已選擇")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .padding(.horizontal, 24)
    }

    // MARK: - Calendar Section
    private func calendarSection() -> some View {
        VStack(spacing: 16) {
            // 🔥 修復問題2：移除月份切換功能，只顯示當前月份
            monthHeader()
            weekdayHeaders()
            calendarGrid()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private func monthHeader() -> some View {
        // 🔥 修復問題2：只顯示月份標題，不提供切換功能
        HStack {
            Spacer()
            Text(getCurrentMonthName())
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Spacer()
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
        let dayComponent = calendar.component(.day, from: day.date)
        let dayString = String(format: "%@-%02d", getCurrentMonthString(), dayComponent)
        let isSelected = viewModel.vacationData.selectedDates.contains(dayString)
        let isCurrentMonth = day.isWithinDisplayedMonth
        let canSelect = viewModel.canSelect(day: dayComponent)

        return Button(action: {
            // 🔥 修復問題7：選擇日期時不顯示 toast
            if isCurrentMonth {
                viewModel.toggleVacationDate(dayString, showToast: false)
            }
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.orange : Color.gray.opacity(0.1))
                    .frame(height: 50)

                if isCurrentMonth {
                    VStack(spacing: 2) {
                        Text("\(dayComponent)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isSelected ? .white : .white)

                        if isSelected {
                            Text("休")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.8))
                                .cornerRadius(2)
                        }
                    }
                } else {
                    Text("\(dayComponent)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray.opacity(0.4))
                }

                if !canSelect && isCurrentMonth {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.5))
                        .frame(height: 50)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!canSelect || !isCurrentMonth)
    }

    // MARK: - Bottom Actions
    private func bottomActions() -> some View {
        HStack(spacing: 16) {
            Button("清除全部") {
                // 🔥 修復問題1：清除時不顯示 toast，統一在 ViewModel 中處理
                viewModel.clearAllVacationDataWithToast()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(Color.red.opacity(0.2))
            .foregroundColor(.red)
            .cornerRadius(12)

            Button("提交排休") {
                viewModel.submitVacation()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(viewModel.vacationData.selectedDates.isEmpty ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .disabled(viewModel.vacationData.selectedDates.isEmpty || viewModel.isFirebaseLoading)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    // MARK: - Helper Methods
    private func getCurrentMonthName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月"
        return formatter.string(from: currentDate)
    }

    private func getCurrentMonthString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: currentDate)
    }

    // 🔥 修復問題1：正確生成日曆排列
    private func getDaysInMonth() -> [CalendarDay] {
        let year = calendar.component(.year, from: currentDate)
        let month = calendar.component(.month, from: currentDate)

        guard let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
            return []
        }

        let range = calendar.range(of: .day, in: .month, for: firstDay)!
        let daysInMonth = range.count

        // 🔥 修復：計算第一天是星期幾（0=周日, 1=周一, ..., 6=周六）
        let firstWeekday = calendar.component(.weekday, from: firstDay) - 1

        var days: [CalendarDay] = []

        // 🔥 修復：添加前面月份的空白天數
        if firstWeekday > 0 {
            let prevMonth = calendar.date(byAdding: .month, value: -1, to: firstDay)!
            let prevRange = calendar.range(of: .day, in: .month, for: prevMonth)!
            let prevDaysCount = prevRange.count

            // 從上個月的末尾開始填充
            for day in (prevDaysCount - firstWeekday + 1)...prevDaysCount {
                if let date = calendar.date(from: DateComponents(
                    year: calendar.component(.year, from: prevMonth),
                    month: calendar.component(.month, from: prevMonth),
                    day: day
                )) {
                    days.append(CalendarDay(date: date, isWithinDisplayedMonth: false))
                }
            }
        }

        // 🔥 修復：添加當前月份的所有天數
        for day in 1...daysInMonth {
            if let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) {
                days.append(CalendarDay(date: date, isWithinDisplayedMonth: true))
            }
        }

        // 🔥 修復：添加下個月的天數以填滿6週格子（42格）
        let totalCellsNeeded = 42
        let remainingCells = totalCellsNeeded - days.count
        if remainingCells > 0 {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstDay)!
            for day in 1...remainingCells {
                if let date = calendar.date(from: DateComponents(
                    year: calendar.component(.year, from: nextMonth),
                    month: calendar.component(.month, from: nextMonth),
                    day: day
                )) {
                    days.append(CalendarDay(date: date, isWithinDisplayedMonth: false))
                }
            }
        }

        return days
    }
}
#Preview {
    EmployeeScheduleEditView(isPresented: .constant(false), viewModel: EmployeeCalendarViewModel())
}
