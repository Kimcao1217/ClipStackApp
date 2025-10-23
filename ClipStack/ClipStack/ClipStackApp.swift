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
    
    /// 复制指定条目到系统剪贴板（⭐ 支持图片）
private func copyItemToClipboard(id: UUID) {
    print("📋 正在复制条目: \(id)")
    
    let context = persistenceController.container.viewContext
    let fetchRequest: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
    
    do {
        let items = try context.fetch(fetchRequest)
        
        guard let item = items.first else {
            print("⚠️ 未找到对应的条目")
            return
        }
        
        // ⭐ 根据内容类型复制
        if item.contentType == "image" {
            // 复制图片
            if let imageData = item.imageData, let image = UIImage(data: imageData) {
                UIPasteboard.general.image = image
                print("✅ 已复制图片到剪贴板（尺寸：\(item.imageWidth)×\(item.imageHeight)）")
                
                // 显示成功提示
                showSuccessHUD(message: "✅ 图片已复制")
            } else {
                print("❌ 图片数据无效")
                showErrorHUD(message: "❌ 图片加载失败")
                return
            }
        } else {
            // 复制文本/链接
            if let content = item.content {
                UIPasteboard.general.string = content
                print("✅ 已复制到剪贴板: \(content.prefix(50))...")
                
                // 显示成功提示
                showSuccessHUD(message: "✅ 已复制")
            } else {
                print("⚠️ 内容为空")
                return
            }
        }
        
        // 增加使用次数
        item.usageCount += 1
        item.lastUsedAt = Date()
        
        try context.save()
        
        // 触觉反馈
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
    } catch {
        print("❌ 复制失败: \(error)")
        showErrorHUD(message: "❌ 复制失败")
    }
}

// MARK: - HUD 提示（⭐ 新增）
/// 显示成功提示（⭐ 修复重复添加子视图问题）
private func showSuccessHUD(message: String) {
    DispatchQueue.main.async {
        // ⭐ createHUD 内部已经添加到 window，不需要再次 addSubview
        let hud = createHUD(message: message, icon: "✅", color: .systemGreen)
        
        UIView.animate(withDuration: 0.3, delay: 0, options: [], animations: {
            hud.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 1.5, options: [], animations: {
                hud.alpha = 0
            }) { _ in
                hud.removeFromSuperview()
            }
        }
    }
}

/// 显示错误提示（⭐ 修复重复添加子视图问题）
private func showErrorHUD(message: String) {
    DispatchQueue.main.async {
        // ⭐ createHUD 内部已经添加到 window，不需要再次 addSubview
        let hud = createHUD(message: message, icon: "❌", color: .systemRed)
        
        UIView.animate(withDuration: 0.3, delay: 0, options: [], animations: {
            hud.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 1.5, options: [], animations: {
                hud.alpha = 0
            }) { _ in
                hud.removeFromSuperview()
            }
        }
    }
}

/// 创建 HUD 视图（⭐ 修复定位问题）
private func createHUD(message: String, icon: String, color: UIColor) -> UIView {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first else {
        return UIView()
    }
    
    let hud = UIView()
    hud.backgroundColor = UIColor.black.withAlphaComponent(0.8)
    hud.layer.cornerRadius = 12
    hud.translatesAutoresizingMaskIntoConstraints = false
    hud.alpha = 0
    
    let label = UILabel()
    label.text = message
    label.textColor = .white
    label.font = .systemFont(ofSize: 16, weight: .medium)
    label.numberOfLines = 0
    label.textAlignment = .center
    label.translatesAutoresizingMaskIntoConstraints = false
    
    hud.addSubview(label)
    
    // ⭐ 关键修复：先添加到 window，再设置约束
    window.addSubview(hud)
    
    NSLayoutConstraint.activate([
        // HUD 居中显示
        hud.centerXAnchor.constraint(equalTo: window.centerXAnchor),
        hud.centerYAnchor.constraint(equalTo: window.centerYAnchor),
        
        // HUD 最小宽度 120，最大宽度 280
        hud.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
        hud.widthAnchor.constraint(lessThanOrEqualToConstant: 280),
        
        // Label 布局
        label.leadingAnchor.constraint(equalTo: hud.leadingAnchor, constant: 20),
        label.trailingAnchor.constraint(equalTo: hud.trailingAnchor, constant: -20),
        label.topAnchor.constraint(equalTo: hud.topAnchor, constant: 12),
        label.bottomAnchor.constraint(equalTo: hud.bottomAnchor, constant: -12)
    ])
    
    return hud
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

class DataRefreshManager: ObservableObject {
    @Published var lastRefreshDate = Date()
    
    private var remoteChangeToken: NSObjectProtocol?
    private var willEnterForegroundToken: NSObjectProtocol?
    
    // ⭐ 新增：防抖定时器
    private var refreshDebounceTimer: Timer?
    
    func startObserving(persistenceController: PersistenceController) {
        print("👂 开始监听Core Data远程变更...")
        
        remoteChangeToken = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: persistenceController.container.persistentStoreCoordinator,
            queue: .main
        ) { [weak self] notification in
            print("📡 收到远程变更通知！（CloudKit 自动同步）")
            self?.scheduleRefresh()  // ⭐ 改用防抖刷新
        }
        
        willEnterForegroundToken = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("📱 App进入前台，刷新数据...")
            self?.scheduleRefresh()  // ⭐ 改用防抖刷新
        }
    }
    
    // ⭐ 新增：防抖刷新（300ms 内多次触发只执行一次）
    private func scheduleRefresh() {
        refreshDebounceTimer?.invalidate()
        
        refreshDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.handleRemoteChange()
        }
    }
    
    private func handleRemoteChange() {
        print("🔄 刷新UI...")
        
        DispatchQueue.main.async { [weak self] in
            self?.lastRefreshDate = Date()
            
            WidgetCenter.shared.reloadAllTimelines()
            
            print("✅ UI 刷新完成")
        }
    }
    
    deinit {
        refreshDebounceTimer?.invalidate()
        
        if let token = remoteChangeToken {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = willEnterForegroundToken {
            NotificationCenter.default.removeObserver(token)
        }
        print("🛑 已停止监听Core Data远程变更")
    }
}
