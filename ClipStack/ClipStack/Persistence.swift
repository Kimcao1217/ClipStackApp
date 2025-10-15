//
//  Persistence.swift
//  ClipStack
//
//  Created by Kim Cao on 13/10/2025.
//  Core Data数据持久化管理器
//  负责初始化Core Data栈并提供预览数据
//  支持App Group共享数据

import CoreData
import Foundation

struct PersistenceController {
    // App Group标识符 - 必须与Xcode配置的完全一致
    static let appGroupIdentifier = "group.com.kimcao.clipstack"
    
    // 单例模式，整个App共享一个数据管理器
    static let shared = PersistenceController()

    // 用于SwiftUI预览的临时数据管理器
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // 创建一些测试数据用于预览
        let sampleItem1 = ClipItem(context: viewContext)
        sampleItem1.id = UUID()
        sampleItem1.content = "这是一个示例文本内容，用于测试剪贴板应用的显示效果"
        sampleItem1.contentType = "text"
        sampleItem1.sourceApp = "微信"
        sampleItem1.createdAt = Date().addingTimeInterval(-3600) // 1小时前
        sampleItem1.isStarred = false
        sampleItem1.usageCount = 2
        
        let sampleItem2 = ClipItem(context: viewContext)
        sampleItem2.id = UUID()
        sampleItem2.content = "https://developer.apple.com/documentation/swiftui"
        sampleItem2.contentType = "link"
        sampleItem2.sourceApp = "Safari"
        sampleItem2.createdAt = Date().addingTimeInterval(-7200) // 2小时前
        sampleItem2.isStarred = true
        sampleItem2.usageCount = 5
        
        let sampleItem3 = ClipItem(context: viewContext)
        sampleItem3.id = UUID()
        sampleItem3.content = "记住要在今天下午3点开会讨论项目进度"
        sampleItem3.contentType = "text"
        sampleItem3.sourceApp = "备忘录"
        sampleItem3.createdAt = Date().addingTimeInterval(-300) // 5分钟前
        sampleItem3.isStarred = false
        sampleItem3.usageCount = 0
        
        // 保存测试数据
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("预览数据创建失败: \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    // Core Data容器，管理整个数据库
    let container: NSPersistentContainer

    // 初始化方法
    // inMemory: 是否只在内存中存储数据（用于预览和测试）
    init(inMemory: Bool = false) {
        // 创建持久化容器，名称必须与.xcdatamodeld文件名一致
        container = NSPersistentContainer(name: "ClipStack")
        
        if inMemory {
            // 如果是内存模式，数据不会保存到磁盘
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // 🔑 关键：使用App Group共享容器路径
            // 这样主App和扩展都能访问同一个数据库文件
            if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: PersistenceController.appGroupIdentifier) {
                let storeURL = appGroupURL.appendingPathComponent("ClipStack.sqlite")
                
                // 配置持久化存储描述符
                let storeDescription = NSPersistentStoreDescription(url: storeURL)
                
                // 启用持久化历史跟踪（用于多进程同步）
                storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                
                // 启用远程变更通知（当扩展修改数据时通知主App）
                storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
                
                container.persistentStoreDescriptions = [storeDescription]
                
                print("✅ Core Data将使用App Group路径: \(storeURL.path)")
            } else {
                print("⚠️ 无法获取App Group路径，将使用默认路径")
            }
        }
        
        // 加载持久化存储
        container.loadPersistentStores(completionHandler: { description, error in
            if let error = error as NSError? {
                // 在实际发布的应用中，应该优雅地处理这个错误
                fatalError("Core Data加载失败: \(error), \(error.userInfo)")
            }
            
            print("✅ Core Data加载成功: \(description)")
        })
        
        // 启用自动合并来自其他上下文的更改
        // 这对于App和Extension同时修改数据非常重要
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // 设置合并策略：新数据覆盖旧数据
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - 便利方法
    
    /// 保存主上下文的更改
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                print("✅ Core Data保存成功")
            } catch {
                let nsError = error as NSError
                print("❌ Core Data保存失败: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}
