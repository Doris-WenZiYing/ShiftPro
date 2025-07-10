//
//  EmployeeCalendarView.swift (完整重構版)
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

    // 排休模式選擇
    @State private var currentVacationMode: VacationMode = .monthly
    @State private var isVacationModeMenuPresented = false
    @State private var isMenuPresented = false

    // 排班月份限制 - 使用當前月份
    @State private var availableVacationMonth: String = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date.now)
    }()
    @State private var availableVacationDays: Int = 4
    @State private var weeklyVacationLimit: Int = 2

    // 日期選擇器狀態
    @State private var isDatePickerPresented = false
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            if isVacationEditMode {
                editModeCalendarView()
            } else {
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

            // 自定義菜單覆蓋層
            if isMenuPresented {
                CustomMenuOverlay(
                    isPresented: $isMenuPresented,
                    currentVacationMode: $currentVacationMode,
                    isVacationModeMenuPresented: $isVacationModeMenuPresented
                )
                .zIndex(4)
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
        .sheet(isPresented: $isDatePickerPresented) {
            EnhancedDatePickerSheet(
                selectedYear: $selectedYear,
                selectedMonth: $selectedMonth,
                isPresented: $isDatePickerPresented,
                controller: controller
            )
        }
        .sheet(isPresented: $isVacationModeMenuPresented) {
            VacationModeSelectionSheet(
                currentMode: $currentVacationMode,
                weeklyLimit: $weeklyVacationLimit,
                monthlyLimit: $availableVacationDays,
                isPresented: $isVacationModeMenuPresented
            )
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

                    calendarGridView(month: month, cellHeight: cellHeight)
                }
            }
        }
    }

    // MARK: - 編輯模式簡化月曆
    private func editModeCalendarView() -> some View {
        VStack(spacing: 0) {
            editModeHeader()

            GeometryReader { geometry in
                let availableHeight = geometry.size.height
                let cellHeight = max((availableHeight - 30) / 6, 80)

                VStack(spacing: 0) {
                    editModeWeekdayHeaders()
                    editModeCalendarGrid(cellHeight: cellHeight)
                }
            }

            editModeBottomInfo()
        }
    }

    // MARK: - View Components
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

            let currentDisplayMonth = String(format: "%04d-%02d", month.year, month.month)
            if currentDisplayMonth == availableVacationMonth && !isVacationEditMode {
                HStack(spacing: 6) {
                    Image(systemName: vacationData.isSubmitted ? "checkmark.circle.fill" : "calendar.badge.checkmark")
                        .font(.system(size: 12))
                        .foregroundColor(vacationData.isSubmitted ? .green : .blue)  // 已排休：綠色，可排休：藍色
                    Text(vacationData.isSubmitted ? "已排休" : "可排休")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(vacationData.isSubmitted ? .green : .blue)  // 已排休：綠色，可排休：藍色
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background((vacationData.isSubmitted ? Color.green : Color.blue).opacity(0.2))  // 背景也跟著變色
                .cornerRadius(16)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    private func topButtonsOverlay() -> some View {
        VStack {
            HStack {
                Spacer()
                Button(action: {
                    // TODO: share section
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isMenuPresented.toggle()
                    }
                }) {
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

    // MARK: - Helper Methods (保留核心邏輯)
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

    private func formatMonthString(_ monthString: String) -> String {
        let components = monthString.split(separator: "-")
        if components.count == 2,
           let year = Int(components[0]),
           let month = Int(components[1]) {
            return "\(year)年\(month)月"
        }
        return monthString
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

// MARK: - Calendar Grid and Cell Logic (移動到擴展中保持代碼整潔)
extension EmployeeCalendarView {

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

    private func calendarGridView(month: CalendarMonth, cellHeight: CGFloat) -> some View {
        let dates = month.getDaysInMonth(offset: 0)
        let gridItems = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

        return LazyVGrid(columns: gridItems, alignment: .center, spacing: 2) {
            ForEach(0..<42, id: \.self) { index in
                normalModeCalendarCell(date: dates[index], month: month, cellHeight: cellHeight)
            }
        }
        .background(Color.black)
        .padding(.horizontal, 8)
        .drawingGroup()
    }

    private func normalModeCalendarCell(date: CalendarDate, month: CalendarMonth, cellHeight: CGFloat) -> some View {
        let dateString = dateToString(date)
        let isSelected = controller.isDateSelected(date)
        let isVacationSelected = vacationData.isDateSelected(dateString) && date.isCurrentMonth == true

        return ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.05))
                .frame(height: cellHeight)

            if isSelected && !isVacationEditMode {
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
                    .foregroundColor(textColor(for: date, isSelected: isSelected, isVacationSelected: isVacationSelected))
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

    private func textColor(for date: CalendarDate, isSelected: Bool, isVacationSelected: Bool) -> Color {
        if isVacationSelected {
            return .white
        } else if isSelected && !isVacationEditMode {
            return .black
        } else if date.isCurrentMonth == true {
            return .white
        } else {
            return isSelected ? .black : .gray.opacity(0.4)
        }
    }

    private func dateToString(_ date: CalendarDate) -> String {
        return String(format: "%04d-%02d-%02d", date.year, date.month, date.day)
    }
}

// MARK: - Edit Mode Views (編輯模式相關視圖)
extension EmployeeCalendarView {

    private func editModeHeader() -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("排休編輯")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        Text(formatMonthString(availableVacationMonth))
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))

                        Text("•")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))

                        Text(currentVacationMode.rawValue)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue.opacity(0.9))
                    }
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

            HStack(spacing: 12) {
                infoCard(
                    title: vacationData.isSubmitted ? "已排休" : "可排休",
                    value: "\(availableVacationDays) 天",
                    icon: vacationData.isSubmitted ? "checkmark.circle.fill" : "calendar.badge.clock",
                    color: vacationData.isSubmitted ? .green : .blue
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
        .padding(.top, 45)
        .padding(.bottom, 16)
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

    private func editModeWeekdayHeaders() -> some View {
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

    private func editModeCalendarCell(day: Int, cellHeight: CGFloat) -> some View {
        let dateString = String(format: "%@-%02d", availableVacationMonth, day)
        let isVacationSelected = vacationData.isDateSelected(dateString)
        let canSelect = canSelectForCurrentMode(day: day)

        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6).opacity(0.3))
                .frame(height: cellHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray5).opacity(0.2), lineWidth: 1)
                )

            if shouldShowWeeklyHint(day: day, canSelect: canSelect, isSelected: isVacationSelected) {
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
            toggleVacationDate(dateString: dateString)
        }
    }

    private func editModeBottomInfo() -> some View {
        VStack(spacing: 8) {
            if !vacationData.selectedDates.isEmpty {
                Text("已選擇: \(vacationData.selectedDates.count) 天")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 15)
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
}

// MARK: - Vacation Logic (排休邏輯)
extension EmployeeCalendarView {

    private func canSelectForCurrentMode(day: Int) -> Bool {
        switch currentVacationMode {
        case .monthly:
            return true
        case .weekly, .monthlyWithWeeklyLimit:
            return canSelectForWeeklyLimit(day: day)
        }
    }

    private func shouldShowWeeklyHint(day: Int, canSelect: Bool, isSelected: Bool) -> Bool {
        switch currentVacationMode {
        case .monthly:
            return false
        case .weekly, .monthlyWithWeeklyLimit:
            return canSelect && !isSelected
        }
    }

    private func canSelectForWeeklyLimit(day: Int) -> Bool {
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

        return selectedInSameWeek.count < weeklyVacationLimit
    }

    private func toggleVacationDate(dateString: String) {
        if vacationData.isSubmitted {
            showToast("已提交排休，無法修改", type: .error)
            return
        }

        var newVacationData = vacationData

        if newVacationData.isDateSelected(dateString) {
            newVacationData.removeDate(dateString)
        } else {
            if newVacationData.selectedDates.count >= availableVacationDays {
                showToast("已超過可排休天數上限 (\(availableVacationDays) 天)", type: .error)
                return
            }

            if currentVacationMode == .weekly || currentVacationMode == .monthlyWithWeeklyLimit {
                let day = Int(dateString.suffix(2)) ?? 1
                if !canSelectForWeeklyLimit(day: day) {
                    showToast("已超過本週排休上限 (\(weeklyVacationLimit) 天)", type: .error)
                    return
                }
            }

            newVacationData.addDate(dateString)
        }

        vacationData = newVacationData
        saveVacationData()
    }
}

#Preview {
    EmployeeCalendarView()
}
