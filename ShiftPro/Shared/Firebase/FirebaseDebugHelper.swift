//
//  FirebaseDebugHelper.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/17.
//

import Foundation
import Firebase
import FirebaseAuth

// MARK: - Firebase 调试助手
class FirebaseDebugHelper {
    static let shared = FirebaseDebugHelper()

    private init() {}

    // MARK: - 测试 Firebase 连接
    func testFirebaseConnection() {
        print("🔥 开始测试 Firebase 连接...")

        let db = Firestore.firestore()

        // 尝试读取一个测试文档
        db.collection("test").document("connection").getDocument { (document, error) in
            if let error = error {
                print("❌ Firebase 连接失败: \(error.localizedDescription)")
            } else {
                print("✅ Firebase 连接成功")
                if let document = document, document.exists {
                    print("📄 测试文档存在")
                } else {
                    print("📄 测试文档不存在，创建新文档...")
                    self.createTestDocument()
                }
            }
        }
    }

    // MARK: - 创建测试文档
    private func createTestDocument() {
        let db = Firestore.firestore()

        db.collection("test").document("connection").setData([
            "timestamp": FieldValue.serverTimestamp(),
            "status": "connected"
        ]) { error in
            if let error = error {
                print("❌ 创建测试文档失败: \(error.localizedDescription)")
            } else {
                print("✅ 测试文档创建成功")
            }
        }
    }

    // MARK: - 测试假期限制同步
    func testVacationLimitsSync() {
        print("🔄 开始测试假期限制同步...")

        let db = Firestore.firestore()

        // 测试写入假期限制
        let testLimits: [String: Any] = [
            "monthlyLimit": 8,
            "weeklyLimit": 2,
            "mode": "monthly",
            "lastUpdated": FieldValue.serverTimestamp(),
            "publishedBy": "boss"
        ]

        db.collection("vacation_limits").document("current").setData(testLimits) { error in
            if let error = error {
                print("❌ 写入假期限制失败: \(error.localizedDescription)")
            } else {
                print("✅ 假期限制写入成功")
                self.readVacationLimits()
            }
        }
    }

    // MARK: - 读取假期限制
    private func readVacationLimits() {
        let db = Firestore.firestore()

        db.collection("vacation_limits").document("current").getDocument { (document, error) in
            if let error = error {
                print("❌ 读取假期限制失败: \(error.localizedDescription)")
            } else if let document = document, document.exists {
                let data = document.data()
                print("✅ 假期限制读取成功:")
                print("📊 月限制: \(data?["monthlyLimit"] ?? "未设置")")
                print("📊 周限制: \(data?["weeklyLimit"] ?? "未设置")")
                print("📊 模式: \(data?["mode"] ?? "未设置")")
                print("📊 发布者: \(data?["publishedBy"] ?? "未知")")
            } else {
                print("📄 假期限制文档不存在")
            }
        }
    }

    // MARK: - 列出所有存储的限制
    func listAllStoredLimits() {
        print("📋 开始列出所有存储的限制...")

        let db = Firestore.firestore()

        db.collection("vacation_limits").getDocuments { (querySnapshot, error) in
            if let error = error {
                print("❌ 获取限制列表失败: \(error.localizedDescription)")
            } else {
                print("✅ 限制列表获取成功:")

                guard let documents = querySnapshot?.documents else {
                    print("📄 没有找到任何限制文档")
                    return
                }

                if documents.isEmpty {
                    print("📄 限制集合为空")
                } else {
                    for document in documents {
                        print("📄 文档 ID: \(document.documentID)")
                        let data = document.data()
                        print("   - 月限制: \(data["monthlyLimit"] ?? "未设置")")
                        print("   - 周限制: \(data["weeklyLimit"] ?? "未设置")")
                        print("   - 模式: \(data["mode"] ?? "未设置")")
                        print("   - 发布者: \(data["publishedBy"] ?? "未知")")
                        print("   ---")
                    }
                }
            }
        }
    }

    // MARK: - 测试实时监听
    func testRealtimeListener() {
        print("👂 开始测试实时监听...")

        let db = Firestore.firestore()

        db.collection("vacation_limits").document("current").addSnapshotListener { (documentSnapshot, error) in
            if let error = error {
                print("❌ 实时监听失败: \(error.localizedDescription)")
            } else if let document = documentSnapshot, document.exists {
                print("🔄 实时更新收到:")
                let data = document.data()
                print("   - 月限制: \(data?["monthlyLimit"] ?? "未设置")")
                print("   - 周限制: \(data?["weeklyLimit"] ?? "未设置")")
                print("   - 模式: \(data?["mode"] ?? "未设置")")
            } else {
                print("📄 实时监听：文档不存在")
            }
        }
    }

    // MARK: - 清除测试数据
    func clearTestData() {
        print("🗑️ 开始清除测试数据...")

        let db = Firestore.firestore()

        // 删除测试连接文档
        db.collection("test").document("connection").delete { error in
            if let error = error {
                print("❌ 删除测试连接文档失败: \(error.localizedDescription)")
            } else {
                print("✅ 测试连接文档删除成功")
            }
        }

        // 删除假期限制文档
        db.collection("vacation_limits").document("current").delete { error in
            if let error = error {
                print("❌ 删除假期限制文档失败: \(error.localizedDescription)")
            } else {
                print("✅ 假期限制文档删除成功")
            }
        }
    }

    // MARK: - 测试用户认证状态
    func testAuthStatus() {
        print("🔐 检查用户认证状态...")

        if let user = Auth.auth().currentUser {
            print("✅ 用户已认证:")
            print("   - UID: \(user.uid)")
            print("   - Email: \(user.email ?? "未设置")")
            print("   - 显示名: \(user.displayName ?? "未设置")")
        } else {
            print("❌ 用户未认证")
            print("💡 尝试匿名登录...")

            Auth.auth().signInAnonymously { authResult, error in
                if let error = error {
                    print("❌ 匿名登录失败: \(error.localizedDescription)")
                } else if let user = authResult?.user {
                    print("✅ 匿名登录成功:")
                    print("   - UID: \(user.uid)")
                }
            }
        }
    }

    // MARK: - 测试网络连接
    func testNetworkConnection() {
        print("🌐 测试网络连接...")

        // 简单的网络连接测试
        guard let url = URL(string: "https://www.google.com") else {
            print("❌ 无效的测试 URL")
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ 网络连接失败: \(error.localizedDescription)")
                } else if let httpResponse = response as? HTTPURLResponse {
                    print("✅ 网络连接成功 - 状态码: \(httpResponse.statusCode)")
                }
            }
        }

        task.resume()
    }

    // MARK: - 完整的连接测试
    func runCompleteTest() {
        print("🚀 开始完整的 Firebase 连接测试...")

        // 1. 测试网络连接
        testNetworkConnection()

        // 等待一秒后继续
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // 2. 测试认证状态
            self.testAuthStatus()

            // 等待一秒后继续
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // 3. 测试 Firebase 连接
                self.testFirebaseConnection()

                // 等待一秒后继续
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    // 4. 测试假期限制同步
                    self.testVacationLimitsSync()

                    // 等待一秒后继续
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        // 5. 列出所有限制
                        self.listAllStoredLimits()


                        print("✅ 完整测试完成")
                    }
                }
            }
        }
    }
}
