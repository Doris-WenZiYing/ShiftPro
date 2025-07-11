//
//  EmployeeCalendarView.swift (完整週休邏輯版)
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/8.
//

import SwiftUI

struct EmployeeCalendarView: View {

    // MARK: - Properties
    @ObservedObject var controller: CalendarController = CalendarController(orientation: .vertical)
    @StateObject private var viewModel = EmployeeCalendarViewModel()
    @ObservedObject var menuState: MenuState // 接收外部的 menuState

    // MARK: - UI State
    @State private var isBottomSheetPresented = false
    @State private var selectedAction: ShiftAction?
    @State private var isDatePickerPresented = false
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Main Content
            if viewModel.isVacationEditMode {
                editModeCalendarView()
            } else {
                normalModeCalendarView()
            }

            // Floating Overlays
            if !viewModel.isVacationEditMode {
                topButtonsOverlay()
                    .zIndex(1) // 確保按鈕在 menu 上方
            }

            editButtonOverlay()
                .zIndex(2)

            // Toast
            ToastView(
                message: viewModel.toastMessage,
                type: viewModel.toastType,
                isShowing: $viewModel.isToastShowing
            )
            .zIndex(5)

            // 移除內部的 CustomMenuOverlay，現在由 ContentView 管理
        }
        .sheet(isPresented: $isBottomSheetPresented) {
            BottomSheetView(
                isPresented: $isBottomSheetPresented,
                selectedAction: $selectedAction
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $isDatePickerPresented) {
            EnhancedDatePickerSheet(
                selectedYear: $selectedYear,
                selectedMonth: $selectedMonth,
                isPresented: $isDatePickerPresented,
                controller: controller
            )
        }
        // VacationModeSelectionSheet 現在由 ContentView 管理
        .onChange(of: selectedAction) { _, action in
            handleSelectedAction(action)
        }
        .onAppear {
            // 同步 menuState 和 viewModel 的數據
            menuState.currentVacationMode = viewModel.currentVacationMode
        }
        .onChange(of: viewModel.currentVacationMode) { _, newMode in
            menuState.currentVacationMode = newMode
        }
        .onChange(of: menuState.currentVacationMode) { _, newMode in
            viewModel.currentVacationMode = newMode
        }
    }

    // MARK: - Normal Mode Calendar
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
        }
    }

    // MARK: - Edit Mode Calendar
    private func editModeCalendarView() -> some View {
        VStack(spacing: 0) {
            editModeHeader()

            GeometryReader { geometry in
                let availableHeight = geometry.size.height
                let cellHeight = max((availableHeight - 30) / 6, 80)

                VStack(spacing: 0) {
                    weekdayHeadersView()
                    editModeCalendarGrid(cellHeight: cellHeight)
                }
            }

            editModeBottomInfo()
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
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Text("\(String(month.year))年")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))

                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                if viewModel.isVacationEditMode {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        Text("編輯中")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(20)
                }
            }

            // Vacation Status Badge
            let currentDisplayMonth = String(format: "%04d-%02d", month.year, month.month)
            if currentDisplayMonth == viewModel.availableVacationMonth && !viewModel.isVacationEditMode {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.vacationData.isSubmitted ? "checkmark.circle.fill" : "calendar.badge.checkmark")
                        .font(.system(size: 12))
                        .foregroundColor(viewModel.vacationData.isSubmitted ? .green : .blue)

                    Text(viewModel.vacationData.isSubmitted ? "已排休" : "可排休")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(viewModel.vacationData.isSubmitted ? .green : .blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background((viewModel.vacationData.isSubmitted ? Color.green : Color.blue).opacity(0.2))
                .cornerRadius(16)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
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
        let dateString = viewModel.dateToString(date)
        let isSelected = controller.isDateSelected(date)
        let isVacationSelected = viewModel.vacationData.isDateSelected(dateString) && date.isCurrentMonth == true

        return ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.05))
                .frame(height: cellHeight)

            if isSelected && !viewModel.isVacationEditMode {
                Rectangle()
                    .fill(Color.white.opacity(date.isCurrentMonth == true ? 1.0 : 0.6))
                    .frame(height: cellHeight)
            }

            if isVacationSelected {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.orange.opacity(0.9),
                                Color.orange.opacity(0.7)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: cellHeight)
            }

            VStack(spacing: 4) {
                Text("\(date.day)")
                    .font(.system(size: min(cellHeight / 5, 14), weight: .medium))
                    .foregroundColor(
                        viewModel.textColor(
                            for: date,
                            isSelected: isSelected,
                            isVacationSelected: isVacationSelected
                        )
                    )
                    .padding(.top, 8)

                if isVacationSelected {
                    Text("休")
                        .font(.system(size: min(cellHeight / 8, 8), weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.orange)
                        .cornerRadius(3)
                }

                Spacer()
            }
        }
        .onTapGesture {
            controller.selectDate(date)
        }
    }

    // MARK: - Edit Mode Header
    private func editModeHeader() -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("排休編輯")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        Text(viewModel.formatMonthString(viewModel.availableVacationMonth))
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))

                        Text("•")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))

                        Text(viewModel.currentVacationMode.rawValue)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue.opacity(0.9))
                    }
                }

                Spacer()

                Button(action: viewModel.exitEditMode) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                        Text("完成")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(22)
                }
            }

            // Info Cards
            HStack(spacing: 12) {
                infoCard(
                    title: viewModel.vacationData.isSubmitted ? "已排休" : "可排休",
                    value: "\(viewModel.availableVacationDays) 天",
                    icon: viewModel.vacationData.isSubmitted ? "checkmark.circle.fill" : "calendar.badge.clock",
                    color: viewModel.vacationData.isSubmitted ? .green : .blue
                )

                infoCard(
                    title: "已選擇",
                    value: "\(viewModel.vacationData.selectedDates.count) 天",
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                let remaining = viewModel.availableVacationDays - viewModel.vacationData.selectedDates.count
                infoCard(
                    title: "剩餘",
                    value: "\(max(0, remaining)) 天",
                    icon: "plus.circle",
                    color: remaining > 0 ? .orange : .red
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 45)
        .padding(.bottom, 16)
    }

    // MARK: - Info Card
    private func infoCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Edit Mode Calendar Grid
    private func editModeCalendarGrid(cellHeight: CGFloat) -> some View {
        let calendar = Calendar.current
        let components = viewModel.availableVacationMonth.split(separator: "-")
        let year = Int(components[0]) ?? 2024
        let month = Int(components[1]) ?? 7

        let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        let range = calendar.range(of: .day, in: .month, for: firstDay)!
        let daysInMonth = range.count
        let startingWeekday = calendar.component(.weekday, from: firstDay) - 1

        let gridItems = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

        return LazyVGrid(columns: gridItems, alignment: .center, spacing: 2) {
            ForEach(0..<startingWeekday, id: \.self) { index in
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: cellHeight)
                    .id("empty-start-\(index)")
            }

            ForEach(1...daysInMonth, id: \.self) { day in
                editModeCalendarCell(day: day, cellHeight: cellHeight)
            }

            let totalCells = 42
            let usedCells = startingWeekday + daysInMonth
            ForEach(usedCells..<totalCells, id: \.self) { index in
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: cellHeight)
                    .id("empty-end-\(index)")
            }
        }
        .background(Color.black)
        .padding(.horizontal, 8)
        .drawingGroup()
    }

    // MARK: - Edit Mode Calendar Cell
    private func editModeCalendarCell(day: Int, cellHeight: CGFloat) -> some View {
        let dateString = String(format: "%@-%02d", viewModel.availableVacationMonth, day)
        let isVacationSelected = viewModel.vacationData.isDateSelected(dateString)
        let canSelect = viewModel.canSelectForCurrentMode(day: day)

        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6).opacity(0.3))
                .frame(height: cellHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray5).opacity(0.2), lineWidth: 1)
                )

            // 修改這裡：使用新的方法名稱 shouldShowSelectionHint
            if viewModel.shouldShowSelectionHint(day: day, canSelect: canSelect, isSelected: isVacationSelected) {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.green.opacity(0.6),
                                Color.blue.opacity(0.4)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(height: cellHeight)
            }

            if isVacationSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.orange.opacity(0.95),
                                Color.orange.opacity(0.8),
                                Color.red.opacity(0.7)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: cellHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.8), lineWidth: 1)
                    )
                    .shadow(color: .orange.opacity(0.3), radius: 3, x: 0, y: 1)
            }

            VStack(spacing: 4) {
                Text("\(day)")
                    .font(.system(size: min(cellHeight / 5, 14), weight: .medium))
                    .foregroundColor(isVacationSelected ? .white : .white)
                    .padding(.top, 8)

                if isVacationSelected {
                    Text("休")
                        .font(.system(size: min(cellHeight / 8, 8), weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.red.opacity(0.8))
                        )
                }

                Spacer()
            }
        }
        .id("edit-\(day)")
        .onTapGesture {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()

            // 檢查週休限制
            if viewModel.currentVacationMode == .weekly {
                let weekOfMonth = getWeekOfMonth(for: day)
                let currentWeekCount = getWeeklyStats()[weekOfMonth] ?? 0

                if !isVacationSelected && currentWeekCount >= viewModel.weeklyVacationLimit {
                    // 顯示錯誤提示
                    viewModel.showToast(
                        message: "已超過第 \(weekOfMonth) 週最多可排 \(viewModel.weeklyVacationLimit) 天",
                        type: .error
                    )
                    return
                }
            }

            viewModel.toggleVacationDate(dateString)
        }
    }

    // MARK: - Edit Mode Bottom Info
    private func editModeBottomInfo() -> some View {
        VStack(spacing: 8) {
            if !viewModel.vacationData.selectedDates.isEmpty {
                Text("已選擇: \(viewModel.vacationData.selectedDates.count) 天")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 15)
    }

    // MARK: - Top Buttons Overlay
    private func topButtonsOverlay() -> some View {
        VStack {
            HStack {
                Spacer()

//                Button(action: {
//                    // TODO: share section
//                }) {
//                    Image(systemName: "square.and.arrow.up")
//                        .font(.system(size: 22, weight: .medium))
//                        .foregroundColor(.white)
//                        .padding(12)
//                }

                Button(action: {
                    menuState.isMenuPresented.toggle()
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.white)
                        .padding(12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Spacer()
        }
    }

    // MARK: - Edit Button Overlay
    private func editButtonOverlay() -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()

                if viewModel.isVacationEditMode {
                    VStack(spacing: 12) {
                        if !viewModel.vacationData.selectedDates.isEmpty && !viewModel.vacationData.isSubmitted {
                            Button(action: {
                                // 在提交前檢查週休限制
                                if viewModel.currentVacationMode == .weekly {
                                    let weeklyStats = getWeeklyStats()
                                    let hasOverLimit = weeklyStats.values.contains { $0 > viewModel.weeklyVacationLimit }

                                    if hasOverLimit {
                                        viewModel.showToast(
                                            message: "請檢查週休限制，每週最多可排 \(viewModel.weeklyVacationLimit) 天",
                                            type: .error
                                        )
                                        return
                                    }
                                }

                                viewModel.submitVacation()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("提交排休")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(28)
                                .shadow(color: .blue.opacity(0.4), radius: 12, x: 0, y: 6)
                            }
                        }

                        if !viewModel.vacationData.selectedDates.isEmpty {
                            Button(action: viewModel.clearCurrentSelection) {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("清除")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.red)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial)
                                .cornerRadius(22)
                                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
                            }
                        }
                    }
                } else {
                    Button(action: {
                        isBottomSheetPresented = true
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                            .padding(15)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                }
            }
            .padding(.bottom, 30)
            .padding(.trailing, 30)
        }
    }

    // MARK: - Weekly Logic Helper Methods

    /// 獲取指定日期屬於當月的第幾週
    private func getWeekOfMonth(for day: Int) -> Int {
        let calendar = Calendar.current
        let components = viewModel.availableVacationMonth.split(separator: "-")
        let year = Int(components[0]) ?? 2024
        let month = Int(components[1]) ?? 7

        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            return 1
        }

        return calendar.component(.weekOfMonth, from: date)
    }

    /// 獲取當前選中日期的週統計
    private func getWeeklyStats() -> [Int: Int] {
        var weeklyStats: [Int: Int] = [:]
        let calendar = Calendar.current
        let components = viewModel.availableVacationMonth.split(separator: "-")
        let year = Int(components[0]) ?? 2024
        let month = Int(components[1]) ?? 7

        for dateString in viewModel.vacationData.selectedDates {
            // 解析日期字符串 (格式: "2024-07-15")
            let dateParts = dateString.split(separator: "-")
            if dateParts.count == 3,
               let dayNum = Int(dateParts[2]),
               let dateYear = Int(dateParts[0]),
               let dateMonth = Int(dateParts[1]),
               dateYear == year && dateMonth == month {

                if let date = calendar.date(from: DateComponents(year: year, month: month, day: dayNum)) {
                    let weekOfMonth = calendar.component(.weekOfMonth, from: date)
                    weeklyStats[weekOfMonth, default: 0] += 1
                }
            }
        }

        return weeklyStats
    }

    // MARK: - Action Handlers
    private func handleSelectedAction(_ action: ShiftAction?) {
        guard let action = action else { return }
        viewModel.handleVacationAction(action)
        selectedAction = nil
    }
}

#Preview {
    EmployeeCalendarView(menuState: MenuState())
}
