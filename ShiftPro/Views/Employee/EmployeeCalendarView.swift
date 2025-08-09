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
    @State private var isActionSheetPresented = false
    @State private var selectedAction: ShiftAction?
    @State private var isDatePickerPresented = false
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())

    // Calendar tracking
    @State private var visibleMonth: String = ""
    @State private var isCalendarReady = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.isSubmissionMode {
                submissionModeView()
                    .transition(.move(edge: .bottom))
            } else {
                normalModeView()
            }

            // Navigation bars
            if !viewModel.isSubmissionMode {
                topNavigationBar()
                bottomActionBar()
            }

            // Toast notifications
            ToastView(
                message: viewModel.toastMessage,
                type: viewModel.toastType,
                isShowing: $viewModel.isToastShowing
            )
            .zIndex(5)
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isSubmissionMode)
        .sheet(isPresented: $isActionSheetPresented) {
            actionSheet()
        }
        .sheet(isPresented: $isDatePickerPresented) {
            datePickerSheet()
        }
        .onAppear {
            setupCalendar()
        }
        .onChange(of: selectedAction) { _, action in
            handleActionChange(action)
        }
        .onChange(of: viewModel.currentVacationMode) { _, newMode in
            menuState.currentVacationMode = newMode
        }
    }

    // MARK: - Normal Mode View
    private func normalModeView() -> some View {
        FullPageScrollCalendarView(controller) { month in
            UnifiedCalendarView(
                month: month,
                onCellTap: { date in
                    handleCellTap(date: date, month: month)
                },
                cellStateProvider: { date in
                    getCellState(for: date, in: month)
                },
                monthTitleConfig: getMonthTitleLoadingState(),
                statusInfo: getStatusInfo(for: month),
                onDatePickerTap: {
                    selectedMonth = month.month
                    selectedYear = month.year
                    isDatePickerPresented = true
                }
            )
            .onAppear {
                handleVisibleMonthChange(month: month)
            }
        }
    }

    // MARK: - Submission Mode View
    private func submissionModeView() -> some View {
        VStack(spacing: 0) {
            // Header
            SectionHeader(
                title: "排休設定",
                subtitle: getCurrentMonthName(),
                icon: "calendar.badge.checkmark",
                iconColor: .blue,
                actionTitle: "取消",
                action: {
                    viewModel.exitEditMode()
                }
            )

            ScrollView {
                VStack(spacing: 20) {
                    // Statistics Card
                    statisticsCard()

                    // Calendar
                    calendarCard()

                    // Action Buttons
                    submissionActionButtons()
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Statistics Card
    private func statisticsCard() -> some View {
        InfoCard(
            title: "排休統計",
            icon: "chart.bar.fill",
            iconColor: .green
        ) {
            CalendarStatistics(stats: [
                .init(title: "月上限", value: "\(viewModel.availableVacationDays)", color: .blue, icon: "calendar"),
                .init(title: "週上限", value: "\(viewModel.weeklyVacationLimit)", color: .green, icon: "calendar.day.timeline.left"),
                .init(title: "已選擇", value: "\(viewModel.vacationData.selectedDates.count)", color: .orange, icon: "checkmark.circle")
            ])
        }
    }

    // MARK: - Calendar Card
    private func calendarCard() -> some View {
        InfoCard(
            title: "選擇排休日期",
            icon: "calendar.circle.fill",
            iconColor: .blue
        ) {
            VStack(spacing: 16) {
                WeekdayHeaders()

                // Simple calendar grid for current month
                let currentMonth = getCurrentCalendarMonth()
                CalendarGrid(
                    month: currentMonth,
                    cellHeight: 50,
                    onCellTap: { date in
                        if date.isCurrentMonth == true {
                            let dateString = viewModel.dateToString(date)
                            viewModel.toggleVacationDate(dateString, showToast: false)
                        }
                    },
                    cellStateProvider: { date in
                        if date.isCurrentMonth != true {
                            return .disabled
                        }

                        let dateString = viewModel.dateToString(date)
                        if viewModel.vacationData.selectedDates.contains(dateString) {
                            return .vacationSelected
                        }

                        return viewModel.canSelect(day: date.day) ? .normal : .disabled
                    }
                )
            }
        }
    }

    // MARK: - Submission Action Buttons
    private func submissionActionButtons() -> some View {
        VStack(spacing: 16) {
            PrimaryButton(
                title: "提交排休",
                icon: "paperplane.fill",
                isLoading: viewModel.isFirebaseLoading,
                isEnabled: !viewModel.vacationData.selectedDates.isEmpty
            ) {
                viewModel.submitVacation()
            }

            HStack(spacing: 12) {
                SecondaryButton(
                    title: "清除全部",
                    icon: "trash",
                    color: .red
                ) {
                    viewModel.clearAllVacationDataWithToast()
                }

                SecondaryButton(
                    title: "取消",
                    icon: "xmark",
                    color: .gray
                ) {
                    viewModel.exitEditMode()
                }
            }
        }
        .padding(.bottom, 30)
    }

    // MARK: - Navigation Bars
    private func topNavigationBar() -> some View {
        VStack {
            CustomNavigationBar(
                title: "",
                subtitle: nil,
                leadingAction: nil,
                trailingActions: [
                    .init(icon: "line.3.horizontal") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            menuState.isMenuPresented.toggle()
                        }
                    }
                ],
                style: .transparent
            )

            Spacer()
        }
    }

    private func bottomActionBar() -> some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                CalendarActionBar(
                    mode: getActionBarMode(),
                    isEnabled: canPerformAction(),
                    onPrimaryAction: {
                        handlePrimaryAction()
                    },
                    onSecondaryAction: viewModel.isVacationEditMode ? {
                        viewModel.exitEditMode()
                    } : nil,
                    onTertiaryAction: viewModel.isVacationEditMode ? {
                        viewModel.clearAllVacationData()
                    } : nil
                )
            }
        }
    }

    // MARK: - Action Sheet
    private func actionSheet() -> some View {
        CustomActionSheet(
            title: "選擇動作",
            items: [
                ActionSheetItem(
                    title: "編輯排休日",
                    subtitle: "選擇需要排休的日期",
                    icon: "calendar.badge.minus",
                    color: .blue
                ) {
                    viewModel.handleVacationAction(.editVacation)
                },
                ActionSheetItem(
                    title: "清除排休日",
                    subtitle: "重置所有排休資料",
                    icon: "trash.circle",
                    color: .red,
                    destructive: true
                ) {
                    viewModel.handleVacationAction(.clearVacation)
                }
            ],
            isPresented: $isActionSheetPresented
        )
    }

    // MARK: - Date Picker Sheet
    private func datePickerSheet() -> some View {
        EnhancedDatePickerSheet(
            selectedYear: $selectedYear,
            selectedMonth: $selectedMonth,
            isPresented: $isDatePickerPresented,
            controller: controller
        )
        .onDisappear {
            let monthKey = String(format: "%04d-%02d", selectedYear, selectedMonth)
            viewModel.updateDisplayMonth(year: selectedYear, month: selectedMonth)
            visibleMonth = monthKey
        }
    }

    // MARK: - Helper Methods
    private func setupCalendar() {
        guard !isCalendarReady else { return }

        let now = Date()
        let year = Calendar.current.component(.year, from: now)
        let month = Calendar.current.component(.month, from: now)
        let monthKey = String(format: "%04d-%02d", year, month)

        visibleMonth = monthKey
        viewModel.updateDisplayMonth(year: year, month: month)
        isCalendarReady = true
    }

    private func handleVisibleMonthChange(month: CalendarMonth) {
        let monthKey = String(format: "%04d-%02d", month.year, month.month)

        guard isCalendarReady else { return }
        guard monthKey != visibleMonth else { return }
        guard isValidMonth(month: month) else { return }

        visibleMonth = monthKey

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            viewModel.updateDisplayMonth(year: month.year, month: month.month)
        }
    }

    private func isValidMonth(month: CalendarMonth) -> Bool {
        let currentYear = Calendar.current.component(.year, from: Date())
        return month.year >= currentYear - 1 && month.year <= currentYear + 2
    }

    private func handleCellTap(date: CalendarDate, month: CalendarMonth) {
        let monthKey = String(format: "%04d-%02d", month.year, month.month)

        if viewModel.isVacationEditMode &&
           date.isCurrentMonth == true &&
           monthKey == viewModel.currentDisplayMonth {
            let dateString = viewModel.dateToString(date)
            if viewModel.canSelect(day: date.day) {
                viewModel.toggleVacationDate(dateString)
            }
        } else {
            controller.selectDate(date)
        }
    }

    private func getCellState(for date: CalendarDate, in month: CalendarMonth) -> CalendarCell.CellState {
        if controller.isDateSelected(date) {
            return .selected
        }

        if date.isToday {
            return .today
        }

        let monthKey = String(format: "%04d-%02d", month.year, month.month)
        let dateString = viewModel.dateToString(date)

        if monthKey == viewModel.currentDisplayMonth &&
           date.isCurrentMonth == true &&
           viewModel.vacationData.selectedDates.contains(dateString) {
            return .vacationSelected
        }

        if date.isCurrentMonth != true {
            return .disabled
        }

        return viewModel.canSelect(day: date.day) ? .normal : .disabled
    }

    private func getMonthTitleLoadingState() -> CalendarMonthTitle.LoadingState {
        if viewModel.isFirebaseLoading {
            return .loading("處理中")
        }
        return .idle
    }

    private func getStatusInfo(for month: CalendarMonth) -> [CalendarMonthTitle.StatusInfo] {
        let monthKey = String(format: "%04d-%02d", month.year, month.month)

        guard monthKey == viewModel.currentDisplayMonth else {
            return [
                .init(
                    title: "老闆設定",
                    status: viewModel.isUsingBossSettings ? "已發佈" : "等待中",
                    color: viewModel.isUsingBossSettings ? .green : .gray,
                    icon: viewModel.isUsingBossSettings ? "checkmark.circle.fill" : "clock.circle"
                )
            ]
        }

        var statusInfo: [CalendarMonthTitle.StatusInfo] = []

        // Vacation status
        let vacationStatus: String
        let vacationColor: Color
        let vacationIcon: String

        if viewModel.isReallySubmitted {
            vacationStatus = "已提交"
            vacationColor = .green
            vacationIcon = "checkmark.circle.fill"
        } else if !viewModel.vacationData.selectedDates.isEmpty {
            vacationStatus = "未提交"
            vacationColor = .orange
            vacationIcon = "clock.circle.fill"
        } else if viewModel.isUsingBossSettings {
            vacationStatus = "可排休"
            vacationColor = .blue
            vacationIcon = "calendar.badge.checkmark"
        } else {
            vacationStatus = "等待發佈"
            vacationColor = .gray
            vacationIcon = "clock.circle"
        }

        statusInfo.append(.init(
            title: "排休狀態",
            status: vacationStatus,
            color: vacationColor,
            icon: vacationIcon
        ))

        // Boss settings status
        statusInfo.append(.init(
            title: "老闆設定",
            status: viewModel.isUsingBossSettings ? "已發佈" : "等待中",
            color: viewModel.isUsingBossSettings ? .green : .gray,
            icon: viewModel.isUsingBossSettings ? "checkmark.circle.fill" : "clock.circle"
        ))

        return statusInfo
    }

    private func getActionBarMode() -> CalendarActionBar.ActionBarMode {
        if viewModel.isVacationEditMode {
            return .edit(hasSelection: !viewModel.vacationData.selectedDates.isEmpty)
        } else if viewModel.isReallySubmitted {
            return .view
        } else if !viewModel.canEditVacation {
            if !viewModel.canEditMonth() {
                return .disabled(reason: "無法編輯過去月份")
            } else {
                return .disabled(reason: "等待老闆發佈設定")
            }
        } else {
            return .submit
        }
    }

    private func canPerformAction() -> Bool {
        if viewModel.isVacationEditMode {
            return true
        }
        return viewModel.canEditVacation
    }

    private func handlePrimaryAction() {
        if viewModel.canEditVacation {
            viewModel.handleVacationAction(.editVacation)
        } else if !viewModel.canEditMonth() {
            viewModel.showToast("無法編輯過去月份", type: .error)
        } else {
            isActionSheetPresented = true
        }
    }

    private func handleActionChange(_ action: ShiftAction?) {
        if let action = action {
            viewModel.handleVacationAction(action)
            selectedAction = nil
        }
    }

    private func getCurrentMonthName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"

        if let date = formatter.date(from: viewModel.currentDisplayMonth) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy年MM月"
            return displayFormatter.string(from: date)
        }

        return viewModel.currentDisplayMonth
    }

    private func getCurrentCalendarMonth() -> CalendarMonth {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"

        if let date = formatter.date(from: viewModel.currentDisplayMonth) {
            let calendar = Calendar.current
            return CalendarMonth(
                year: calendar.component(.year, from: date),
                month: calendar.component(.month, from: date)
            )
        }

        return CalendarMonth.current
    }
}

#Preview {
    EmployeeCalendarView(menuState: MenuState())
}
