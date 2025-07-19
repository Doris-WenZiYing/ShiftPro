//
//  Organization.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/19.
//

import Foundation
import FirebaseFirestore

struct Organization: Codable {
    let orgId: String
    let name: String
    let createdAt: Date?

    var dictionary: [String: Any] {
        [
            "orgId": orgId,
            "name": name,
            "createdAt": FieldValue.serverTimestamp()
        ]
    }
}

