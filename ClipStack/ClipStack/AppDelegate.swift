//
//  AppDelegate.swift
//  ClipStack
//
//  轻量级 AppDelegate，仅用于远程推送注册（CloudKit 需要）
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    
    /// App 启动完成
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        print("📱 AppDelegate 初始化完成")
        
        // ⚠️ 注册远程推送通知（CloudKit 自动同步需要）
        application.registerForRemoteNotifications()
        
        return true
    }
    
    /// 远程推送注册成功
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("✅ 远程推送注册成功，Token: \(token)")
    }
    
    /// 远程推送注册失败
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("⚠️ 远程推送注册失败: \(error.localizedDescription)")
    }
    
    /// 收到远程推送通知（CloudKit 变更通知）
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("📬 收到远程推送通知: \(userInfo)")
        
        // ⚠️ NSPersistentCloudKitContainer 会自动处理 CloudKit 通知
        // 我们只需要调用 completionHandler
        completionHandler(.newData)
    }
}
