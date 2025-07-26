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

    // 🚨 新增：只追蹤用戶實際看到的月份
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
            // 只初始化一次
            if !isCalendarReady {
                let now = Date()
                let y = Calendar.current.component(.year, from: now)
                let m = Calendar.current.component(.month, from: now)
                let monthKey = String(format: "%04d-%02d", y, m)

                visibleMonth = monthKey
                viewModel.updateDisplayMonth(year: y, month: m)
                isCalendarReady = true

                print("📱 Boss 初始化日曆視圖: \(monthKey)")
            }

            menuState.currentVacationMode = viewModel.currentVacationMode

            // 🔥 監聽從設定頁面發佈的通知
            NotificationCenter.default.addObserver(
                forName: Notification.Name("BossSettingsPublished"),
                object: nil,
                queue: .main
            ) { [viewModel] notification in
                print("📢 Boss 收到設定頁面發佈通知，重新載入狀態")
                viewModel.forceReloadCurrentMonth()
            }
        }
        .onChange(of: viewModel.currentVacationMode) { _, newMode in
            menuState.currentVacationMode = newMode
        }
        .onChange(of: menuState.currentVacationMode) { _, newMode in
            viewModel.currentVacationMode = newMode
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
        }
    }

    // 🚨 新增：只處理真正可見的月份變化
    private func handleVisibleMonthChange(month: CalendarMonth) {
        let monthKey = String(format: "%04d-%02d", month.year, month.month)

        // 只處理用戶真正可見的月份
        guard isCalendarReady else {
            print("📅 Boss 日曆尚未準備就緒，跳過: \(monthKey)")
            return
        }

        // 防止處理相同月份
        guard monthKey != visibleMonth else {
            print("📅 Boss 月份相同，跳過: \(monthKey)")
            return
        }

        // 🔥 修復：更嚴格的年份檢查，使用正確的年份格式
        let currentYear = Calendar.current.component(.year, from: Date())
        guard month.year >= currentYear - 1 && month.year <= currentYear + 2 else {
            print("🚫 Boss 忽略不合理年份: \(month.year) (當前: \(currentYear))")
            return
        }

        print("📅 Boss 用戶切換到可見月份: \(visibleMonth) -> \(monthKey)")
        visibleMonth = monthKey
        viewModel.updateDisplayMonth(year: month.year, month: month.month)
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

                        Text("\(month.year)年") // 🔥 修復：直接使用 month.year
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))

                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()
            }

            // 🔥 修復：調整狀態顯示佈局，加入同步狀態
            HStack(spacing: 12) {
                // Vacation Status
                statusBadge(
                    title: "排休狀態",
                    status: viewModel.vacationStatusText,
                    color: viewModel.vacationStatusColor,
                    icon: viewModel.isVacationPublished ? "checkmark.circle.fill" : "clock.circle.fill"
                )

                // Schedule Status
                statusBadge(
                    title: "班表狀態",
                    status: viewModel.scheduleStatusText,
                    color: viewModel.scheduleStatusColor,
                    icon: viewModel.isSchedulePublished ? "checkmark.circle.fill" : "clock.circle.fill"
                )

                // 🔥 移動同步狀態到這裡，與其他狀態對齊
                SyncStatusView()
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
            // 兩個操作都導向同一個設定頁面
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
