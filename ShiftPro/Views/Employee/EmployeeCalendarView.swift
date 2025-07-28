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
    @State private var showingScheduleEditView = false

    // 🔥 優化：追蹤用戶可見月份
    @State private var visibleMonth: String = ""
    @State private var isCalendarReady = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.isSubmissionMode {
                // 🔥 新增：排休提交畫面
                EmployeeScheduleEditView(
                    isPresented: $viewModel.isSubmissionMode,
                    viewModel: viewModel
                )
                .transition(.move(edge: .bottom))
            } else {
                normalModeCalendarView()
            }

            if !viewModel.isSubmissionMode {
                topBar()
                bottomBar()
            }

            // Toast 通知
            ToastView(
                message: viewModel.toastMessage,
                type: viewModel.toastType,
                isShowing: $viewModel.isToastShowing
            )
            .zIndex(5)
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isSubmissionMode)
        .sheet(isPresented: $isSheetPresented) {
            BottomSheetView(
                isPresented: $isSheetPresented,
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
            .onDisappear {
                let monthKey = String(format: "%04d-%02d", selectedYear, selectedMonth)
                viewModel.updateDisplayMonth(year: selectedYear, month: selectedMonth)
                visibleMonth = monthKey
            }
        }
        .onChange(of: selectedAction) { _, action in
            if let action = action {
                viewModel.handleVacationAction(action)
                selectedAction = nil
            }
        }
        .onChange(of: viewModel.currentVacationMode) { _, newMode in
            menuState.currentVacationMode = newMode
        }
        .onChange(of: menuState.currentVacationMode) { _, newMode in
            viewModel.currentVacationMode = newMode
        }
        .onAppear {
            setupCalendar()
        }
    }

    // MARK: - Setup
    private func setupCalendar() {
        guard !isCalendarReady else { return }

        let now = Date()
        let year = Calendar.current.component(.year, from: now)
        let month = Calendar.current.component(.month, from: now)
        let monthKey = String(format: "%04d-%02d", year, month)

        visibleMonth = monthKey
        viewModel.updateDisplayMonth(year: year, month: month)
        isCalendarReady = true

        print("📱 Employee 初始化日曆視圖: \(monthKey)")
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
                handleVisibleMonthChange(month: month)
            }
        }
    }

    // 🔥 修復問題3：優化月份變化處理，避免狀態混亂
    private func handleVisibleMonthChange(month: CalendarMonth) {
        let monthKey = String(format: "%04d-%02d", month.year, month.month)

        guard isCalendarReady else { return }
        guard monthKey != visibleMonth else { return }
        guard isValidMonth(month: month) else { return }

        print("📅 Employee 切換到可見月份: \(visibleMonth) -> \(monthKey)")
        visibleMonth = monthKey

        // 🔥 修復：延遲更新避免狀態混亂
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            viewModel.updateDisplayMonth(year: month.year, month: month.month)
        }
    }

    private func isValidMonth(month: CalendarMonth) -> Bool {
        let currentYear = Calendar.current.component(.year, from: Date())
        return month.year >= currentYear - 1 && month.year <= currentYear + 2
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

                        // 🔥 修復問題4：年份顯示不使用格式化器
                        Text("\(month.year)年")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))

                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                // 🔥 優化：編輯模式指示器
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

            // 🔥 修復問題3：優化狀態顯示，確保穩定性
            HStack(spacing: 12) {
                // 排休狀態
                statusBadge(
                    title: "排休狀態",
                    status: getVacationStatus(for: month),
                    color: getVacationStatusColor(for: month),
                    icon: getVacationStatusIcon(for: month)
                )

                // 老闆設定狀態
                statusBadge(
                    title: "老闆設定",
                    status: viewModel.isUsingBossSettings ? "已發佈" : "等待中",
                    color: viewModel.isUsingBossSettings ? .green : .gray,
                    icon: viewModel.isUsingBossSettings ? "checkmark.circle.fill" : "clock.circle"
                )

                // 同步狀態
                SyncStatusView()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    // MARK: - 🔥 修復問題3：優化狀態判斷邏輯，確保一致性
    private func getVacationStatus(for month: CalendarMonth) -> String {
        let monthKey = String(format: "%04d-%02d", month.year, month.month)

        // 🔥 確保只對當前顯示月份進行狀態判斷
        guard monthKey == viewModel.currentDisplayMonth else {
            // 其他月份根據是否有老闆設定來決定
            return viewModel.isUsingBossSettings ? "可排休" : "等待發佈"
        }

        // 🔥 使用真實 Firebase 狀態，優先級：已提交 > 未提交 > 可排休 > 等待發佈
        if viewModel.isReallySubmitted {
            return "已提交"
        } else if !viewModel.vacationData.selectedDates.isEmpty {
            return "未提交"
        } else if viewModel.isUsingBossSettings {
            return "可排休"
        } else {
            return "等待發佈"
        }
    }

    private func getVacationStatusColor(for month: CalendarMonth) -> Color {
        let monthKey = String(format: "%04d-%02d", month.year, month.month)

        guard monthKey == viewModel.currentDisplayMonth else {
            return viewModel.isUsingBossSettings ? .blue : .gray
        }

        if viewModel.isReallySubmitted {
            return .green
        } else if !viewModel.vacationData.selectedDates.isEmpty {
            return .orange
        } else if viewModel.isUsingBossSettings {
            return .blue
        } else {
            return .gray
        }
    }

    private func getVacationStatusIcon(for month: CalendarMonth) -> String {
        let monthKey = String(format: "%04d-%02d", month.year, month.month)

        guard monthKey == viewModel.currentDisplayMonth else {
            return viewModel.isUsingBossSettings ? "calendar.badge.checkmark" : "clock.circle"
        }

        if viewModel.isReallySubmitted {
            return "checkmark.circle.fill"
        } else if !viewModel.vacationData.selectedDates.isEmpty {
            return "clock.circle.fill"
        } else if viewModel.isUsingBossSettings {
            return "calendar.badge.checkmark"
        } else {
            return "clock.circle"
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
        let dateString = viewModel.dateToString(date)
        let monthKey = String(format: "%04d-%02d", month.year, month.month)

        let isVacationSelected = monthKey == viewModel.currentDisplayMonth &&
                                date.isCurrentMonth == true &&
                                viewModel.vacationData.selectedDates.contains(dateString)

        let canSelect = viewModel.canSelect(day: date.day) && date.isCurrentMonth == true

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
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.orange, lineWidth: 2)
                            .padding(2)
                    )
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

                // 🔥 優化：更好的指示器
                HStack(spacing: 2) {
                    if isSelected {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                    }

                    if isVacationSelected {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                    }
                }

                Spacer()
            }

            // 🔥 不可選擇的日期遮罩
            if !canSelect && date.isCurrentMonth == true {
                Rectangle()
                    .fill(Color.black.opacity(0.3))
                    .frame(height: cellHeight)
            }
        }
        .onTapGesture {
            if viewModel.isVacationEditMode &&
               date.isCurrentMonth == true &&
               monthKey == viewModel.currentDisplayMonth &&
               canSelect {
                viewModel.toggleVacationDate(dateString)
            } else {
                controller.selectDate(date)
            }
        }
        .opacity(date.isCurrentMonth == true ? 1.0 : 0.3)
    }

    // MARK: - Top Bar
    private func topBar() -> some View {
        VStack {
            HStack {
                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        menuState.isMenuPresented.toggle()
                    }
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
                    // 編輯模式按鈕
                    HStack(spacing: 12) {
                        Button("取消") {
                            viewModel.exitEditMode()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)

                        Button("提交排休") {
                            viewModel.submitVacation()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .disabled(viewModel.vacationData.selectedDates.isEmpty)

                        Button("清除") {
                            viewModel.clearAllVacationData()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding(.trailing, 24)
                } else {
                    // 主要操作按鈕
                    Button {
                        if viewModel.canEditVacation {
                            // 🔥 直接進入排休編輯畫面
                            viewModel.handleVacationAction(.editVacation)
                        } else if !viewModel.canEditMonth() {
                            viewModel.showToast("無法編輯過去月份", type: .error)
                        } else {
                            isSheetPresented = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: getActionIcon())
                                .font(.system(size: 14))

                            Text(getActionText())
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(getActionColor())
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    .padding(.trailing, 30)
                }
            }
            .padding(.bottom, 30)
        }
    }

    // MARK: - 🔥 優化：動態按鈕文字和樣式
    private func getActionText() -> String {
        if viewModel.isReallySubmitted {
            return "已提交"
        } else if !viewModel.vacationData.selectedDates.isEmpty {
            return "繼續編輯"
        } else if viewModel.isFutureMonth() {
            return "預約排休"
        } else {
            return "開始排休"
        }
    }

    private func getActionIcon() -> String {
        if viewModel.isReallySubmitted {
            return "checkmark.circle.fill"
        } else if !viewModel.vacationData.selectedDates.isEmpty {
            return "pencil.circle"
        } else {
            return "calendar.badge.plus"
        }
    }

    private func getActionColor() -> Color {
        if viewModel.isReallySubmitted {
            return .green
        } else if !viewModel.canEditVacation {
            return .gray
        } else {
            return .blue
        }
    }
}

// MARK: - 🔥 修復後的員工排休編輯畫面
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
    EmployeeCalendarView(menuState: MenuState())
}
