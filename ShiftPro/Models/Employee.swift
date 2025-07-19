//
//  Employee.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/19.
//

import Foundation
import FirebaseFirestore

struct Employee: Codable {
    let orgId: String
    let employeeId: String
    let name: String
    let role: String
    let createdAt: Date?
    let updatedAt: Date?

    var docId: String { "\(orgId)_\(employeeId)" }

    var dictionary: [String: Any] {
        [
            "orgId": orgId,
            "employeeId": employeeId,
            "name": name,
            "role": role,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }
}

