//
//  BossCalendarView.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/11.
//

import SwiftUI

struct BossCalendarView: View {
    // MARK: - Properties
    @ObservedObject var controller: CalendarController = CalendarController(orientation: .vertical)
    @StateObject private var viewModel = BossCalendarViewModel()
    @ObservedObject var menuState: MenuState

    // MARK: - UI State
    @State private var isBottomSheetPresented = false
    @State private var selectedAction: BossAction?
    @State private var isDatePickerPresented = false
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var showingSettingsView = false
    @State private var showingSchedulePublishView = false

    // 🔥 優化：月份追蹤
    @State private var visibleMonth: String = ""
    @State private var isCalendarReady = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            normalModeCalendarView()

            topButtonsOverlay()
                .zIndex(1)

            editButtonOverlay()
                .zIndex(2)

            // 載入指示器
            if viewModel.isFirebaseLoading {
                loadingOverlay()
                    .zIndex(3)
            }

            ToastView(
                message: viewModel.toastMessage,
                type: viewModel.toastType,
                isShowing: $viewModel.isToastShowing
            )
            .zIndex(5)
        }
        .sheet(isPresented: $isBottomSheetPresented) {
            BossBottomSheetView(
                isPresented: $isBottomSheetPresented,
                selectedAction: $selectedAction,
                isVacationPublished: viewModel.isVacationPublished,
                isSchedulePublished: viewModel.isSchedulePublished
            )
            .presentationDetents([.fraction(0.7)])
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
                print("📅 Boss 用戶手動選擇月份: \(monthKey)")
                viewModel.updateDisplayMonth(year: selectedYear, month: selectedMonth)
                visibleMonth = monthKey
            }
        }
        // 🔥 保持你的自定義設定
        .sheet(isPresented: $showingSettingsView) {
            BossSettingsView()
        }
        .sheet(isPresented: $showingSchedulePublishView) {
            SchedulePublishView(
                isPresented: $showingSchedulePublishView,
                onPublish: { scheduleData in
                    viewModel.publishSchedule(scheduleData)
                }
            )
        }
        .onChange(of: selectedAction) { _, action in
            handleSelectedAction(action)
        }
        .onAppear {
            setupCalendar()
            syncMenuState()
        }
        .onChange(of: viewModel.currentVacationMode) { _, newMode in
            menuState.currentVacationMode = newMode
        }
        .onChange(of: menuState.currentVacationMode) { _, newMode in
            viewModel.currentVacationMode = newMode
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

        print("📱 Boss 初始化日曆視圖: \(monthKey)")
    }

    private func syncMenuState() {
        menuState.currentVacationMode = viewModel.currentVacationMode
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

    // 處理可見月份變化
    private func handleVisibleMonthChange(month: CalendarMonth) {
        let monthKey = String(format: "%04d-%02d", month.year, month.month)

        guard isCalendarReady else { return }
        guard monthKey != visibleMonth else { return }
        guard isValidMonth(month: month) else { return }

        print("📅 Boss 切換到可見月份: \(visibleMonth) -> \(monthKey)")
        visibleMonth = monthKey
        viewModel.updateDisplayMonth(year: month.year, month: month.month)
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
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        // 🔥 修復問題3：直接使用 Int 轉 String，避免格式化器
                        Text("\(month.year)年")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))

                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                // 處理中指示器
                if viewModel.isFirebaseLoading {
                    HStack(spacing: 6) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.8)

                        Text("處理中")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(12)
                }
            }

            // 狀態顯示
            HStack(spacing: 12) {
                // Vacation Status - 使用真實 Firebase 狀態
                statusBadge(
                    title: "排休狀態",
                    status: viewModel.vacationStatusText,
                    color: viewModel.vacationStatusColor,
                    icon: getVacationIcon()
                )

                // Schedule Status
                statusBadge(
                    title: "班表狀態",
                    status: viewModel.scheduleStatusText,
                    color: viewModel.scheduleStatusColor,
                    icon: viewModel.isSchedulePublished ? "checkmark.circle.fill" : "clock.circle.fill"
                )

                // 顯示更多資訊
                if let rule = viewModel.firebaseRule {
                    VStack(spacing: 2) {
                        Text("\(rule.monthlyLimit ?? 0)天")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.green)

                        Text("月限制")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(8)
                }

                // Sync Status
                SyncStatusView()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    // 動態圖標
    private func getVacationIcon() -> String {
        if viewModel.isFirebaseLoading {
            return "clock.arrow.circlepath"
        } else if viewModel.isVacationPublished {
            return "checkmark.circle.fill"
        } else {
            return "clock.circle.fill"
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

        return ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.05))
                .frame(height: cellHeight)

            if isSelected {
                Rectangle()
                    .fill(Color.white.opacity(date.isCurrentMonth == true ? 1.0 : 0.6))
                    .frame(height: cellHeight)
            }

            VStack(spacing: 4) {
                Text("\(date.day)")
                    .font(.system(size: min(cellHeight / 5, 14), weight: .medium))
                    .foregroundColor(
                        isSelected ? .black : (date.isCurrentMonth == true ? .white : .gray.opacity(0.4))
                    )
                    .padding(.top, 8)

                Spacer()
            }
        }
        .onTapGesture {
            controller.selectDate(date)
        }
    }

    // MARK: - Loading Overlay
    private func loadingOverlay() -> some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)

                Text("處理中...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(Color.black.opacity(0.8))
            .cornerRadius(16)
        }
    }

    // MARK: - Top Buttons Overlay
    private func topButtonsOverlay() -> some View {
        VStack {
            HStack {
                Spacer()

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
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

                Button(action: {
                    isBottomSheetPresented = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.yellow)

                        Text("管理")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                }
                .disabled(viewModel.isFirebaseLoading)
            }
            .padding(.bottom, 30)
            .padding(.trailing, 30)
        }
    }

    // MARK: - Action Handlers
    private func handleSelectedAction(_ action: BossAction?) {
        guard let action = action else { return }

        switch action {
        case .publishVacation, .manageVacationLimits:
            showingSettingsView = true
        case .publishSchedule:
            showingSchedulePublishView = true
        default:
            viewModel.handleBossAction(action)
        }

        selectedAction = nil
    }
}

#Preview {
    BossCalendarView(menuState: MenuState())
}
