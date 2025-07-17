//
//  BossCalendarViewModel.swift
//  ShiftPro
//
//  支援動態月份切換的版本
//

import Foundation
import SwiftUI
import Combine

class BossCalendarViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var currentVacationMode: VacationMode = .monthly
    @Published var toastMessage = ""
    @Published var toastType: ToastType = .info
    @Published var isToastShowing = false
    @Published var isVacationPublished = false
    @Published var isSchedulePublished = false

    // 🔥 新增：當前顯示的月份
    @Published var currentDisplayMonth: String = ""

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init() {
        // 初始化為當前月份
        currentDisplayMonth = getCurrentMonthString()
        setupNotifications()
        loadPublishStatus()
        print("🏢 老闆端ViewModel初始化完成 - 當前月份: \(currentDisplayMonth)")
    }

    deinit {
        cancellables.removeAll()
    }

    // MARK: - 🔥 新增：月份切換方法
    func updateDisplayMonth(year: Int, month: Int) {
        let newMonth = String(format: "%04d-%02d", year, month)
        if newMonth != currentDisplayMonth {
            print("📅 老闆端切換到月份: \(newMonth)")
            currentDisplayMonth = newMonth

            // 重新加載該月份的發佈狀態
            loadPublishStatus()
        }
    }

    // MARK: - Current Month Info
    var currentMonthLimits: VacationLimits {
        let components = currentDisplayMonth.split(separator: "-")
        let year = Int(components[0]) ?? Calendar.current.component(.year, from: Date())
        let month = Int(components[1]) ?? Calendar.current.component(.month, from: Date())
        return VacationLimitsManager.shared.getVacationLimits(for: year, month: month)
    }

    // MARK: - Boss Actions
    func handleBossAction(_ action: BossAction) {
        switch action {
        case .publishVacation:
            break
        case .publishSchedule:
            break
        case .unpublishVacation:
            unpublishVacationSchedule()
        case .unpublishSchedule:
            unpublishWorkSchedule()
        case .manageVacationLimits:
            break
        }
    }

    // MARK: - Publish Methods
    func publishVacationSetting(_ setting: VacationSetting) {
        let limits = setting.toVacationLimits()
        let success = VacationLimitsManager.shared.saveVacationLimitsWithNotification(limits)

        if success {
            saveVacationSetting(setting)
            isVacationPublished = true
            savePublishStatus()
            showToast("發佈排休成功！員工已收到排休設定", type: .success)
        } else {
            showToast("發佈排休失敗，請重試", type: .error)
        }
    }

    func publishSchedule(_ scheduleData: ScheduleData) {
        saveScheduleData(scheduleData)
        isSchedulePublished = true
        savePublishStatus()
        showToast("發佈班表成功！員工已收到班表", type: .success)
    }

    // MARK: - Unpublish Methods
    private func unpublishVacationSchedule() {
        let components = currentDisplayMonth.split(separator: "-")
        let year = Int(components[0]) ?? Calendar.current.component(.year, from: Date())
        let month = Int(components[1]) ?? Calendar.current.component(.month, from: Date())

        let deleteSuccess = VacationLimitsManager.shared.deleteLimits(for: year, month: month)

        if deleteSuccess {
            isVacationPublished = false
            savePublishStatus()
            showToast("排休計劃已取消發佈", type: .warning)
            print("✅ 成功刪除 \(year)-\(month) 的排休設定")
        } else {
            showToast("取消發佈失敗，請重試", type: .error)
            print("❌ 刪除 \(year)-\(month) 的排休設定失敗")
        }
    }

    private func unpublishWorkSchedule() {
        isSchedulePublished = false
        savePublishStatus()
        showToast("工作班表已取消發佈", type: .warning)
    }

    // MARK: - Status Properties
    var vacationStatusText: String {
        return isVacationPublished ? "已發佈" : "未發佈"
    }

    var scheduleStatusText: String {
        return isSchedulePublished ? "已發佈" : "未發佈"
    }

    var vacationStatusColor: Color {
        return isVacationPublished ? .green : .orange
    }

    var scheduleStatusColor: Color {
        return isSchedulePublished ? .green : .orange
    }

    // MARK: - Helper Methods
    func formatMonthString(_ monthString: String) -> String {
        let components = monthString.split(separator: "-")
        if components.count == 2,
           let year = Int(components[0]),
           let month = Int(components[1]) {
            return "\(year)年\(month)月"
        }
        return monthString
    }

    func getCurrentMonthString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    func showToast(_ message: String, type: ToastType) {
        toastMessage = message
        toastType = type
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isToastShowing = true
        }
    }

    // MARK: - Data Persistence
    private func saveVacationSetting(_ setting: VacationSetting) {
        let key = "VacationSetting_\(currentDisplayMonth)"
        if let encoded = try? JSONEncoder().encode(setting) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    private func saveScheduleData(_ scheduleData: ScheduleData) {
        let key = "ScheduleData_\(currentDisplayMonth)"
        if let encoded = try? JSONEncoder().encode(scheduleData) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    func savePublishStatus() {
        let status = BossPublishStatus(
            vacationPublished: isVacationPublished,
            schedulePublished: isSchedulePublished,
            month: currentDisplayMonth
        )

        let key = "BossPublishStatus_\(currentDisplayMonth)"
        if let encoded = try? JSONEncoder().encode(status) {
            UserDefaults.standard.set(encoded, forKey: key)
        }

        print("💾 老闆端狀態已保存 (\(currentDisplayMonth)):")
        print("   排休發佈: \(isVacationPublished)")
        print("   班表發佈: \(isSchedulePublished)")
    }

    // 🔥 修復：基於當前顯示月份載入發佈狀態
    private func loadPublishStatus() {
        let key = "BossPublishStatus_\(currentDisplayMonth)"
        if let data = UserDefaults.standard.data(forKey: key),
           let status = try? JSONDecoder().decode(BossPublishStatus.self, from: data) {
            isVacationPublished = status.vacationPublished
            isSchedulePublished = status.schedulePublished
            print("📖 從 UserDefaults 載入老闆端狀態 (\(currentDisplayMonth)):")
        } else {
            // 🔥 重要：檢查 VacationLimitsManager 中的發佈狀態
            let components = currentDisplayMonth.split(separator: "-")
            let year = Int(components[0]) ?? Calendar.current.component(.year, from: Date())
            let month = Int(components[1]) ?? Calendar.current.component(.month, from: Date())

            isVacationPublished = VacationLimitsManager.shared.hasLimitsForMonth(year: year, month: month)
            isSchedulePublished = false // 班表狀態保持默認
            print("📖 從 VacationLimitsManager 載入老闆端狀態 (\(currentDisplayMonth)):")
        }

        print("   排休發佈: \(isVacationPublished)")
        print("   班表發佈: \(isSchedulePublished)")
    }

    // 🔥 強化：監聽通知並更新狀態
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .vacationLimitsDidUpdate)
            .sink { [weak self] notification in
                print("📬 老闆端收到休假設定更新通知")

                // 如果通知是關於當前顯示月份的，重新載入狀態
                if let userInfo = notification.userInfo,
                   let targetMonth = userInfo["targetMonth"] as? String,
                   targetMonth == self?.currentDisplayMonth {
                    print("🎯 更新當前顯示月份的狀態")
                    self?.loadPublishStatus()
                }

                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
