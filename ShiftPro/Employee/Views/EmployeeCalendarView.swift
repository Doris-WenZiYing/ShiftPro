//
//  EmployeeCalendarView.swift
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

    // 🔥 新增：追踪已載入的月份，避免重複載入
    @State private var loadedMonths: Set<String> = []
    @State private var isInitialLoad = true

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
        .onChange(of: selectedAction) { _, action in
            handleSelectedAction(action)
        }
        .onAppear {
            // 🔥 修正：只在初次載入時同步當前月份數據
            if isInitialLoad {
                let currentDate = Date()
                let currentYear = Calendar.current.component(.year, from: currentDate)
                let currentMonth = Calendar.current.component(.month, from: currentDate)
                let currentMonthString = String(format: "%04d-%02d", currentYear, currentMonth)

                print("📱 初次載入 - 當前月份: \(currentMonthString)")
                viewModel.updateDisplayMonth(year: currentYear, month: currentMonth)
                loadedMonths.insert(currentMonthString)
                isInitialLoad = false
            }

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
            // 🔥 修正：只在月份真正變化且未載入過時才更新數據
            .onAppear {
                handleMonthAppear(month: month)
            }
        }
    }

    // 🔥 新增：處理月份出現的方法
    private func handleMonthAppear(month: CalendarMonth) {
        let monthString = String(format: "%04d-%02d", month.year, month.month)
        if !loadedMonths.contains(monthString) {
            print("📅 載入新月份: \(monthString)")
            viewModel.updateDisplayMonth(year: month.year, month: month.month)
            loadedMonths.insert(monthString)
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

            // 🔥 修正：基於當前顯示月份和設定狀態顯示 Badge
            let currentDisplayMonth = String(format: "%04d-%02d", month.year, month.month)
            let isCurrentMonth = currentDisplayMonth == viewModel.getCurrentMonthString()

            if currentDisplayMonth == viewModel.currentDisplayMonth && !viewModel.isVacationEditMode {

                // 如果有老闆設定且已發佈
                if viewModel.isUsingBossSettings {
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
                // 如果是當前月份但老闆尚未發佈
                else if isCurrentMonth {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)

                        Text("等待發佈")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(16)
                }
                // 如果是其他月份且老闆尚未發佈
                else {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)

                        Text("尚未設定")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(16)
                }
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
                        Text(viewModel.formatMonthString(viewModel.currentDisplayMonth))
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

            // 🔥 優化：Info Cards with enhanced weekly info
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

            // 🔥 新增：週休限制資訊卡
            if viewModel.currentVacationMode == .weekly || viewModel.currentVacationMode == .monthlyWithWeeklyLimit {
                weeklyLimitInfoCard()
            }

            // 週休統計顯示 (週休和月休模式都顯示)
            if !viewModel.vacationData.selectedDates.isEmpty {
                weeklyStatsView()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 45)
        .padding(.bottom, 16)
    }

    // MARK: - 🔥 修復：週休限制資訊卡
    private func weeklyLimitInfoCard() -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.day.timeline.leading")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)

                Text("週休限制")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Text("每週最多 \(viewModel.weeklyVacationLimit) 天")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
            }

            HStack {
                Text("週一～週日為一週")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - 🔥 修復：週休統計視圖 (分解複雜表達式)
    private func weeklyStatsView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("週休統計")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            weeklyStatsGrid()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    // 🔥 新增：分離的週休統計網格
    private func weeklyStatsGrid() -> some View {
        let weeklyStats = getWeeklyStats()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(weeklyStats.keys.sorted()), id: \.self) { week in
                weeklyStatsCard(week: week, count: weeklyStats[week] ?? 0)
            }
        }
    }

    // 🔥 新增：單個週休統計卡片
    private func weeklyStatsCard(week: Int, count: Int) -> some View {
        let isOverLimit = count > viewModel.weeklyVacationLimit
        let isAtLimit = count == viewModel.weeklyVacationLimit
        let weekRangeText = getWeekRangeText(for: week)

        return VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text("第\(week)週")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                Text("\(count)/\(viewModel.weeklyVacationLimit)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(statusColor(isOverLimit: isOverLimit, isAtLimit: isAtLimit))

                Image(systemName: statusIcon(isOverLimit: isOverLimit, isAtLimit: isAtLimit))
                    .font(.system(size: 10))
                    .foregroundColor(statusColor(isOverLimit: isOverLimit, isAtLimit: isAtLimit))
            }

            if !weekRangeText.isEmpty {
                HStack {
                    Text(weekRangeText)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(statusBackgroundColor(isOverLimit: isOverLimit, isAtLimit: isAtLimit))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(statusBorderColor(isOverLimit: isOverLimit, isAtLimit: isAtLimit), lineWidth: 1)
        )
    }

    // MARK: - 🔥 新增：狀態輔助方法
    private func statusColor(isOverLimit: Bool, isAtLimit: Bool) -> Color {
        if isOverLimit { return .red }
        if isAtLimit { return .orange }
        return .white
    }

    private func statusIcon(isOverLimit: Bool, isAtLimit: Bool) -> String {
        if isOverLimit { return "exclamationmark.triangle.fill" }
        if isAtLimit { return "checkmark.circle.fill" }
        return "circle"
    }

    private func statusBackgroundColor(isOverLimit: Bool, isAtLimit: Bool) -> Color {
        if isOverLimit { return Color.red.opacity(0.2) }
        if isAtLimit { return Color.orange.opacity(0.2) }
        return Color.green.opacity(0.15)
    }

    private func statusBorderColor(isOverLimit: Bool, isAtLimit: Bool) -> Color {
        if isOverLimit { return Color.red.opacity(0.5) }
        if isAtLimit { return Color.orange.opacity(0.5) }
        return Color.green.opacity(0.3)
    }

    // 🔥 新增：獲取週範圍文字
    private func getWeekRangeText(for weekNumber: Int) -> String {
        let calendar = Calendar.current
        let components = viewModel.currentDisplayMonth.split(separator: "-")
        guard let year = Int(components[0]), let month = Int(components[1]) else { return "" }

        // 找到該週的任一天來計算範圍
        for day in 1...31 {
            if let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
               calendar.component(.weekOfMonth, from: date) == weekNumber {
                return WeekUtils.formatWeekRange(
                    WeekUtils.getWeekRange(for: date).start,
                    WeekUtils.getWeekRange(for: date).end
                )
            }
        }
        return ""
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
        let components = viewModel.currentDisplayMonth.split(separator: "-")
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

    // MARK: - Edit Mode Calendar Cell (優化版)
    private func editModeCalendarCell(day: Int, cellHeight: CGFloat) -> some View {
        let dateString = String(format: "%@-%02d", viewModel.currentDisplayMonth, day)
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

            // 🔥 優化：更完善的週休限制檢查邏輯
            handleVacationDateSelection(dateString: dateString, day: day, isCurrentlySelected: isVacationSelected)
        }
    }

    // 🔥 新增：處理排休日期選擇的核心邏輯
    private func handleVacationDateSelection(dateString: String, day: Int, isCurrentlySelected: Bool) {
        // 直接使用 ViewModel 的 toggleVacationDate 方法，它已經包含了所有邏輯
        viewModel.toggleVacationDate(dateString)
    }

    // MARK: - Edit Mode Bottom Info
    private func editModeBottomInfo() -> some View {
        VStack(spacing: 8) {
            // 🔥 優化：顯示更詳細的底部資訊
            if !viewModel.vacationData.selectedDates.isEmpty {
                HStack(spacing: 16) {
                    Text("已選擇: \(viewModel.vacationData.selectedDates.count) 天")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))

                    if viewModel.currentVacationMode == .weekly || viewModel.currentVacationMode == .monthlyWithWeeklyLimit {
                        if viewModel.hasWeeklyConflicts() {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.red)
                                Text("週限制超標")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    Spacer()
                }
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

                Button(action: {
                    withAnimation(.linear(duration: 0.25)) {
                        menuState.isMenuPresented.toggle()
                    }
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
        let components = viewModel.currentDisplayMonth.split(separator: "-")
        let year = Int(components[0]) ?? 2024
        let month = Int(components[1]) ?? 7

        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            return 1
        }

        return calendar.component(.weekOfMonth, from: date)
    }

    /// 獲取當前選中日期的週統計
    private func getWeeklyStats() -> [Int: Int] {
        return viewModel.getWeeklyStats()
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
