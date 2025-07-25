//
//  EmployeeCalendarView.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/10.
//

import SwiftUI

struct EmployeeCalendarView: View {
    // MARK: - Dependencies
    @StateObject private var viewModel = EmployeeCalendarViewModel()
    @ObservedObject private var controller = CalendarController(orientation: .vertical)
    @ObservedObject var menuState: MenuState

    // MARK: - UI State
    @State private var isSheetPresented = false
    @State private var selectedAction: ShiftAction?
    @State private var isDatePickerPresented = false
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())

    // 🚨 新增：只追蹤用戶實際看到的月份
    @State private var visibleMonth: String = ""
    @State private var isCalendarReady = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            normalModeCalendarView()

            topBar()
            bottomBar()

            if viewModel.isToastShowing {
                ToastView(
                    message: viewModel.toastMessage,
                    type: viewModel.toastType,
                    isShowing: $viewModel.isToastShowing
                )
                .zIndex(1)
            }
        }
        .sheet(isPresented: $isSheetPresented) {
            BottomSheetView(
                isPresented: $isSheetPresented,
                selectedAction: $selectedAction
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
            .onChange(of: selectedAction) {_, newAction in
                if let action = newAction {
                    viewModel.handleVacationAction(action)
                    selectedAction = nil
                }
            }
        }
        .sheet(isPresented: $isDatePickerPresented) {
            EnhancedDatePickerSheet(
                selectedYear: $selectedYear,
                selectedMonth: $selectedMonth,
                isPresented: $isDatePickerPresented,
                controller: controller
            )
            .onDisappear {
                let monthKey = String(format: "%04d-%02d", selectedYear, selectedMonth)
                print("📅 用戶手動選擇月份: \(monthKey)")
                viewModel.safeUpdateDisplayMonth(year: selectedYear, month: selectedMonth)
                visibleMonth = monthKey
            }
        }
        .onAppear {
            // 只初始化一次
            if !isCalendarReady {
                let now = Date()
                let y = Calendar.current.component(.year, from: now)
                let m = Calendar.current.component(.month, from: now)
                let monthKey = String(format: "%04d-%02d", y, m)

                visibleMonth = monthKey
                viewModel.safeUpdateDisplayMonth(year: y, month: m)
                isCalendarReady = true

                print("📱 初始化日曆視圖: \(monthKey)")
            }
        }
        .onChange(of: viewModel.currentVacationMode) {
            menuState.currentVacationMode = viewModel.currentVacationMode
        }
        .onChange(of: menuState.currentVacationMode) {
            viewModel.currentVacationMode = menuState.currentVacationMode
        }
    }

    // MARK: - Calendar View
    private func normalModeCalendarView() -> some View {
        FullPageScrollCalendarView(controller) { month in
            VStack(spacing: 0) {
                monthTitleView(month: month)
                weekdayHeadersView()

                GeometryReader { geometry in
                    let availableHeight = geometry.size.height
                    let cellHeight = max((availableHeight - 20) / 6, 70)

                    calendarGridView(month: month, cellHeight: cellHeight)
                }
            }
            // 🚨 關鍵修復：只監聽真正顯示在屏幕上的月份
            .onAppear {
                handleVisibleMonthChange(month: month)
            }
            // 🚨 移除 onChange 監聽器，因為它們會在日曆庫初始化時大量觸發
        }
    }

    // 🚨 新增：只處理真正可見的月份變化
    private func handleVisibleMonthChange(month: CalendarMonth) {
        let monthKey = String(format: "%04d-%02d", month.year, month.month)

        // 只處理用戶真正可見的月份
        guard isCalendarReady else {
            return
        }

        // 防止處理相同月份
        guard monthKey != visibleMonth else {
            return
        }

        // 只處理合理的年份範圍（當前年份 ±1）
        let currentYear = Calendar.current.component(.year, from: Date())
        guard abs(month.year - currentYear) <= 1 else {
            print("🚫 忽略不合理年份: \(month.year)")
            return
        }

        print("📅 用戶切換到可見月份: \(visibleMonth) -> \(monthKey)")
        visibleMonth = monthKey
        viewModel.safeUpdateDisplayMonth(year: month.year, month: month.month)
    }

    // MARK: - Month Title View
    private func monthTitleView(month: CalendarMonth) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: {
                    selectedMonth = month.month
                    selectedYear = month.year
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isDatePickerPresented = true
                    }
                }) {
                    HStack(spacing: 8) {
                        Text(month.monthName)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text("\(month.yearString)年")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))

                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                if viewModel.isVacationEditMode {
                    Text("編輯中")
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(12)
                        .foregroundColor(.orange)
                }
            }

            // 狀態顯示
            HStack(spacing: 12) {
                statusBadge(
                    title: "排休狀態",
                    status: getVacationStatus(for: month),
                    color: getVacationStatusColor(for: month),
                    icon: getVacationStatusIcon(for: month)
                )

                statusBadge(
                    title: "同步狀態",
                    status: viewModel.isUsingBossSettings ? "已同步" : "等待中",
                    color: viewModel.isUsingBossSettings ? .green : .gray,
                    icon: viewModel.isUsingBossSettings ? "cloud.fill" : "cloud"
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    // MARK: - Status Helper Methods
    private func getVacationStatus(for month: CalendarMonth) -> String {
        let monthKey = String(format: "%04d-%02d", month.year, month.month)

        if monthKey == viewModel.currentDisplayMonth {
            if viewModel.vacationData.isSubmitted {
                return "已提交"
            } else if !viewModel.vacationData.selectedDates.isEmpty {
                return "未提交"
            } else if viewModel.isUsingBossSettings {
                return "可排休"
            } else {
                return "等待發佈"
            }
        } else {
            return "未設定"
        }
    }

    private func getVacationStatusColor(for month: CalendarMonth) -> Color {
        let monthKey = String(format: "%04d-%02d", month.year, month.month)

        if monthKey == viewModel.currentDisplayMonth {
            if viewModel.vacationData.isSubmitted {
                return .green
            } else if !viewModel.vacationData.selectedDates.isEmpty {
                return .orange
            } else if viewModel.isUsingBossSettings {
                return .blue
            } else {
                return .gray
            }
        } else {
            return .gray
        }
    }

    private func getVacationStatusIcon(for month: CalendarMonth) -> String {
        let monthKey = String(format: "%04d-%02d", month.year, month.month)

        if monthKey == viewModel.currentDisplayMonth {
            if viewModel.vacationData.isSubmitted {
                return "checkmark.circle.fill"
            } else if !viewModel.vacationData.selectedDates.isEmpty {
                return "clock.circle.fill"
            } else if viewModel.isUsingBossSettings {
                return "calendar.badge.checkmark"
            } else {
                return "clock.circle"
            }
        } else {
            return "calendar"
        }
    }

    private func statusBadge(title: String, status: String, color: Color, icon: String) -> some View {
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

    // MARK: - Weekday Headers
    private func weekdayHeadersView() -> some View {
        HStack(spacing: 1) {
            ForEach(0..<7, id: \.self) { i in
                Text(DateFormatter().shortWeekdaySymbols[i].prefix(1))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .textCase(.uppercase)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Calendar Grid
    private func calendarGridView(month: CalendarMonth, cellHeight: CGFloat) -> some View {
        let dates = month.getDaysInMonth(offset: 0)
        let gridItems = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

        return LazyVGrid(columns: gridItems, alignment: .center, spacing: 2) {
            ForEach(0..<42, id: \.self) { index in
                calendarCell(date: dates[index], cellHeight: cellHeight, month: month)
            }
        }
        .background(Color.black)
        .padding(.horizontal, 8)
        .drawingGroup()
    }

    // MARK: - Calendar Cell
    private func calendarCell(date: CalendarDate, cellHeight: CGFloat, month: CalendarMonth) -> some View {
        let isSelected = controller.isDateSelected(date)
        let ds = viewModel.dateToString(date)
        let monthKey = String(format: "%04d-%02d", month.year, month.month)

        let isVacationSelected = monthKey == viewModel.currentDisplayMonth &&
                                date.isCurrentMonth == true &&
                                viewModel.vacationData.selectedDates.contains(ds)

        return ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.05))
                .frame(height: cellHeight)

            if isSelected {
                Rectangle()
                    .fill(Color.white.opacity(date.isCurrentMonth == true ? 1.0 : 0.6))
                    .frame(height: cellHeight)
            }

            if isVacationSelected {
                Rectangle()
                    .fill(Color.orange.opacity(0.3))
                    .frame(height: cellHeight)
            }

            VStack(spacing: 4) {
                Text("\(date.day)")
                    .font(.system(size: min(cellHeight / 5, 14), weight: .medium))
                    .foregroundColor(
                        isSelected ? .black :
                        isVacationSelected ? .orange :
                        (date.isCurrentMonth == true ? .white : .gray.opacity(0.4))
                    )
                    .padding(.top, 8)

                if isVacationSelected {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                }

                Spacer()
            }
        }
        .onTapGesture {
            if viewModel.isVacationEditMode &&
               date.isCurrentMonth == true &&
               monthKey == viewModel.currentDisplayMonth {
                viewModel.toggleVacationDate(ds)
            } else {
                controller.selectDate(date)
            }
        }
    }

    // MARK: - Top Bar
    private func topBar() -> some View {
        VStack {
            HStack {
                // 緊急重置按鈕
                Button("重置") {
                    isCalendarReady = false
                    visibleMonth = ""
                    viewModel.emergencyReset()

                    // 延遲重新初始化
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isCalendarReady = true
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(.red)
                .opacity(0.6)

                Spacer()

                Button {
                    print("🔘 Menu button tapped")
                    withAnimation(.easeInOut(duration: 0.3)) {
                        menuState.isMenuPresented.toggle()
                    }
                    print("🔘 Menu state after toggle: \(menuState.isMenuPresented)")
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            Spacer()
        }
    }

    // MARK: - Bottom Bar
    private func bottomBar() -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                if viewModel.isVacationEditMode {
                    HStack(spacing: 12) {
                        Button("提交排休") {
                            viewModel.submitVacation()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)

                        Button("清除") {
                            viewModel.clearCurrentSelection()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding(.trailing, 24)
                } else {
                    Button {
                        if viewModel.canEditMonth() {
                            isSheetPresented = true
                        } else {
                            viewModel.showToast("無法編輯過去月份", type: .error)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.system(size: 14))

                            Text(viewModel.isFutureMonth() ? "預約排休" : "編輯排休")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    .padding(.trailing, 30)
                }
            }
            .padding(.bottom, 30)
        }
    }
}

#Preview {
    EmployeeCalendarView(menuState: MenuState())
}
