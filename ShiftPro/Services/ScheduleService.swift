//
//  ScheduleService.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/17.
//

import Foundation
import Combine
import FirebaseAuth

final class ScheduleService {
    static let shared = ScheduleService()
    private let firebase: FirebaseService
    private let localStorage: LocalStorageService
    private let dateFormatter: DateFormatter

    private init(
        firebase: FirebaseService = .shared,
        localStorage: LocalStorageService = .shared
    ) {
        self.firebase = firebase
        self.localStorage = localStorage
        self.dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
    }

    // MARK: - Employee Schedule Operations

    /// 取得員工排班資料（支援 orgId 或使用當前用戶）
    func fetchEmployeeSchedule(
        orgId: String? = nil,
        employeeId: String? = nil,
        month: String
    ) -> AnyPublisher<FirestoreEmployeeSchedule?, Error> {
        let actualEmployeeId = employeeId ?? Auth.auth().currentUser?.uid
        let actualOrgId = orgId ?? UserDefaults.standard.string(forKey: "orgId") ?? "demo_store_01"

        guard let empId = actualEmployeeId else {
            return Fail(error: NSError(
                domain: "ScheduleService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "未登入或未提供員工ID"]
            ))
            .eraseToAnyPublisher()
        }

        let docId = "\(actualOrgId)_\(empId)_\(month)"

        return firebase
            .getDocument(
                collection: "employee_schedules",
                document: docId,
                as: FirestoreEmployeeSchedule.self
            )
            .eraseToAnyPublisher()
    }

    /// 取得員工排班日期陣列（方便 UI 使用）
    func fetchEmployeeScheduleDates(
        orgId: String? = nil,
        employeeId: String? = nil,
        month: String
    ) -> AnyPublisher<[Date], Error> {
        return fetchEmployeeSchedule(orgId: orgId, employeeId: employeeId, month: month)
            .map { schedule in
                schedule?.selectedDates.compactMap { self.dateFormatter.date(from: $0) } ?? []
            }
            .eraseToAnyPublisher()
    }

    /// 監聽員工排班變化（實時更新）
    func observeEmployeeSchedule(
        orgId: String? = nil,
        employeeId: String? = nil,
        month: String
    ) -> AnyPublisher<FirestoreEmployeeSchedule?, Error> {
        let actualEmployeeId = employeeId ?? Auth.auth().currentUser?.uid
        let actualOrgId = orgId ?? UserDefaults.standard.string(forKey: "orgId") ?? "demo_store_01"

        guard let empId = actualEmployeeId else {
            return Fail(error: NSError(
                domain: "ScheduleService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "未登入或未提供員工ID"]
            ))
            .eraseToAnyPublisher()
        }

        let docId = "\(actualOrgId)_\(empId)_\(month)"

        return firebase
            .documentPublisher(
                collection: "employee_schedules",
                document: docId,
                as: FirestoreEmployeeSchedule.self
            )
            .eraseToAnyPublisher()
    }

    /// 更新員工排班
    func updateEmployeeSchedule(
        orgId: String? = nil,
        employeeId: String? = nil,
        month: String,
        dates: [Date]
    ) -> AnyPublisher<Void, Error> {
        let actualEmployeeId = employeeId ?? Auth.auth().currentUser?.uid
        let actualOrgId = orgId ?? UserDefaults.standard.string(forKey: "orgId") ?? "demo_store_01"

        guard let empId = actualEmployeeId else {
            return Fail(error: NSError(
                domain: "ScheduleService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "未登入或未提供員工ID"]
            ))
            .eraseToAnyPublisher()
        }

        let docId = "\(actualOrgId)_\(empId)_\(month)"
        let dateStrings = dates.map { dateFormatter.string(from: $0) }
        let now = Date()

        let payload: [String: Any] = [
            "orgId": actualOrgId,
            "employeeId": empId,
            "month": month,
            "selectedDates": dateStrings,
            "isSubmitted": false,
            "createdAt": now,
            "updatedAt": now
        ]

        return firebase
            .setData(
                collection: "employee_schedules",
                document: docId,
                data: payload
            )
            .eraseToAnyPublisher()
    }

    /// 提交員工排班
    func submitEmployeeSchedule(
        orgId: String? = nil,
        employeeId: String? = nil,
        month: String
    ) -> AnyPublisher<Void, Error> {
        let actualEmployeeId = employeeId ?? Auth.auth().currentUser?.uid
        let actualOrgId = orgId ?? UserDefaults.standard.string(forKey: "orgId") ?? "demo_store_01"

        guard let empId = actualEmployeeId else {
            return Fail(error: NSError(
                domain: "ScheduleService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "未登入或未提供員工ID"]
            ))
            .eraseToAnyPublisher()
        }

        let docId = "\(actualOrgId)_\(empId)_\(month)"
        let payload: [String: Any] = [
            "isSubmitted": true,
            "updatedAt": Date()
        ]

        return firebase
            .updateData(
                collection: "employee_schedules",
                document: docId,
                data: payload
            )
            .eraseToAnyPublisher()
    }

