//
//  ClipStackApp.swift
//  ClipStack
//
//  Created by Kim Cao on 13/10/2025.
//

import SwiftUI
import CoreData

@main
struct ClipStackApp: App {
    let persistenceController = PersistenceController.shared
    
    // 用于监听Core Data远程变更通知
    @StateObject private var dataRefreshManager = DataRefreshManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                // ⚠️ 关键：让ContentView能响应刷新信号
                .environmentObject(dataRefreshManager)
                .onAppear {
                    // App启动时开始监听远程变更
                    dataRefreshManager.startObserving(persistenceController: persistenceController)
                }
        }
    }
}

// MARK: - 数据刷新管理器

/// 管理Core Data远程变更通知和数据刷新
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
            print("📡 收到远程变更通知！")
            self?.handleRemoteChange(persistenceController: persistenceController)
        }
        
        // 监听App进入前台事件
        willEnterForegroundToken = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("📱 App进入前台，执行刷新...")
            self?.handleRemoteChange(persistenceController: persistenceController)
        }
    }
    
    /// 处理远程变更
    private func handleRemoteChange(persistenceController: PersistenceController) {
        print("🔄 正在刷新Core Data上下文...")
        
        let viewContext = persistenceController.container.viewContext
        
        // 在主线程刷新上下文
        DispatchQueue.main.async { [weak self] in
            // 刷新所有对象
            viewContext.refreshAllObjects()
            
            // ⚠️ 关键：通知SwiftUI重新查询数据
            self?.lastRefreshDate = Date()
            
            print("✅ 上下文刷新完成！UI应该已更新")
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