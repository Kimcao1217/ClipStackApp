//
//  Persistence.swift
//  ClipStack
//
//  Created by Kim Cao on 13/10/2025.
//  Core Data数据持久化管理器
//  负责初始化Core Data栈并提供预览数据

import CoreData
import Foundation

struct PersistenceController {
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
            // 如果保存失败，我们在这里处理错误
            // 在实际开发中，可以添加错误日志或用户提示
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
        }
        
        // 加载持久化存储
        container.loadPersistentStores(completionHandler: { _, error in
            if let error = error as NSError? {
                // 在实际发布的应用中，应该优雅地处理这个错误
                // 比如显示用户友好的错误信息，或者重新创建数据库
                fatalError("Core Data加载失败: \(error), \(error.userInfo)")
            }
        })
        
        // 启用自动合并来自其他上下文的更改
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
