//
//  Persistence.swift
//  ClipStack
//
//  Core Data持久化控制器
//  主 App 使用 NSPersistentCloudKitContainer（支持 iCloud 同步）
//  Extension 使用 NSPersistentContainer（仅本地存储）

import CoreData

struct PersistenceController {
    
    static let shared = PersistenceController()
    
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext
        
        for i in 0..<5 {
            let newItem = ClipItem(context: viewContext)
            newItem.id = UUID()
            newItem.content = "示例条目 \(i + 1)"
            newItem.contentType = "text"
            newItem.sourceApp = "预览"
            newItem.createdAt = Date()
            newItem.isStarred = (i == 0)
            newItem.usageCount = 0
        }
        
        do {
            try viewContext.save()
        } catch {
            print("❌ 预览数据创建失败: \(error)")
        }
        
        return controller
    }()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        let isExtension = Bundle.main.bundlePath.hasSuffix(".appex")
        
        if isExtension {
            container = NSPersistentContainer(name: "ClipStack")
        } else {
            container = NSPersistentCloudKitContainer(name: "ClipStack")
        }
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            guard let storeURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: "group.com.kimcao.clipstack")?
                .appendingPathComponent("ClipStack.sqlite") else {
                fatalError("❌ 无法获取App Group共享容器路径")
            }
            
            let description = NSPersistentStoreDescription(url: storeURL)
            
            if !isExtension {
                if FileManager.default.ubiquityIdentityToken != nil {
                    description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                        containerIdentifier: "iCloud.com.kimcao.clipstack"
                    )
                }
            }
            
            // ✅ 关键配置：让 CloudKit 在后台自动合并
description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)  // ⭐ 新增
description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            
            container.persistentStoreDescriptions = [description]
        }
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("❌ Core Data加载失败: \(error)")
            }
            print("✅ Core Data加载成功")
        }
        
        // ✅ 关键配置：自动合并变化
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}

// ✅ 保留限制检查方法（不改动）
extension PersistenceController {
    
    @discardableResult
    static func enforceHistoryLimit(context: NSManagedObjectContext) -> Bool {
        if ProManager.shared.isPro {
            return true
        }
        
        let request: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
        request.predicate = NSPredicate(format: "isStarred == %@", NSNumber(value: false))
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ClipItem.createdAt, ascending: true)
        ]
        
        do {
            let items = try context.fetch(request)
            let currentCount = items.count
            let limit = ProManager.freeHistoryLimit
            
            print("📊 当前非收藏条目数：\(currentCount)/\(limit)")
            
            if currentCount >= limit {
                let itemsToDelete = items.prefix(currentCount - limit + 1)
                
                for item in itemsToDelete {
                    print("🗑️ 自动删除最旧的条目: \(item.previewContent)")
                    context.delete(item)
                }
                
                try context.save()
                print("✅ 已清理 \(itemsToDelete.count) 条旧记录")
            }
            
            return true
        } catch {
            print("❌ 清理历史记录失败: \(error)")
            return false
        }
    }
    
    static func checkStarredLimit(context: NSManagedObjectContext) -> (currentCount: Int, canStar: Bool) {
        if ProManager.shared.isPro {
            return (0, true)
        }
        
        let request: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
        request.predicate = NSPredicate(format: "isStarred == %@", NSNumber(value: true))
        
        do {
            let count = try context.count(for: request)
            let canStar = ProManager.shared.canStarItem(currentStarredCount: count)
            
            print("⭐ 当前收藏数：\(count)/\(ProManager.shared.getStarredLimit())")
            
            return (count, canStar)
        } catch {
            print("❌ 查询收藏数失败: \(error)")
            return (0, false)
        }
    }
}

// ✅ 删除 fetchItems 方法（不需要手动查询）
// ✅ 删除 FilterType 枚举（移到 ContentView.swift 内部）

enum FilterType: String, CaseIterable {
    case all = "全部"
    case text = "文本"
    case link = "链接"
    case image = "图片"
    case starred = "⭐收藏"
}