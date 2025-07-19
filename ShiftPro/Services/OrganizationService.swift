//
//  OrganizationService.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/19.
//

import Combine
import Foundation

final class OrganizationService {
    static let shared = OrganizationService()
    private let firebase: FirebaseService

    private init(firebase: FirebaseService = .shared) {
        self.firebase = firebase
    }

    // MARK: - Organization Operations

    /// 取得組織資料
    func fetchOrganization(orgId: String) -> AnyPublisher<Organization?, Error> {
        return firebase
            .getDocument(
                collection: "organizations",
                document: orgId,
                as: Organization.self
            )
            .eraseToAnyPublisher()
    }

    /// 新增或更新組織
    func addOrUpdateOrganization(_ organization: Organization) -> AnyPublisher<Void, Error> {
        let payload = organization.dictionary

        return firebase
            .setData(
                collection: "organizations",
                document: organization.orgId,
                data: payload
            )
            .eraseToAnyPublisher()
    }

    /// 更新組織資料
    func updateOrganization(
        orgId: String,
        name: String? = nil,
        description: String? = nil
    ) -> AnyPublisher<Void, Error> {
        var payload: [String: Any] = ["updatedAt": Date()]

        if let name = name { payload["name"] = name }
        if let description = description { payload["description"] = description }

        return firebase
            .updateData(
                collection: "organizations",
                document: orgId,
                data: payload
            )
            .eraseToAnyPublisher()
    }

    /// 刪除組織
    func deleteOrganization(orgId: String) -> AnyPublisher<Void, Error> {
        return firebase
            .deleteDocument(
                collection: "organizations",
                document: orgId
            )
            .eraseToAnyPublisher()
    }
}
