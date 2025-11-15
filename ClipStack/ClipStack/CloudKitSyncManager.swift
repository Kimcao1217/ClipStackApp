//
//  CloudKitSyncManager.swift
//  ClipStack
//
//  CloudKit 同步状态管理器
//  监听 NSPersistentCloudKitContainer 的同步事件并提供状态给 UI
//

import Foundation
import CoreData
import Combine

/// CloudKit 同步状态枚举
enum CloudKitSyncStatus: Equatable {
    case notStarted           // 未开始同步
    case inProgress           // 正在同步
    case succeeded            // 同步成功
    case failed(String)       // 同步失败（带错误信息）
    
    var displayText: String {
        switch self {
        case .notStarted:
            return L10n.syncNotStarted
        case .inProgress:
            return L10n.syncInProgress
        case .succeeded:
            return L10n.syncSucceeded
        case .failed(let error):
            return String(format: NSLocalizedString("sync.failed", comment: ""), error)
        }
    }
    
    var iconName: String {
        switch self {
        case .notStarted:
            return "icloud.slash"
        case .inProgress:
            return "icloud.and.arrow.up"
        case .succeeded:
            return "icloud"
        case .failed:
            return "exclamationmark.icloud"
        }
    }
}

/// CloudKit 同步管理器（单例）
class CloudKitSyncManager: ObservableObject {
    
    // MARK: - 单例
    
    static let shared = CloudKitSyncManager()
    
    // MARK: - 发布属性
    
    /// 当前同步状态
    @Published var syncStatus: CloudKitSyncStatus = .notStarted
    
    /// 是否已登录 iCloud
    @Published var isCloudKitAvailable: Bool = false
    
    /// 同步的设备数量（通过推送 token 估算）
    @Published var syncedDeviceCount: Int = 0
    
    // MARK: - 私有属性
    
    private var notificationObservers: [NSObjectProtocol] = []
    private let persistenceController = PersistenceController.shared
    
    // ✅ iCloud 账户变更通知名称
    private let iCloudAccountChangedNotification = Notification.Name("NSUbiquityIdentityDidChangeNotification")
    
    // MARK: - 初始化
    
    private init() {
        checkCloudKitAvailability()
        setupNotificationObservers()
        print("☁️ CloudKitSyncManager 初始化完成")
    }
    
    deinit {
        removeNotificationObservers()
    }
    
    // MARK: - 公开方法
    
    /// 手动触发同步（用户下拉刷新时调用）
    func manualSync() {
        print("🔄 用户手动触发同步")
        syncStatus = .inProgress
        
        // NSPersistentCloudKitContainer 会自动同步，我们只需要等待通知
        // 这里可以强制保存一次，触发同步
        let context = persistenceController.container.viewContext
        if context.hasChanges {
            do {
                try context.save()
                print("✅ 已保存本地更改，等待 CloudKit 同步")
            } catch {
                print("❌ 保存失败: \(error.localizedDescription)")
                syncStatus = .failed(error.localizedDescription)
            }
        } else {
            // 没有本地更改时，直接标记为成功
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.syncStatus = .succeeded
            }
        }
    }
    
    // MARK: - 私有方法
    
    /// 检查 iCloud 是否可用
    private func checkCloudKitAvailability() {
        // 检查用户是否登录 iCloud
        if FileManager.default.ubiquityIdentityToken != nil {
            isCloudKitAvailable = true
            print("✅ iCloud 账户已登录")
        } else {
            isCloudKitAvailable = false
            syncStatus = .failed(L10n.syncErrorNotLoggedIn)
            print("❌ 未登录 iCloud 账户")
        }
    }
    
    /// 设置通知监听器
    private func setupNotificationObservers() {
        // ✅ 监听 CloudKit 同步事件
        let eventObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: persistenceController.container,
            queue: .main
        ) { [weak self] notification in
            self?.handleCloudKitEvent(notification)
        }
        notificationObservers.append(eventObserver)
        
        // ✅ 监听 iCloud 账户变更
        let accountObserver = NotificationCenter.default.addObserver(
            forName: iCloudAccountChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("⚠️ iCloud 账户发生变更")
            self?.checkCloudKitAvailability()
        }
        notificationObservers.append(accountObserver)
        
        print("👂 已设置 CloudKit 通知监听器")
    }
    
    /// 移除通知监听器
    private func removeNotificationObservers() {
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        notificationObservers.removeAll()
    }
    
    /// 处理 CloudKit 同步事件
    private func handleCloudKitEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else {
            return
        }
        
        print("📬 收到 CloudKit 事件: \(event.type)")
        
        switch event.type {
        case .setup:
            print("⚙️ CloudKit 正在初始化")
            syncStatus = .inProgress
            
        case .import:
            print("📥 正在从 iCloud 导入数据")
            syncStatus = .inProgress
            
            // 导入完成后检查错误
            if event.endDate != nil {
                if let error = event.error {
                    handleSyncError(error)
                } else {
                    print("✅ 导入完成")
                    syncStatus = .succeeded
                    
                    // 3 秒后恢复到未开始状态
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        if case .succeeded = self.syncStatus {
                            self.syncStatus = .notStarted
                        }
                    }
                }
            }
            
        case .export:
            print("📤 正在向 iCloud 导出数据")
            syncStatus = .inProgress
            
            // 导出完成后检查错误
            if event.endDate != nil {
                if let error = event.error {
                    handleSyncError(error)
                } else {
                    print("✅ 导出完成")
                    syncStatus = .succeeded
                    
                    // 3 秒后恢复到未开始状态
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        if case .succeeded = self.syncStatus {
                            self.syncStatus = .notStarted
                        }
                    }
                }
            }
            
        @unknown default:
            print("⚠️ 未知的 CloudKit 事件类型")
        }
    }
    
    /// 处理同步错误
    private func handleSyncError(_ error: Error) {
        let nsError = error as NSError
        
        print("❌ CloudKit 同步错误:")
        print("   - Domain: \(nsError.domain)")
        print("   - Code: \(nsError.code)")
        print("   - Description: \(nsError.localizedDescription)")
        
        // 根据错误类型提供友好提示
        let errorMessage: String
        
        switch nsError.code {
        case 1:  // CKError.networkUnavailable
            errorMessage = L10n.syncErrorNetwork
            
        case 2:  // CKError.networkFailure
            errorMessage = L10n.syncErrorNetwork
            
        case 9:  // CKError.quotaExceeded
            errorMessage = L10n.syncErrorQuotaExceeded
            
        case 11: // CKError.notAuthenticated
            errorMessage = L10n.syncErrorNotLoggedIn
            
        default:
            errorMessage = nsError.localizedDescription
        }
        
        syncStatus = .failed(errorMessage)
        
        // 10 秒后恢复到未开始状态（给用户时间看到错误）
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if case .failed = self.syncStatus {
                self.syncStatus = .notStarted
            }
        }
    }
}
