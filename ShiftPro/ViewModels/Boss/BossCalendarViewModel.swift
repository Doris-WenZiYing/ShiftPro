//
//  BossCalendarViewModel.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/11.
//

import Foundation
import Combine
import SwiftUI

class BossCalendarViewModel: ObservableObject {
    // MARK: - Published
    @Published var currentVacationMode: VacationMode = .monthly
    @Published var isVacationPublished = false
    @Published var isSchedulePublished = false
    @Published var toastMessage = ""
    @Published var toastType: ToastType = .info
    @Published var isToastShowing = false
    @Published var currentDisplayMonth: String

    // MARK: - Dependencies
    private let scheduleService: ScheduleService
    private let storage: LocalStorageService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init(
        scheduleService: ScheduleService = .shared,
        storage: LocalStorageService = .shared
    ) {
        self.scheduleService = scheduleService
        self.storage = storage

        // Initialize currentDisplayMonth
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        self.currentDisplayMonth = formatter.string(from: Date())

        // load saved publish status
        loadPublishStatus()
    }

    deinit {
        cancellables.forEach { $0.cancel() }
    }

    // MARK: - Month
    func updateDisplayMonth(year: Int, month: Int) {
        let newM = String(format: "%04d-%02d", year, month)
        guard newM != currentDisplayMonth else { return }
        currentDisplayMonth = newM
        loadPublishStatus()
    }

    // MARK: - Publish Vacation
    func publishVacationSetting(_ setting: VacationSetting) {
        scheduleService.updateVacationRule(
            orgId: orgId,
            month: currentDisplayMonth,
            type: setting.type.rawValue,
            monthlyLimit: setting.allowedDays,
            weeklyLimit: setting.type == .weekly ? setting.allowedDays : nil,
            published: true
        )
        .sink { [weak self] completion in
            switch completion {
            case .failure:
                self?.showToast("發佈失敗，請重試", type: .error)
            case .finished:
                break
            }
        } receiveValue: { [weak self] in
            self?.isVacationPublished = true
            self?.savePublishStatus()
            self?.showToast("發佈排休成功！", type: .success)
        }
        .store(in: &cancellables)
    }

    func unpublishVacation() {
        scheduleService.deleteVacationRule(orgId: orgId, month: currentDisplayMonth)
            .sink { [weak self] completion in
                switch completion {
                case .failure:
                    self?.showToast("取消發佈失敗", type: .error)
                case .finished:
                    break
                }
            } receiveValue: { [weak self] in
                self?.isVacationPublished = false
                self?.savePublishStatus()
                self?.showToast("取消發佈成功", type: .warning)
            }
            .store(in: &cancellables)
    }

    // MARK: - Helpers

    var vacationStatusText: String {
        isVacationPublished ? "已發佈" : "未發佈"
    }

    var vacationStatusColor: Color {
        isVacationPublished ? .green : .orange
    }

    var scheduleStatusText: String {
        isSchedulePublished ? "已發佈" : "未發佈"
    }

    var scheduleStatusColor: Color {
        isSchedulePublished ? .green : .orange
    }

    // MARK: - Schedule Management

    /// 發佈班表
    func publishSchedule(_ scheduleData: ScheduleData) {
        // TODO: 實作班表發佈邏輯
        // 這裡可以將班表資料同步到 Firebase
        isSchedulePublished = true
        showToast("班表發佈成功！", type: .success)
    }

    /// 處理老闆操作
    func handleBossAction(_ action: BossAction) {
        switch action {
        case .publishVacation:
            // 處理發佈休假設定
            break
        case .unpublishVacation:
            // 處理取消發佈休假設定
            unpublishVacation()
        case .publishSchedule:
            // 處理發佈班表 (這個會在 View 中直接處理)
            break
        case .unpublishSchedule:
            // 處理取消發佈班表
            unpublishSchedule()
        case .manageVacationLimits:
            // 處理管理休假限制 (這個會在 View 中直接處理)
            break
        default:
            break
        }
    }

    /// 取消發佈班表
    func unpublishSchedule() {
        // TODO: 實作取消發佈班表邏輯
        isSchedulePublished = false
        showToast("班表已取消發佈", type: .warning)
    }

    private func loadPublishStatus() {
        let key = "BossPublishStatus_\(currentDisplayMonth)"
        if let data = UserDefaults.standard.data(forKey: key),
           let status = try? JSONDecoder().decode(BossPublishStatus.self, from: data) {
            isVacationPublished = status.vacationPublished
            isSchedulePublished = status.schedulePublished
        } else {
            // fallback: check Firestore
            scheduleService.fetchVacationRule(orgId: orgId, month: currentDisplayMonth)
                .replaceError(with: nil)
                .sink { [weak self] rule in
                    DispatchQueue.main.async {
                        self?.isVacationPublished = (rule?.published ?? false)
                    }
                }
                .store(in: &cancellables)
        }
    }

    private func savePublishStatus() {
        let status = BossPublishStatus(
            vacationPublished: isVacationPublished,
            schedulePublished: isSchedulePublished,
            month: currentDisplayMonth
        )
        let key = "BossPublishStatus_\(currentDisplayMonth)"
        if let encoded = try? JSONEncoder().encode(status) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    func showToast(_ msg: String, type: ToastType) {
        toastMessage = msg
        toastType = type
        withAnimation { isToastShowing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + (type == .error ? 5 : 3)) {
            withAnimation { self.isToastShowing = false }
        }
    }

    // MARK: - Read from UserDefaults
    private var orgId: String {
        UserDefaults.standard.string(forKey: "orgId") ?? "demo_store_01"
    }
}

// MARK: - Supporting Models
struct BossPublishStatus: Codable {
    let vacationPublished: Bool
    let schedulePublished: Bool
    let month: String
}
