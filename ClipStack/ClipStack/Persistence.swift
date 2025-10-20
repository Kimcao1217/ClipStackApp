//
//  Persistence.swift
//  ClipStack
//
//  Core Data持久化控制器
//  主 App 使用 NSPersistentCloudKitContainer（支持 iCloud 同步）
//  Extension 使用 NSPersistentContainer（仅本地存储）

import CoreData

struct PersistenceController {
    
    // MARK: - 单例
    
    static let shared = PersistenceController()
    
    // MARK: - 预览用实例（内存存储，不同步到 iCloud）
    
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext
        
        // 创建一些示例数据用于预览
        for i in 0..<5 {
            let newItem = ClipItem(context: viewContext)
            newItem.id = UUID()
            newItem.content = "示例条目 \(i + 1)：这是一段测试内容，用于在 Xcode 预览中显示。"
            newItem.contentType = "text"
            newItem.sourceApp = "预览"
            newItem.createdAt = Date()
            newItem.isStarred = (i == 0) // 第一个条目设为收藏
            newItem.usageCount = 0
        }
        
        do {
            try viewContext.save()
        } catch {
            print("❌ 预览数据创建失败: \(error)")
        }
        
        return controller
    }()
    
    // MARK: - Core Data Stack
    
    /// 持久化容器（根据环境选择类型）
    let container: NSPersistentContainer
    
    // MARK: - 初始化
    
    init(inMemory: Bool = false) {
        // ⚠️ 检测是否在 Extension 环境
        let isExtension = Bundle.main.bundlePath.hasSuffix(".appex")
        
        if isExtension {
            // ⚠️ Extension 使用简单的 NSPersistentContainer（无 CloudKit）
            print("🔌 Share Extension 环境，使用简化版 Core Data（无 CloudKit）")
            container = NSPersistentContainer(name: "ClipStack")
        } else {
            // ⚠️ 主 App 使用 NSPersistentCloudKitContainer（有 CloudKit）
            print("📱 主 App 环境，使用 CloudKit 同步版 Core Data")
            container = NSPersistentCloudKitContainer(name: "ClipStack")
        }
        
        // 配置持久化存储
        if inMemory {
            // 测试用：内存存储
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // ⚠️ 生产环境：使用 App Group 共享存储
            guard let storeURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: "group.com.kimcao.clipstack")?
                .appendingPathComponent("ClipStack.sqlite") else {
                fatalError("❌ 无法获取App Group共享容器路径")
            }
            
            let description = NSPersistentStoreDescription(url: storeURL)
            
            // ⚠️ 只在主 App 启用 CloudKit 同步
            if !isExtension {
                description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: "iCloud.com.kimcao.clipstack"
                )
            }
            
            // 启用远程变更通知（主 App 和 Extension 都需要）
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // 启用历史追踪（用于同步）
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            
            // 自动迁移
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            
            container.persistentStoreDescriptions = [description]
            
            print("✅ Core Data将使用App Group路径: \(storeURL.path)")
        }
        
        // 加载持久化存储
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("❌ Core Data加载失败: \(error), \(error.userInfo)")
            }
            print("✅ Core Data加载成功: \(storeDescription)")
        }
        
        // 配置上下文
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // ⚠️ 只在主 App 打印 CloudKit 状态
        if !isExtension {
            print("✅ NSPersistentCloudKitContainer 初始化完成，自动同步已启用")
        } else {
            print("✅ 简化版 Core Data 初始化完成（Extension 环境）")
        }
    }
}
