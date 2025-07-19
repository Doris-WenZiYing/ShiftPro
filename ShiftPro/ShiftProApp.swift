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

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 配置 Firebase
        FirebaseApp.configure()

        // 設置 Firestore
        let settings = FirestoreSettings()
        settings.cacheSettings = MemoryCacheSettings()
        let db = Firestore.firestore()
        db.settings = settings

        print("🔥 Firebase 初始化完成")
        return true
    }
}
