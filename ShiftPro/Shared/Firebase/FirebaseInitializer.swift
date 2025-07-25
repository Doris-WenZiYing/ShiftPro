//
//  FirebaseInitializer.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/25.
//

import Foundation
import Combine

class FirebaseInitializer: ObservableObject {
    static let shared = FirebaseInitializer()

    private let scheduleService: ScheduleService
    private var cancellables = Set<AnyCancellable>()

    @Published var isInitializing = false
    @Published var initializationProgress: String = ""

    private init(scheduleService: ScheduleService = .shared) {
        self.scheduleService = scheduleService
    }

    // MARK: - 一鍵初始化所有測試數據
    func initializeAllTestData() {
        guard !isInitializing else { return }

        isInitializing = true
        initializationProgress = "開始初始化 Firebase 數據..."

        print("🚀 開始初始化 Firebase 測試數據")

        // 1. 建立組織
        createTestOrganization()
            .flatMap { _ in
                self.updateProgress("組織建立完成，建立員工資料...")
            }
            .flatMap { _ in
                self.createTestEmployees()
            }
            .flatMap { _ in
                self.updateProgress("員工建立完成，建立休假規則...")
            }
            .flatMap { _ in
                self.createTestVacationRules()
            }
            .flatMap { _ in
                self.updateProgress("休假規則建立完成，建立員工排班...")
            }
            .flatMap { _ in
                self.createTestEmployeeSchedules()
            }
            .sink(
                receiveCompletion: { [weak self] completion in
                    DispatchQueue.main.async {
                        self?.isInitializing = false
                        switch completion {
                        case .failure(let error):
                            self?.initializationProgress = "初始化失敗: \(error.localizedDescription)"
                            print("❌ Firebase 初始化失敗: \(error)")
                        case .finished:
                            self?.initializationProgress = "✅ 所有測試數據初始化完成！"
                            print("✅ Firebase 初始化完成")
                        }
                    }
                },
                receiveValue: { _ in
                    print("✅ 數據初始化步驟完成")
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - 建立測試組織
    private func createTestOrganization() -> AnyPublisher<Void, Error> {
        return scheduleService.addOrUpdateOrganization(
            orgId: "demo_store_01",
            name: "Demo Store",
            settings: [
                "timezone": "Asia/Taipei",
                "currency": "TWD",
                "workDays": "1,2,3,4,5" // 週一到週五
            ]
        )
        .handleEvents(receiveOutput: { _ in
            print("✅ 組織建立成功: demo_store_01")
        })
        .eraseToAnyPublisher()
    }

    // MARK: - 建立測試員工
    private func createTestEmployees() -> AnyPublisher<Void, Error> {
        let employees = [
            ("emp_001", "張小明", "正職員工"),
            ("emp_002", "李小華", "兼職員工"),
            ("emp_003", "王小美", "正職員工"),
            ("emp_004", "陳小強", "兼職員工")
        ]

        let publishers = employees.map { (id, name, role) in
            scheduleService.addOrUpdateEmployee(
                orgId: "demo_store_01",
                employeeId: id,
                name: name,
                role: role
            )
            .handleEvents(receiveOutput: { _ in
                print("✅ 員工建立成功: \(name) (\(id))")
            })
        }

        return Publishers.MergeMany(publishers)
            .collect()
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    // MARK: - 建立測試休假規則
    private func createTestVacationRules() -> AnyPublisher<Void, Error> {
        let currentDate = Date()
        let calendar = Calendar.current

        // 建立當前月份和未來2個月的休假規則
        let months = (0...2).compactMap { offset in
            calendar.date(byAdding: .month, value: offset, to: currentDate)
        }

        let publishers = months.map { date in
            let year = calendar.component(.year, from: date)
            let month = calendar.component(.month, from: date)
            let monthString = String(format: "%04d-%02d", year, month)

            return scheduleService.updateVacationRule(
                orgId: "demo_store_01",
                month: monthString,
                type: "monthly",
                monthlyLimit: 9, // 每月最多9天
                weeklyLimit: 2,  // 每週最多2天
                published: true
            )
            .handleEvents(receiveOutput: { _ in
                print("✅ 休假規則建立成功: \(monthString)")
            })
        }

        return Publishers.MergeMany(publishers)
            .collect()
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    // MARK: - 建立測試員工排班
    private func createTestEmployeeSchedules() -> AnyPublisher<Void, Error> {
        let currentDate = Date()
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // 為當前月份建立一些示例排班
        let year = calendar.component(.year, from: currentDate)
        let month = calendar.component(.month, from: currentDate)
        let monthString = String(format: "%04d-%02d", year, month)

        // 員工排班示例數據
        let scheduleData = [
            ("emp_001", ["2025-08-05", "2025-08-12", "2025-08-19"]),
            ("emp_002", ["2025-08-06", "2025-08-13", "2025-08-20"]),
            ("emp_003", ["2025-08-07", "2025-08-14", "2025-08-21"])
        ]

        let publishers = scheduleData.map { (employeeId, dateStrings) in
            let dates = dateStrings.compactMap { dateFormatter.date(from: $0) }

            return scheduleService.updateEmployeeSchedule(
                orgId: "demo_store_01",
                employeeId: employeeId,
                month: monthString,
                dates: dates
            )
            .flatMap {
                // 提交排班
                self.scheduleService.submitEmployeeSchedule(
                    orgId: "demo_store_01",
                    employeeId: employeeId,
                    month: monthString
                )
            }
            .handleEvents(receiveOutput: { _ in
                print("✅ 員工排班建立成功: \(employeeId) - \(dateStrings.count)天")
            })
        }

        return Publishers.MergeMany(publishers)
            .collect()
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    // MARK: - 清除所有測試數據
    func clearAllTestData() {
        guard !isInitializing else { return }

        isInitializing = true
        initializationProgress = "正在清除所有測試數據..."

        print("🗑️ 開始清除所有測試數據")

        // 這裡可以實作清除邏輯，但由於 Firebase 沒有批次刪除 API
        // 建議在 Firebase Console 手動清除或使用 Firebase Admin SDK

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isInitializing = false
            self.initializationProgress = "⚠️ 請在 Firebase Console 手動清除數據"
            print("⚠️ 請在 Firebase Console 手動清除數據")
        }
    }

    // MARK: - Helper Methods
    private func updateProgress(_ message: String) -> AnyPublisher<Void, Never> {
        DispatchQueue.main.async {
            self.initializationProgress = message
            print("📝 \(message)")
        }
        return Just(()).eraseToAnyPublisher()
    }

    // MARK: - 檢查數據完整性
    func checkDataIntegrity() {
        print("🔍 檢查 Firebase 數據完整性...")

        // 檢查組織
        scheduleService.fetchOrganization(orgId: "demo_store_01")
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        print("❌ 組織數據檢查失敗: \(error)")
                    case .finished:
                        break
                    }
                },
                receiveValue: { org in
                    if let org = org {
                        print("✅ 組織數據完整: \(org)")
                    } else {
                        print("⚠️ 組織數據不存在")
                    }
                }
            )
            .store(in: &cancellables)

        // 檢查當前月份的休假規則
        let currentMonthString = DateFormatter.yearMonthFormatter.string(from: Date())
        scheduleService.fetchVacationRule(orgId: "demo_store_01", month: currentMonthString)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        print("❌ 休假規則檢查失敗: \(error)")
                    case .finished:
                        break
                    }
                },
                receiveValue: { rule in
                    if let rule = rule {
                        print("✅ 休假規則完整: \(rule)")
                    } else {
                        print("⚠️ 當前月份休假規則不存在: \(currentMonthString)")
                    }
                }
            )
            .store(in: &cancellables)
    }
}
