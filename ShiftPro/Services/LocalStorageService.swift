//
//  LocalStorageService.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/17.
//

import Foundation

public final class LocalStorageService {
    public static let shared = LocalStorageService()
    private let defaults = UserDefaults.standard
    private init() {}

    public func saveVacationData(_ data: VacationData, month: String) {
        let key = "VacationData_\(month)"
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: key)
        }
    }

    public func loadVacationData(month: String) -> VacationData? {
        let key = "VacationData_\(month)"
        guard let raw = defaults.data(forKey: key),
              let data = try? JSONDecoder().decode(VacationData.self, from: raw) else {
            return nil
        }
        return data
    }

    public func clearVacationData(month: String) {
        defaults.removeObject(forKey: "VacationData_\(month)")
    }
}
