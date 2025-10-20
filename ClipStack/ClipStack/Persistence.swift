//
//  Persistence.swift
//  ClipStack
//
//  Core Data持久化控制器
//  使用 NSPersistentCloudKitContainer 自动同步到 iCloud

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
            let newItem = ClipItem(
                content: "示例条目 \(i + 1)：这是一段测试内容，用于在 Xcode 预览中显示。",
                contentType: "text",
                sourceApp: "预览",
                context: viewContext
            )
            newItem.isStarred = (i == 0) // 第一个条目设为收藏
        }
        
        do {
            try viewContext.save()
        } catch {
            print("❌ 预览数据创建失败: \(error)")
        }
        
        return controller
    }()
    
    // MARK: - Core Data Stack
    
    /// 持久化容器（使用 CloudKit 自动同步）
    let container: NSPersistentCloudKitContainer
    
    // MARK: - 初始化
    
    init(inMemory: Bool = false) {
        // ⚠️ 关键：使用 NSPersistentCloudKitContainer（支持 CloudKit 同步）
        container = NSPersistentCloudKitContainer(name: "ClipStack")
        
        // 配置持久化存储
        if inMemory {
            // 测试用：内存存储
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // ⚠️ 生产环境：使用 App Group 共享存储
            let storeURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: "group.com.kimcao.clipstack")!
                .appendingPathComponent("ClipStack.sqlite")
            
            let description = NSPersistentStoreDescription(url: storeURL)
            
            // ⚠️ 关键配置：启用 CloudKit 同步
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.kimcao.clipstack"
            )
            
            // 启用远程变更通知
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // 启用历史追踪（用于同步）
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            
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
        
        print("✅ NSPersistentCloudKitContainer 初始化完成，自动同步已启用")
    }
}
