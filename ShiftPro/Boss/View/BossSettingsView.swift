//
//  BossSettingsView.swift
//  ShiftPro
//
//  完全修復版本：自動關閉Sheet + 正確狀態同步
//

import SwiftUI

struct BossSettingsView: View {
    // MARK: - Properties
    @State private var monthlyLimit: Int = 8
    @State private var weeklyLimit: Int = 2
    @State private var vacationType: VacationType = .monthly
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var showingSuccessAlert = false
    @State private var showingDatePicker = false
    @State private var alertMessage = ""

    // 🔥 新增：用於關閉 Sheet 的 Binding
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView()

                ScrollView {
                    VStack(spacing: 24) {
                        dateSelectionCard()
                        vacationTypeCard()
                        limitsSettingCard()
                        currentSettingsPreview()
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
                // 🔥 點擊確定後關閉 Sheet
                dismiss()
            }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingDatePicker) {
            BossDatePickerSheet(
                selectedYear: $selectedYear,
                selectedMonth: $selectedMonth,
                isPresented: $showingDatePicker
            )
        }
    }

    // MARK: - Header View
    private func headerView() -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("休假設定發佈")
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
                    Text(String(format: "%04d年%02d月", selectedYear, selectedMonth))
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
                previewRow("calendar.circle", "目標月份", String(format: "%04d年%02d月", selectedYear, selectedMonth))
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

    // MARK: - Publish Button
    private func publishButton() -> some View {
        Button(action: publishVacationSettings) {
            HStack(spacing: 12) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18, weight: .semibold))

                Text("發佈排休設定")
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
    }

    // MARK: - Helper Methods
    private func loadCurrentSettings() {
        let limits = VacationLimitsManager.shared.getVacationLimits(for: selectedYear, month: selectedMonth)

        if let monthlyLimit = limits.monthlyLimit {
            self.monthlyLimit = monthlyLimit
        }
        if let weeklyLimit = limits.weeklyLimit {
            self.weeklyLimit = weeklyLimit
        }

        self.vacationType = limits.vacationType
    }

    private func publishVacationSettings() {
        print("🚀 開始發佈排休設定...")

        let limits = VacationLimits(
            monthlyLimit: vacationType == .monthly ? monthlyLimit : nil,
            weeklyLimit: weeklyLimit,
            year: selectedYear,
            month: selectedMonth,
            isPublished: true,
            publishedDate: Date(),
            vacationType: vacationType
        )

        print("📦 即將發佈的設定:")
        print("   月份: \(selectedYear)-\(selectedMonth)")
        print("   類型: \(vacationType.rawValue)")
        print("   月限制: \(limits.monthlyLimit ?? 0)")
        print("   週限制: \(limits.weeklyLimit ?? 0)")
        print("   已發佈: \(limits.isPublished)")

        let success = VacationLimitsManager.shared.saveVacationLimitsWithNotification(limits)
        if success {
            alertMessage = "排休設定已成功發佈給員工！\n\n目標月份: \(String(format: "%04d年%02d月", selectedYear, selectedMonth))\n排休類型: \(vacationType.displayName)\n限制天數: \(vacationType == .monthly ? monthlyLimit : weeklyLimit) 天\n\n員工現在可以開始排休了！"
            showingSuccessAlert = true
            print("✅ 發佈成功！員工端應該收到通知")

            // 🔥 發佈成功後延遲關閉 Sheet（如果用戶沒有點擊確定）
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if showingSuccessAlert {
                    showingSuccessAlert = false
                    dismiss()
                }
            }
        } else {
            alertMessage = "發佈失敗，請重試"
            showingSuccessAlert = true
            print("❌ 發佈失敗！")
        }
    }
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
                                Text("\(year)")
                                    .font(.system(size: 20, weight: .medium))
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
