//
//  EmployeeCalendarView.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/8.
//

import SwiftUI

struct EmployeeCalendarView: View {
    @ObservedObject var controller: CalendarController = CalendarController(orientation: .vertical)
    @State private var isBottomSheetPresented = false
    @State private var selectedAction: ShiftAction?

    // 排休相關狀態
    @State private var isVacationEditMode = false
    @State private var vacationData = VacationData()
    @State private var vacationLimits = VacationLimits.weeklyOnly
    @State private var toastMessage = ""
    @State private var toastType: ToastView.ToastType = .info
    @State private var isToastShowing = false

    // 排班月份限制 - 使用當前月份
    @State private var availableVacationMonth: String = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date.now)
    }()
    @State private var availableVacationDays: Int = 4

    // 優化後的統一 Picker 狀態
    @State private var isDatePickerPresented = false
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            if isVacationEditMode {
                // 編輯模式：只顯示可編輯月份的簡化月曆
                editModeCalendarView()
            } else {
                // 一般模式：完整月曆
                normalModeCalendarView()
            }

            // FLOATING: Top buttons overlay (只在非編輯模式顯示)
            if !isVacationEditMode {
                topButtonsOverlay()
            }

            // FLOATING: Edit button overlay
            editButtonOverlay()

            // Toast 通知
            ToastView(message: toastMessage, type: toastType, isShowing: $isToastShowing)
                .zIndex(3)

            // 統一的日期選擇器
            if isDatePickerPresented {
                datePickerOverlay()
            }
        }
        .sheet(isPresented: $isBottomSheetPresented) {
            BottomSheetView(
                isPresented: $isBottomSheetPresented,
                selectedAction: $selectedAction
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
        }
        .onChange(of: selectedAction) { _, action in
            if let action = action {
                handleSelectedAction(action)
                selectedAction = nil
            }
        }
        .onAppear {
            loadVacationData()
        }
    }

    // MARK: - 一般模式月曆
    private func normalModeCalendarView() -> some View {
        FullPageScrollCalendarView(controller) { month in
            VStack(spacing: 0) {
                monthTitleView(month: month)
                weekdayHeadersView()

                GeometryReader { geometry in
                    let availableHeight = geometry.size.height
                    let cellHeight = max((availableHeight - 20) / 6, 70)

                    calendarGridView(month: month, cellHeight: cellHeight, isEditMode: false)
                }
            }
        }
    }

    // MARK: - 編輯模式簡化月曆 (移除多餘區域，上移)
    private func editModeCalendarView() -> some View {
        VStack(spacing: 0) {
            // 簡化的編輯模式標題 (減少頂部空白)
            editModeHeader()

            // 直接顯示月曆，移除多餘的提示文字
            GeometryReader { geometry in
                let availableHeight = geometry.size.height
                let cellHeight = max((availableHeight - 30) / 6, 80)

                VStack(spacing: 0) {
                    editModeWeekdayHeaders()
                    editModeCalendarGrid(cellHeight: cellHeight)
                }
            }

            // 編輯模式底部資訊 (簡化)
            editModeBottomInfo()
        }
    }

    // MARK: - 編輯模式標題 (緊湊版，減少空白)
    private func editModeHeader() -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("排休編輯")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text(formatMonthString(availableVacationMonth))
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isVacationEditMode = false
                    }
                }) {
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

            // 排休資訊卡片
            HStack(spacing: 12) {
                infoCard(
                    title: "可排休",
                    value: "\(availableVacationDays) 天",
                    icon: "calendar.badge.clock",
                    color: .blue
                )

                infoCard(
                    title: "已選擇",
                    value: "\(vacationData.selectedDates.count) 天",
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                let remaining = availableVacationDays - vacationData.selectedDates.count
                infoCard(
                    title: "剩餘",
                    value: "\(max(0, remaining)) 天",
                    icon: "plus.circle",
                    color: remaining > 0 ? .orange : .red
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 45) // 減少頂部間距，從 60 減到 45
        .padding(.bottom, 16) // 減少底部間距
    }

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

    // MARK: - 編輯模式週日標題 (對齊格子中央)
    private func editModeWeekdayHeaders() -> some View {
        HStack(spacing: 1) { // 使用與格子相同的間距
            ForEach(0..<7, id: \.self) { i in
                Text(DateFormatter().shortWeekdaySymbols[i].prefix(1))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity) // 確保完全對齊
                    .textCase(.uppercase)
            }
        }
        .padding(.horizontal, 0) // 移除 padding 確保對齊
        .padding(.bottom, 12)
    }

    // MARK: - 編輯模式月曆格子
    private func editModeCalendarGrid(cellHeight: CGFloat) -> some View {
        let calendar = Calendar.current
        let components = availableVacationMonth.split(separator: "-")
        let year = Int(components[0]) ?? 2024
        let month = Int(components[1]) ?? 7

        let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        let range = calendar.range(of: .day, in: .month, for: firstDay)!
        let daysInMonth = range.count
        let startingWeekday = calendar.component(.weekday, from: firstDay) - 1

        let gridItems = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

        return LazyVGrid(columns: gridItems, alignment: .center, spacing: 2) {
            // 前面的空白日期
            ForEach(0..<startingWeekday, id: \.self) { index in
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: cellHeight)
                    .id("empty-start-\(index)") // 添加穩定的 ID
            }

            // 當月日期
            ForEach(1...daysInMonth, id: \.self) { day in
                editModeCalendarCell(day: day, cellHeight: cellHeight)
            }

            // 後面的空白日期填滿 6 週
            let totalCells = 42
            let usedCells = startingWeekday + daysInMonth
            ForEach(usedCells..<totalCells, id: \.self) { index in
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: cellHeight)
                    .id("empty-end-\(index)") // 添加穩定的 ID
            }
        }
        .background(Color.black)
        .padding(.horizontal, 8)
        .drawingGroup() // 減少重繪，提升滑動性能
    }

    private func editModeCalendarCell(day: Int, cellHeight: CGFloat) -> some View {
        let dateString = String(format: "%@-%02d", availableVacationMonth, day)
        let isVacationSelected = vacationData.isDateSelected(dateString)
        let canSelect = canSelectForWeeklyLimit(day: day)

        return ZStack {
            // 基礎背景 - 與一般模式保持一致
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6).opacity(0.3))
                .frame(height: cellHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray5).opacity(0.2), lineWidth: 1)
                )

            // 週排休框線提示 - 更精緻的提示
            if case .weekly = vacationLimits.type, canSelect && !isVacationSelected {
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

            // 排休選擇背景 - 豐富的漸層效果
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

            VStack(spacing: 0) {
                Text("\(day)")
                    .font(.system(size: min(cellHeight / 5, 16), weight: .medium))
                    .foregroundColor(isVacationSelected ? .white : .white)
                    .padding(.top, 8)

                Spacer()

                if isVacationSelected {
                    Text("休")
                        .font(.system(size: min(cellHeight / 8, 9), weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.red.opacity(0.8))
                        )
                        .padding(.bottom, 8)
                } else {
                    Spacer()
                        .frame(height: 18)
                }
            }
        }
        .id("edit-\(day)") // 添加穩定的 ID
        .onTapGesture {
            // 添加輕微的觸覺反饋，但不要視覺動畫
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            toggleVacationDate(dateString: dateString)
        }
    }

    // MARK: - 編輯模式底部資訊 (簡化)
    private func editModeBottomInfo() -> some View {
        VStack(spacing: 8) {
            if !vacationData.selectedDates.isEmpty {
                Text("已選擇: \(vacationData.selectedDates.count) 天")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 15) // 減少底部空間
    }

    // MARK: - 週排休邏輯
    private func canSelectForWeeklyLimit(day: Int) -> Bool {
        guard case .weekly(let weeklyLimit) = vacationLimits.type else { return true }

        let calendar = Calendar.current
        let components = availableVacationMonth.split(separator: "-")
        let year = Int(components[0]) ?? 2024
        let month = Int(components[1]) ?? 7

        guard let targetDate = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            return false
        }

        let selectedInSameWeek = vacationData.selectedDates.compactMap { dateString -> Date? in
            let parts = dateString.split(separator: "-")
            guard parts.count == 3,
                  let y = Int(parts[0]),
                  let m = Int(parts[1]),
                  let d = Int(parts[2]) else { return nil }
            return calendar.date(from: DateComponents(year: y, month: m, day: d))
        }.filter { selectedDate in
            calendar.isDate(selectedDate, equalTo: targetDate, toGranularity: .weekOfYear)
        }

        return selectedInSameWeek.count < weeklyLimit
    }

    private func handleSelectedAction(_ action: ShiftAction) {
        switch action {
        case .editVacation:
            let currentMonth = getCurrentMonthString()
            if currentMonth != availableVacationMonth {
                showToast("只能在 \(formatMonthString(availableVacationMonth)) 排休", type: .error)
                return
            }

            if vacationData.isSubmitted {
                showToast("本月排休已提交，無法修改", type: .error)
                return
            }
            withAnimation(.easeInOut(duration: 0.3)) {
                isVacationEditMode = true
            }
        case .clearVacation:
            let key = "VacationData_\(getCurrentMonthString())"
            UserDefaults.standard.removeObject(forKey: key)
            vacationData = VacationData()
            showToast("所有排休資料已清除", type: .info)
        }
    }

    // MARK: - 優化後的月份標題視圖 (統一的日期選擇器觸發)
    private func monthTitleView(month: CalendarMonth) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 月份和年份 - 統一的點擊區域
                Button(action: {
                    selectedMonth = month.month
                    selectedYear = month.year
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isDatePickerPresented = true
                    }
                }) {
                    HStack(spacing: 8) {
                        Text(month.monthName)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)

                        Text("\(month.year)年")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))

                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                // 只在編輯模式顯示編輯中標籤
                if isVacationEditMode {
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

            // 可排休標籤移到月份標題下方，避免被擋住
            // 修正：檢查當前顯示的月份是否為可排休月份
            let currentDisplayMonth = String(format: "%04d-%02d", month.year, month.month)
            if currentDisplayMonth == availableVacationMonth && !isVacationEditMode {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    Text("可排休")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.2))
                .cornerRadius(16)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    // MARK: - 優化的統一日期選擇器
    private func datePickerOverlay() -> some View {
        ZStack {
            // 半透明黑色背景
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isDatePickerPresented = false
                    }
                }

            VStack {
                Spacer()

                VStack(spacing: 0) {
                    // 頂部控制條
                    HStack {
                        Button("取消") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isDatePickerPresented = false
                            }
                        }
                        .foregroundColor(.blue)
                        .font(.system(size: 17))

                        Spacer()

                        Text("選擇日期")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)

                        Spacer()

                        Button("完成") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isDatePickerPresented = false
                            }
                        }
                        .foregroundColor(.blue)
                        .font(.system(size: 17, weight: .semibold))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(.systemGray6))

                    // 分隔線
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 0.5)

                    // 統一的年月選擇器
                    HStack(spacing: 0) {
                        // 年份選擇器
                        VStack(spacing: 8) {
                            Text("年份")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.top, 12)

                            Picker("年份", selection: $selectedYear) {
                                ForEach(2020...2030, id: \.self) { year in
                                    Text("\(year)")
                                        .font(.system(size: 20, weight: .medium))
                                        .tag(year)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(height: 180)
                        }
                        .frame(maxWidth: .infinity)

                        // 中間分隔線
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(width: 1)
                            .padding(.vertical, 20)

                        // 月份選擇器
                        VStack(spacing: 8) {
                            Text("月份")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.top, 12)

                            Picker("月份", selection: $selectedMonth) {
                                ForEach(1...12, id: \.self) { month in
                                    Text("\(month)月")
                                        .font(.system(size: 20, weight: .medium))
                                        .tag(month)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(height: 180)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .background(Color(.systemBackground))
                    .padding(.bottom, 12)
                }
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .zIndex(10)
    }

    private func weekdayHeadersView() -> some View {
        HStack(spacing: 1) { // 使用與格子相同的間距
            ForEach(0..<7, id: \.self) { i in
                Text(DateFormatter().shortWeekdaySymbols[i].prefix(1))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .textCase(.uppercase)
            }
        }
        .padding(.horizontal, 0) // 移除 padding 確保對齊
        .padding(.bottom, 12)
    }

    private func calendarGridView(month: CalendarMonth, cellHeight: CGFloat, isEditMode: Bool) -> some View {
        let dates = month.getDaysInMonth(offset: 0)
        let gridItems = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

        return LazyVGrid(columns: gridItems, alignment: .center, spacing: 2) {
            ForEach(0..<42, id: \.self) { index in
                normalModeCalendarCell(date: dates[index], month: month, cellHeight: cellHeight)
            }
        }
        .background(Color.black)
        .padding(.horizontal, 8)
        .drawingGroup() // 減少重繪，提升滑動性能
    }

    private func normalModeCalendarCell(date: CalendarDate, month: CalendarMonth, cellHeight: CGFloat) -> some View {
        let dateString = dateToString(date)
        let isSelected = controller.isDateSelected(date) && date.isCurrentMonth == true
        let isVacationSelected = vacationData.isDateSelected(dateString) && date.isCurrentMonth == true

        return ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.05))
                .frame(height: cellHeight)

            if isSelected && !isVacationEditMode {
                Rectangle()
                    .fill(Color.white)
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

            VStack(spacing: 0) {
                Text("\(date.day)")
                    .font(.system(size: min(cellHeight / 5, 16), weight: .medium)) // 縮小字體
                    .foregroundColor(textColor(for: date, isSelected: isSelected, isVacationSelected: isVacationSelected))
                    .padding(.top, 8)

                Spacer()

                if isVacationSelected {
                    Text("休")
                        .font(.system(size: min(cellHeight / 8, 9), weight: .bold)) // 縮小標籤
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.orange)
                        .cornerRadius(4)
                        .padding(.bottom, 8)
                } else {
                    Spacer()
                        .frame(height: 18)
                }
            }
        }
        .onTapGesture {
            if date.isCurrentMonth == true {
                controller.selectDate(date)
            } else {
                controller.selectDate(date)
            }
        }
    }

    private func textColor(for date: CalendarDate, isSelected: Bool, isVacationSelected: Bool) -> Color {
        if isVacationSelected {
            return .white
        } else if isSelected && !isVacationEditMode {
            return .black
        } else if date.isCurrentMonth == true {
            return .white
        } else {
            // 其他月份的日期用稍微亮一點的灰色，讓選中效果更明顯
            return isSelected ? .black : .gray.opacity(0.4)
        }
    }

    // MARK: - 排休邏輯 (優化性能)
    private func toggleVacationDate(dateString: String) {
        if vacationData.isSubmitted {
            showToast("已提交排休，無法修改", type: .error)
            return
        }

        // 使用批量更新避免多次 UI 重繪
        var newVacationData = vacationData

        if newVacationData.isDateSelected(dateString) {
            newVacationData.removeDate(dateString)
        } else {
            if newVacationData.selectedDates.count >= availableVacationDays {
                showToast("已超過可排休天數上限 (\(availableVacationDays) 天)", type: .error)
                return
            }

            if case .weekly(let weeklyLimit) = vacationLimits.type {
                let day = Int(dateString.suffix(2)) ?? 1
                if !canSelectForWeeklyLimit(day: day) {
                    showToast("已超過本週排休上限 (\(weeklyLimit) 天)", type: .error)
                    return
                }
            }

            newVacationData.addDate(dateString)
        }

        // 一次性更新狀態，減少重繪
        vacationData = newVacationData
        saveVacationData()
    }

    private func dateToString(_ date: CalendarDate) -> String {
        return String(format: "%04d-%02d-%02d", date.year, date.month, date.day)
    }

    private func formatMonthString(_ monthString: String) -> String {
        let components = monthString.split(separator: "-")
        if components.count == 2,
           let year = Int(components[0]),
           let month = Int(components[1]) {
            return "\(year)年\(month)月"
        }
        return monthString
    }

    private func topButtonsOverlay() -> some View {
        VStack {
            HStack {
                Spacer()
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                Button(action: {}) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Spacer()
        }
    }

    private func editButtonOverlay() -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()

                if isVacationEditMode {
                    VStack(spacing: 12) {
                        if !vacationData.selectedDates.isEmpty && !vacationData.isSubmitted {
                            Button(action: submitVacation) {
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

                        if !vacationData.selectedDates.isEmpty {
                            Button(action: clearCurrentSelection) {
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
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.black)
                            .padding(20)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.25), radius: 15, x: 0, y: 8)
                            )
                    }
                }
            }
            .padding(.bottom, 30)
            .padding(.trailing, 30)
        }
    }

    // MARK: - 輔助方法
    private func submitVacation() {
        vacationData.isSubmitted = true
        vacationData.currentMonth = getCurrentMonthString()
        saveVacationData()
        showToast("排休已成功提交！", type: .success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                isVacationEditMode = false
            }
        }
    }

    private func clearCurrentSelection() {
        vacationData.selectedDates.removeAll()
        saveVacationData()
    }

    private func getCurrentMonthString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    private func showToast(_ message: String, type: ToastView.ToastType) {
        toastMessage = message
        toastType = type
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isToastShowing = true
        }
    }

    private func saveVacationData() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(vacationData) {
            UserDefaults.standard.set(encoded, forKey: "VacationData_\(getCurrentMonthString())")
        }
    }

    private func loadVacationData() {
        let key = "VacationData_\(getCurrentMonthString())"
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(VacationData.self, from: data) {
            vacationData = decoded
        }
    }
}

#Preview {
    EmployeeCalendarView()
}
