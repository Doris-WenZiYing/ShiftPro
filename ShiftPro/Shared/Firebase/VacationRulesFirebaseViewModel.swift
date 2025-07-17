//
//  VacationRulesFirebaseViewModel.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/17.
//

import Foundation
import SwiftUI
import Firebase

@MainActor
class VacationRulesFirebaseViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var vacationRules: [VacationRuleFirebase] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isConnected = false

    // MARK: - Private Properties
    private let firebaseManager = FirebaseManager.shared
    private let orgId = "demo_store_01" // 示範用的組織ID
    private var listener: ListenerRegistration?

    // MARK: - Initialization
    init() {
        checkConnection()
        loadVacationRules()
    }

    deinit {
        listener?.remove()
    }

    // MARK: - Public Methods

    /// 保存休假規則到 Firebase
    func saveVacationRule(month: String, type: String, monthlyLimit: Int, weeklyLimit: Int, published: Bool) {
        isLoading = true
        errorMessage = nil

        let rule = VacationRuleFirebase(
            orgId: orgId,
            month: month,
            type: type,
            monthlyLimit: monthlyLimit,
            weeklyLimit: weeklyLimit,
            published: published
        )

        firebaseManager.saveVacationRule(
            orgId: orgId,
            month: month,
            rule: rule
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success:
                    print("✅ 休假規則保存成功")
                    self?.loadVacationRules()
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("❌ 保存失敗: \(error.localizedDescription)")
                }
            }
        }
    }

    /// 獲取特定月份的休假規則
    func getVacationRule(month: String) {
        isLoading = true
        errorMessage = nil

        firebaseManager.getVacationRule(
            orgId: orgId,
            month: month
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success(let rule):
                    print("✅ 獲取規則成功: \(rule.month)")
                    // 可以在這裡處理單個規則
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("❌ 獲取失敗: \(error.localizedDescription)")
                }
            }
        }
    }

    /// 載入所有休假規則
    func loadVacationRules() {
        isLoading = true
        errorMessage = nil

        firebaseManager.getVacationRules(orgId: orgId) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success(let rules):
                    self?.vacationRules = rules.sorted { $0.month < $1.month }
                    print("✅ 載入 \(rules.count) 個休假規則")
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("❌ 載入失敗: \(error.localizedDescription)")
                }
            }
        }
    }

    /// 開始監聽特定月份的規則變化
    func startListening(month: String) {
        listener?.remove()

        listener = firebaseManager.listenToVacationRule(
            orgId: orgId,
            month: month
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let rule):
                    print("📱 即時更新: \(rule.month)")
                    self?.updateRuleInList(rule)
                case .failure(let error):
                    print("❌ 監聽錯誤: \(error.localizedDescription)")
                }
            }
        }
    }

    /// 停止監聽
    func stopListening() {
        listener?.remove()
        listener = nil
    }

    /// 清除錯誤訊息
    func clearError() {
        errorMessage = nil
    }

    // MARK: - Private Methods

    /// 檢查 Firebase 連接狀態
    private func checkConnection() {
        // 簡單的連接測試
        let testRef = Firestore.firestore().collection("test").document("connection")
        testRef.getDocument { [weak self] document, error in
            DispatchQueue.main.async {
                self?.isConnected = error == nil
                print("🔥 Firebase 連接狀態: \(self?.isConnected == true ? "已連接" : "未連接")")
            }
        }
    }

    /// 更新規則列表中的特定規則
    private func updateRuleInList(_ updatedRule: VacationRuleFirebase) {
        if let index = vacationRules.firstIndex(where: { $0.month == updatedRule.month }) {
            vacationRules[index] = updatedRule
        } else {
            vacationRules.append(updatedRule)
            vacationRules.sort { $0.month < $1.month }
        }
    }
}

// MARK: - 示範用的輔助方法
extension VacationRulesFirebaseViewModel {

    /// 創建示範數據
    func createSampleData() {
        let sampleRules = [
            ("2025-08", "monthly", 9, 2, true),
            ("2025-09", "weekly", 0, 3, false),
            ("2025-10", "monthly", 8, 2, true)
        ]

        for (month, type, monthlyLimit, weeklyLimit, published) in sampleRules {
            saveVacationRule(
                month: month,
                type: type,
                monthlyLimit: monthlyLimit,
                weeklyLimit: weeklyLimit,
                published: published
            )
        }
    }

    /// 清除所有測試數據
    func clearAllData() {
        for rule in vacationRules {
            firebaseManager.deleteDocument(
                collection: "vacation_rules",
                documentId: "\(rule.orgId)_\(rule.month)"
            ) { result in
                switch result {
                case .success:
                    print("✅ 刪除成功: \(rule.month)")
                case .failure(let error):
                    print("❌ 刪除失敗: \(error.localizedDescription)")
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.loadVacationRules()
        }
    }
}
