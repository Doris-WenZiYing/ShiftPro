//
//  EmployeeService.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/19.
//

import Combine
import Foundation

final class EmployeeService {
    static let shared = EmployeeService()
    private let firebase: FirebaseService

    private init(firebase: FirebaseService = .shared) {
        self.firebase = firebase
    }

    // MARK: - Employee Operations

    /// 取得員工資料
    func fetchEmployee(orgId: String, employeeId: String) -> AnyPublisher<FirestoreEmployee?, Error> {
        let docId = "\(orgId)_\(employeeId)"
        return firebase
            .getDocument(
                collection: "organizations/\(orgId)/employees",
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
                collection: "organizations/\(orgId)/employees",
                document: docId,
                data: payload
            )
            .eraseToAnyPublisher()
    }

    /// 更新員工資料
    func updateEmployee(
        orgId: String,
        employeeId: String,
        name: String? = nil,
        role: String? = nil
    ) -> AnyPublisher<Void, Error> {
        let docId = "\(orgId)_\(employeeId)"
        var payload: [String: Any] = ["updatedAt": Date()]

        if let name = name { payload["name"] = name }
        if let role = role { payload["role"] = role }

        return firebase
            .updateData(
                collection: "organizations/\(orgId)/employees",
                document: docId,
                data: payload
            )
            .eraseToAnyPublisher()
    }

    /// 刪除員工
    func deleteEmployee(orgId: String, employeeId: String) -> AnyPublisher<Void, Error> {
        let docId = "\(orgId)_\(employeeId)"
        return firebase
            .deleteDocument(
                collection: "organizations/\(orgId)/employees",
                document: docId
            )
            .eraseToAnyPublisher()
    }
}
