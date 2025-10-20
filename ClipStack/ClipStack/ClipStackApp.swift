//
//  ClipStackApp.swift
//  ClipStack
//
//  Created by Kim Cao on 13/10/2025.
//

import SwiftUI
import CoreData
import WidgetKit

@main
struct ClipStackApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let persistenceController = PersistenceController.shared
    
    // 用于监听Core Data远程变更通知
    @StateObject private var dataRefreshManager = DataRefreshManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(dataRefreshManager)
                .onAppear {
                    // App启动时开始监听远程变更
                    dataRefreshManager.startObserving(persistenceController: persistenceController)
                }
                // 处理 Widget 跳转
                .onOpenURL { url in
                    handleWidgetURL(url)
                }
                // App 进入后台时清理键盘资源
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    print("📱 App 进入后台，清理键盘资源...")
                    KeyboardPrewarmer.shared.cleanup()
                }
                // App 返回前台时重新预热键盘
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    print("📱 App 返回前台，重新预热键盘...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        KeyboardPrewarmer.shared.prewarmInBackground()
                    }
                }
        }
    }
    
    // MARK: - Widget URL 处理
    
    /// 处理从 Widget 跳转进来的 URL
    private func handleWidgetURL(_ url: URL) {
        print("📱 收到 Widget URL: \(url)")
        
        // 解析 URL（格式：clipstack://copy/UUID 或 clipstack://refresh）
        guard url.scheme == "clipstack" else {
            print("⚠️ 不是 ClipStack URL")
            return
        }
        
        if url.host == "copy", let idString = url.pathComponents.last, let id = UUID(uuidString: idString) {
            // 复制指定条目
            copyItemToClipboard(id: id)
        } else if url.host == "refresh" {
            // 手动刷新 Widget
            refreshWidget()
        }
    }
    
    /// 复制指定条目到系统剪贴板
    private func copyItemToClipboard(id: UUID) {
        print("📋 正在复制条目: \(id)")
        
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let items = try context.fetch(fetchRequest)
            
            if let item = items.first, let content = item.content {
                // 复制到剪贴板
                UIPasteboard.general.string = content
                
                // 增加使用次数
                item.usageCount += 1
                item.lastUsedAt = Date()
                
                try context.save()
                
                print("✅ 已复制到剪贴板: \(content.prefix(50))...")
                
                // 显示成功提示（使用触觉反馈）
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
            } else {
                print("⚠️ 未找到对应的条目")
            }
        } catch {
            print("❌ 复制失败: \(error)")
        }
    }
    
    /// 手动刷新 Widget
    private func refreshWidget() {
        print("🔄 手动刷新 Widget...")
        WidgetCenter.shared.reloadAllTimelines()
        
        // 触觉反馈
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        print("✅ Widget 刷新请求已发送")
    }
}

// MARK: - 数据刷新管理器

/// 管理Core Data远程变更通知和数据刷新
/// ⚠️ 使用 NSPersistentCloudKitContainer 自动同步，不需要手动上传
class DataRefreshManager: ObservableObject {
    // ⚠️ 关键：这个属性变化会触发SwiftUI重新渲染
    @Published var lastRefreshDate = Date()
    
    private var remoteChangeToken: NSObjectProtocol?
    private var willEnterForegroundToken: NSObjectProtocol?
    
    /// 开始监听Core Data的远程变更通知
    func startObserving(persistenceController: PersistenceController) {
        print("👂 开始监听Core Data远程变更...")
        
        // 监听持久化存储的远程变更通知
        remoteChangeToken = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: persistenceController.container.persistentStoreCoordinator,
            queue: .main
        ) { [weak self] notification in
            print("📡 收到远程变更通知！（CloudKit 自动同步）")
            self?.handleRemoteChange()
        }
        
        // 监听App进入前台事件
        willEnterForegroundToken = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("📱 App进入前台，刷新数据...")
            self?.handleRemoteChange()
        }
    }
    
    /// 处理远程变更
    private func handleRemoteChange() {
        print("🔄 刷新UI...")
        
        DispatchQueue.main.async { [weak self] in
            // ⚠️ 关键：通知SwiftUI重新查询数据
            self?.lastRefreshDate = Date()
            
            // 通知 Widget 刷新
            WidgetCenter.shared.reloadAllTimelines()
            
            print("✅ UI 刷新完成")
        }
    }
    
    deinit {
        // 清理通知监听
        if let token = remoteChangeToken {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = willEnterForegroundToken {
            NotificationCenter.default.removeObserver(token)
        }
        print("🛑 已停止监听Core Data远程变更")
    }
}