    // MARK: - Vacation Rule Operations

    /// 取得休假規則
    func fetchVacationRule(orgId: String, month: String) -> AnyPublisher<FirestoreVacationRule?, Error> {
        let docId = "\(orgId)_\(month)"
        return firebase
            .getDocument(
                collection: "vacation_rules",
                document: docId,
                as: FirestoreVacationRule.self
            )
            .eraseToAnyPublisher()
    }

    /// 更新休假規則
    func updateVacationRule(
        orgId: String,
        month: String,
        type: String,
        monthlyLimit: Int? = nil,
        weeklyLimit: Int? = nil,
        published: Bool = false
    ) -> AnyPublisher<Void, Error> {
        let docId = "\(orgId)_\(month)"
        let now = Date()

        let payload: [String: Any] = [
            "orgId": orgId,
            "month": month,
            "type": type,
            "monthlyLimit": monthlyLimit as Any,
            "weeklyLimit": weeklyLimit as Any,
            "published": published,
            "createdAt": now,
            "updatedAt": now
        ]

        return firebase
            .setData(
                collection: "vacation_rules",
                document: docId,
                data: payload
            )
            .eraseToAnyPublisher()
    }

    /// 刪除休假規則
    func deleteVacationRule(orgId: String, month: String) -> AnyPublisher<Void, Error> {
        let docId = "\(orgId)_\(month)"
        return firebase
            .deleteDocument(
                collection: "vacation_rules",
                document: docId
            )
            .eraseToAnyPublisher()
    }

    // MARK: - Employee Operations

    /// 取得員工資料
    func fetchEmployee(orgId: String, employeeId: String) -> AnyPublisher<FirestoreEmployee?, Error> {
        let docId = "\(orgId)_\(employeeId)"
        return firebase
            .getDocument(
                collection: "employees",  // 👈 直接在 employees 集合中
                document: docId,
                as: FirestoreEmployee.self
            )
            .eraseToAnyPublisher()
    }

    /// 新增或更新員工
    func addOrUpdateEmployee(
        orgId: String,
        employeeId: String,
        name: String,
        role: String
    ) -> AnyPublisher<Void, Error> {
        let docId = "\(orgId)_\(employeeId)"
        let now = Date()

        let payload: [String: Any] = [
            "orgId": orgId,
            "employeeId": employeeId,
            "name": name,
            "role": role,
            "createdAt": now,
            "updatedAt": now
        ]

        return firebase
            .setData(
                collection: "employees",  // 👈 直接在 employees 集合中
                document: docId,
                data: payload
            )
            .eraseToAnyPublisher()
    }

    // MARK: - Organization Operations

    /// 取得組織資料
    func fetchOrganization(orgId: String) -> AnyPublisher<FirestoreOrganization?, Error> {
        return firebase
            .getDocument(
                collection: "organizations",
                document: orgId,
                as: FirestoreOrganization.self
            )
            .eraseToAnyPublisher()
    }

    /// 新增或更新組織
    func addOrUpdateOrganization(
        orgId: String,
        name: String,
        settings: [String: String]? = nil
    ) -> AnyPublisher<Void, Error> {
        let now = Date()

        var payload: [String: Any] = [
            "name": name,
            "createdAt": now
        ]

        if let settings = settings {
            payload["settings"] = settings
        }

        return firebase
            .setData(
                collection: "organizations",
                document: orgId,
                data: payload
            )
            .eraseToAnyPublisher()
    }

    // MARK: - Combined Operations

    /// 同時取得休假規則和員工排班
    func fetchScheduleData(
        orgId: String,
        employeeId: String? = nil,
        month: String
    ) -> AnyPublisher<(FirestoreVacationRule?, FirestoreEmployeeSchedule?), Error> {
        return Publishers.Zip(
            fetchVacationRule(orgId: orgId, month: month),
            fetchEmployeeSchedule(orgId: orgId, employeeId: employeeId, month: month)
        )
        .eraseToAnyPublisher()
    }

    // MARK: - Local Storage Integration

    /// 本地保存排班資料
    func saveToLocal(month: String, dates: [Date]) {
        let dateStrings = Set(dates.map { dateFormatter.string(from: $0) })
        var vacationData = VacationData()
        vacationData.selectedDates = dateStrings
        vacationData.currentMonth = month
        localStorage.saveVacationData(vacationData, month: month)
    }

    /// 從本地載入排班資料
    func loadFromLocal(month: String) -> [Date] {
        guard let vacationData = localStorage.loadVacationData(month: month) else {
            return []
        }
        return Array(vacationData.selectedDates).compactMap { dateFormatter.date(from: $0) }
    }

    /// 清除本地排班資料
    func clearLocal(month: String) {
        localStorage.clearVacationData(month: month)
    }
}
