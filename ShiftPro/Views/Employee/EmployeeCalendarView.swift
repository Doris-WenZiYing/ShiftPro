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
                viewModel.updateDisplayMonth(
                    year: selectedYear,
                    month: selectedMonth
                )
            }
        }
        .onAppear {
            let now = Date()
            let y = Calendar.current.component(.year, from: now)
            let m = Calendar.current.component(.month, from: now)
            viewModel.updateDisplayMonth(year: y, month: m)
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
            .onAppear {
                viewModel.updateDisplayMonth(year: month.year, month: month.month)
            }
            .onChange(of: month.year) { _, newYear in
                viewModel.updateDisplayMonth(year: newYear, month: month.month)
            }
            .onChange(of: month.month) { _, newMonth in
                viewModel.updateDisplayMonth(year: month.year, month: newMonth)
            }
        }
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

                        Text("\(month.year.yearString)年")
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

            // 員工端狀態顯示
            let currentDisplayMonth = String(format: "%04d-%02d", month.year, month.month)
            if currentDisplayMonth == viewModel.currentDisplayMonth {
                HStack(spacing: 12) {
                    // 排休狀態
                    statusBadge(
                        title: "排休狀態",
                        status: viewModel.vacationData.isSubmitted ? "已提交" : "未提交",
                        color: viewModel.vacationData.isSubmitted ? .green : .orange,
                        icon: viewModel.vacationData.isSubmitted ? "checkmark.circle.fill" : "clock.circle.fill"
                    )

                    // 同步狀態
                    statusBadge(
                        title: "同步狀態",
                        status: viewModel.isUsingBossSettings ? "已同步" : "等待中",
                        color: viewModel.isUsingBossSettings ? .green : .gray,
                        icon: viewModel.isUsingBossSettings ? "cloud.fill" : "cloud"
                    )
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
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
                calendarCell(date: dates[index], cellHeight: cellHeight)
            }
        }
        .background(Color.black)
        .padding(.horizontal, 8)
        .drawingGroup()
    }

    // MARK: - Calendar Cell
    private func calendarCell(date: CalendarDate, cellHeight: CGFloat) -> some View {
        let isSelected = controller.isDateSelected(date)
        let ds = viewModel.dateToString(date)
        let isVacationSelected = viewModel.vacationData.selectedDates.contains(ds)

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
            if viewModel.isVacationEditMode && date.isCurrentMonth == true {
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
                Spacer()
                Button {
                    menuState.isMenuPresented.toggle()
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
}無法編輯過去月份", type: .error)
                        }
                    } label: {
                        Text(viewModel.isFutureMonth() ? "預約排休" : "編輯排休")
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .background(viewModel.isFutureMonth() ? Color.blue : Color.white)
                            .foregroundColor(viewModel.isFutureMonth() ? .white : .black)
                            .cornerRadius(20)
                    }
                    .padding(.trailing, 24)
                }
            }
            .padding(.bottom, 30)
        }
    }
}

#Preview {
    EmployeeCalendarView(menuState: MenuState())
}
