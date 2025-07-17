//
//  ShiftProApp.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/8.
//

import SwiftUI
import Firebase

@main
struct ShiftProApp: App {

    init() {
        // 🔥 初始化 Firebase
        FirebaseApp.configure()

        // 🔥 可選：啟用 Firestore 離線持久化
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        Firestore.firestore().settings = settings

        print("🔥 Firebase 初始化完成")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
