//
//  BossSettingsView.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/11.
//

import SwiftUI
import Combine

struct BossSettingsView: View {
    // MARK: - State Properties
    @State private var monthlyLimit: Int = 8
    @State private var weeklyLimit: Int = 2
    @State private var vacationType: VacationType = .monthly
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var showingSuccessAlert = false
    @State private var showingDatePicker = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var showingUnpublishAlert = false

    // 🔥 新增：Firebase 狀態追蹤
    @State private var currentFirebaseRule: FirestoreVacationRule?
    @State private var hasExistingRule = false
    @State private var isPublished = false

    @Environment(\.dismiss) private var dismiss
    private let scheduleService = ScheduleService.shared
    private let userManager = UserManager.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView()

                ScrollView {
                    VStack(spacing: 24) {
                        dateSelectionCard()

                        // 🔥 新增：現有設定狀態卡片
                        if hasExistingRule {
                            existingRuleCard()
                        }

                        vacationTypeCard()
                        limitsSettingCard()
                        currentSettingsPreview()

                        // 🔥 優化：動態按鈕
                        if hasExistingRule && isPublished {
                            unpublishButton()
                        }

                        publishButton()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
            }
        }
        .onAppear {
            loadCurrentSettings()
        }
        .onChange(of: selectedYear) { _, _ in
            loadCurrentSettings()
        }
        .onChange(of: selectedMonth) { _, _ in
            loadCurrentSettings()
        }
        .alert("發佈完成", isPresented: $showingSuccessAlert) {
            Button("確定") {
                dismiss()
            }
        } message: {
            Text(alertMessage)
        }
        .alert("取消發佈", isPresented: $showingUnpublishAlert) {
            Button("取消", role: .cancel) { }
            Button("確認取消發佈", role: .destructive) {
                unpublishVacationSettings()
            }
        } message: {
            Text("確定要取消發佈排休設定嗎？這將清除該月份的所有設定。")
        }
        .sheet(isPresented: $showingDatePicker) {
            BossDatePickerSheet(
                selectedYear: $selectedYear,
                selectedMonth: $selectedMonth,
                isPresented: $showingDatePicker
            )
        }
        .overlay {
            if isLoading {
                loadingOverlay()
            }
        }
    }

    // MARK: - Header View
    private func headerView() -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("休假設定管理")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text("設定並發佈員工排休規則")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                    Text("管理者")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.yellow)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.yellow.opacity(0.2))
                .cornerRadius(20)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 45)
        .padding(.bottom, 16)
    }

    // MARK: - Date Selection Card
    private func dateSelectionCard() -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "calendar.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)

                Text("設定目標月份")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()
            }

            Button(action: { showingDatePicker = true }) {
                HStack {
                    // 🔥 修復問題3：直接使用字串轉換
                    Text("\(String(selectedYear))年\(String(format: "%02d", selectedMonth))月")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    // MARK: - 🔥 新增：現有規則卡片
    private func existingRuleCard() -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: isPublished ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(isPublished ? .green : .orange)

                Text("當前設定狀態")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Text(isPublished ? "已發佈" : "已設定未發佈")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isPublished ? .green : .orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background((isPublished ? Color.green : Color.orange).opacity(0.2))
                    .cornerRadius(12)
            }

            if let rule = currentFirebaseRule {
                VStack(spacing: 8) {
                    existingRuleRow("排休類型", VacationType(rawValue: rule.type)?.displayName ?? "未知")

                    if let monthlyLimit = rule.monthlyLimit {
                        existingRuleRow("月休限制", "\(monthlyLimit) 天")
                    }

                    if let weeklyLimit = rule.weeklyLimit {
                        existingRuleRow("週休限制", "\(weeklyLimit) 天")
                    }

                    existingRuleRow("發佈狀態", rule.published ? "已發佈給員工" : "尚未發佈")
                }
                .padding(16)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
            }
        }
        .padding(20)
        .background((isPublished ? Color.green : Color.orange).opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke((isPublished ? Color.green : Color.orange).opacity(0.3), lineWidth: 1)
        )
    }

    private func existingRuleRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
    }

    // MARK: - Vacation Type Card
    private func vacationTypeCard() -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)

                Text("排休類型")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()
            }

            VStack(spacing: 12) {
                vacationTypeOption(.weekly, "週排休", "每週固定休假天數", "calendar.day.timeline.leading")
                vacationTypeOption(.monthly, "月排休", "每月總休假天數", "calendar.badge.checkmark")
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private func vacationTypeOption(_ type: VacationType, _ title: String, _ description: String, _ icon: String) -> some View {
        let isSelected = vacationType == type

        return Button(action: {
            vacationType = type
            if type == .weekly {
                weeklyLimit = 2
                monthlyLimit = 8
            } else {
                monthlyLimit = 8
                weeklyLimit = 2
            }
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .blue : .gray)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Limits Setting Card
    private func limitsSettingCard() -> some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "number.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)

                Text("天數設定")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()
            }

            if vacationType == .monthly {
                limitCard(
                    title: "月休天數",
                    subtitle: "每月最多可休天數",
                    icon: "calendar.badge.checkmark",
                    value: $monthlyLimit,
                    range: 1...31,
                    color: .blue
                )
            } else {
                limitCard(
                    title: "週休天數",
                    subtitle: "每週最多可休天數",
                    icon: "calendar.day.timeline.leading",
                    value: $weeklyLimit,
                    range: 1...7,
                    color: .green
                )
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private func limitCard(
        title: String,
        subtitle: String,
        icon: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        color: Color
    ) -> some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }

            HStack(spacing: 20) {
                Button(action: {
                    if value.wrappedValue > range.lowerBound {
                        value.wrappedValue -= 1
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(value.wrappedValue > range.lowerBound ? color : .gray)
                }
                .disabled(value.wrappedValue <= range.lowerBound)

                VStack(spacing: 4) {
                    Text("\(value.wrappedValue)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)

                    Text("天")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(minWidth: 80)

                Button(action: {
                    if value.wrappedValue < range.upperBound {
                        value.wrappedValue += 1
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(value.wrappedValue < range.upperBound ? color : .gray)
                }
                .disabled(value.wrappedValue >= range.upperBound)
            }
        }
    }

    // MARK: - Current Settings Preview
    private func currentSettingsPreview() -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "eye.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.purple)

                Text("設定預覽")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()
            }

            VStack(spacing: 12) {
                // 🔥 修復問題3：預覽中的年月顯示
                previewRow("calendar.circle", "目標月份", "\(String(selectedYear))年\(String(format: "%02d", selectedMonth))月")
                previewRow("calendar.badge.checkmark", "排休類型", vacationType.displayName)

                if vacationType == .monthly {
                    previewRow("number.circle", "月休限制", "\(monthlyLimit) 天")
                } else {
                    previewRow("number.circle", "週休限制", "\(weeklyLimit) 天")
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private func previewRow(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.purple)
                .frame(width: 24)

            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    // MARK: - 🔥 新增：取消發佈按鈕
    private func unpublishButton() -> some View {
        Button(action: {
            showingUnpublishAlert = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 18, weight: .semibold))

                Text("取消發佈設定")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.red, Color.red.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: .red.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .disabled(isLoading)
    }

    // MARK: - Publish Button
    private func publishButton() -> some View {
        Button(action: publishVacationSettings) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: hasExistingRule ? "arrow.clockwise" : "paperplane.fill")
                        .font(.system(size: 18, weight: .semibold))
                }

                Text(hasExistingRule ? "更新並發佈設定" : "發佈排休設定")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: .blue.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .disabled(isLoading)
    }

    // MARK: - Loading Overlay
    private func loadingOverlay() -> some View {
        ZStack {
            Color.black.opacity(0.5)
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

    // MARK: - 🔥 優化：載入當前設定
    private func loadCurrentSettings() {
        print("🔍 Boss Settings 載入當前設定...")

        isLoading = true

        scheduleService.fetchVacationRule(
            orgId: userManager.currentOrgId,
            month: String(format: "%04d-%02d", selectedYear, selectedMonth)
        )
        .sink(
            receiveCompletion: { [self] completion in
                DispatchQueue.main.async {
                    self.isLoading = false
                    switch completion {
                    case .failure(let error):
                        print("❌ 載入設定失敗: \(error)")
                    case .finished:
                        break
                    }
                }
            },
            receiveValue: { [self] rule in
                DispatchQueue.main.async {
                    if let rule = rule {
                        print("✅ 載入到現有設定")
                        self.currentFirebaseRule = rule
                        self.hasExistingRule = true
                        self.isPublished = rule.published

                        // 載入設定值
                        if let monthlyLimit = rule.monthlyLimit {
                            self.monthlyLimit = monthlyLimit
                        }
                        if let weeklyLimit = rule.weeklyLimit {
                            self.weeklyLimit = weeklyLimit
                        }
                        if let vacationType = VacationType(rawValue: rule.type) {
                            self.vacationType = vacationType
                        }
                    } else {
                        print("📱 該月份無現有設定")
                        self.currentFirebaseRule = nil
                        self.hasExistingRule = false
                        self.isPublished = false
                    }
                }
            }
        )
        .store(in: &cancellables)
    }

    // MARK: - 🔥 優化：發佈排休設定
    func publishVacationSettings() {
        print("🚀 Boss Settings 發佈排休設定...")

        isLoading = true

        let monthString = String(format: "%04d-%02d", selectedYear, selectedMonth)

        scheduleService.updateVacationRule(
            orgId: userManager.currentOrgId,
            month: monthString,
            type: vacationType.rawValue,
            monthlyLimit: vacationType == .monthly ? monthlyLimit : nil,
            weeklyLimit: vacationType == .weekly ? weeklyLimit : nil,
            published: true
        )
        .sink(
            receiveCompletion: { [self] completion in
                DispatchQueue.main.async {
                    self.isLoading = false
                    switch completion {
                    case .failure(let error):
                        print("❌ Boss Settings 發佈失敗: \(error)")
                        self.alertMessage = "發佈失敗，請檢查網絡連接後重試"
                        self.showingSuccessAlert = true
                    case .finished:
                        break
                    }
                }
            },
            receiveValue: { [self] in
                DispatchQueue.main.async {
                    print("✅ Boss Settings 發佈成功！")

                    self.alertMessage = """
                    排休設定已成功發佈！
                    
                    目標月份: \(String(self.selectedYear))年\(String(format: "%02d", self.selectedMonth))月
                    排休類型: \(self.vacationType.displayName)
                    限制天數: \(self.vacationType == .monthly ? self.monthlyLimit : self.weeklyLimit) 天
                    
                    員工現在可以開始排休了！
                    """
                    self.showingSuccessAlert = true

                    // 發送通知
                    NotificationCenter.default.post(
                        name: Notification.Name("BossSettingsPublished"),
                        object: nil,
                        userInfo: ["month": monthString]
                    )
                }
            }
        )
        .store(in: &cancellables)
    }

    // MARK: - 🔥 新增：取消發佈
    private func unpublishVacationSettings() {
        print("🗑️ Boss Settings 取消發佈...")

        isLoading = true

        let monthString = String(format: "%04d-%02d", selectedYear, selectedMonth)

        scheduleService.deleteVacationRule(
            orgId: userManager.currentOrgId,
            month: monthString
        )
        .sink(
            receiveCompletion: { [self] completion in
                DispatchQueue.main.async {
                    self.isLoading = false
                    switch completion {
                    case .failure(let error):
                        print("❌ Boss Settings 取消發佈失敗: \(error)")
                        self.alertMessage = "取消發佈失敗，請重試"
                        self.showingSuccessAlert = true
                    case .finished:
                        break
                    }
                }
            },
            receiveValue: { [self] in
                DispatchQueue.main.async {
                    print("✅ Boss Settings 取消發佈成功")

                    self.alertMessage = "已成功取消發佈排休設定"
                    self.showingSuccessAlert = true

                    // 重置狀態
                    self.currentFirebaseRule = nil
                    self.hasExistingRule = false
                    self.isPublished = false

                    // 發送通知
                    NotificationCenter.default.post(
                        name: Notification.Name("VacationRuleUnpublished"),
                        object: nil,
                        userInfo: [
                            "orgId": self.userManager.currentOrgId,
                            "month": monthString
                        ]
                    )
                }
            }
        )
        .store(in: &cancellables)
    }

    // MARK: - Private Properties
    @State private var cancellables = Set<AnyCancellable>()
}

// MARK: - Boss Date Picker Sheet
struct BossDatePickerSheet: View {
    @Binding var selectedYear: Int
    @Binding var selectedMonth: Int
    @Binding var isPresented: Bool

    private let years = Array(2024...2030)
    private let months = Array(1...12)

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("選擇目標月份")
                    .font(.system(size: 24, weight: .bold))
                    .padding(.top, 20)

                HStack(spacing: 40) {
                    VStack {
                        Text("年")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.gray)

                        Picker("年", selection: $selectedYear) {
                            ForEach(years, id: \.self) { year in
                                // 🔥 修復問題3：直接使用字串轉換
                                Text(String(year))
                                    .font(.system(size: 20, weight: .medium))
                                    .tag(year)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(width: 120, height: 150)
                    }

                    VStack {
                        Text("月")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.gray)

                        Picker("月", selection: $selectedMonth) {
                            ForEach(months, id: \.self) { month in
                                Text("\(month)")
                                    .font(.system(size: 20, weight: .medium))
                                    .tag(month)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(width: 120, height: 150)
                    }
                }

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("確定") {
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    BossSettingsView()
}
