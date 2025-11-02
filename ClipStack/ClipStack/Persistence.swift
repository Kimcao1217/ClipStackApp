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
            newItem.content = "Sample item \(i + 1)"  // ✅ 改为英文
            newItem.contentType = "text"
            newItem.sourceApp = ClipItemSource.preview.rawValue
            newItem.createdAt = Date()
            newItem.isStarred = (i == 0)
        }
        
        do {
            try viewContext.save()
        } catch {
            print("❌ \(L10n.errorPreviewDataFailed): \(error)")  // ✅ 本地化
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
                fatalError("❌ \(L10n.errorAppGroupPathFailed)")  // ✅ 本地化
            }
            
            let description = NSPersistentStoreDescription(url: storeURL)
            
            if !isExtension {
                if FileManager.default.ubiquityIdentityToken != nil {
                    description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                        containerIdentifier: "iCloud.com.kimcao.clipstack"
                    )
                }
            }
            
            // 让 CloudKit 在后台自动合并
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            
            container.persistentStoreDescriptions = [description]
        }
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("❌ \(L10n.errorCoreDataLoadFailed): \(error)")  // ✅ 本地化
            }
            print("✅ \(L10n.successCoreDataLoaded)")  // ✅ 本地化
        }
        
        // ✅ 关键配置：自动合并变化
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}

// MARK: - 免费版限制管理

extension PersistenceController {
    
    /// 强制执行历史记录限制（自动删除最旧的非收藏条目）
    /// - Parameter context: Core Data 上下文
    /// - Returns: 是否成功执行清理
    @discardableResult
    static func enforceHistoryLimit(context: NSManagedObjectContext) -> Bool {
        // Pro 版无限制
        if ProManager.shared.isPro {
            return true
        }
        
        let request: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
        request.predicate = NSPredicate(format: "isStarred == %@", NSNumber(value: false))
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ClipItem.createdAt, ascending: true)  // 最旧的在前
        ]
        
        do {
            let items = try context.fetch(request)
            let currentCount = items.count
            let limit = ProManager.freeHistoryLimit
            
            print("📊 \(L10n.logCurrentHistoryCount(currentCount, limit))")  // ✅ 本地化
            
            if currentCount > limit {
                // 删除超出限制的旧条目
                let excessCount = currentCount - limit
                let itemsToDelete = items.prefix(excessCount)
                
                for item in itemsToDelete {
                    print("🗑️ \(L10n.logAutoDeleteOldItem): \(item.previewContent)")  // ✅ 本地化
                    context.delete(item)
                }
                
                try context.save()
                print("✅ \(L10n.logCleanupCompleted(itemsToDelete.count))")  // ✅ 本地化
            }
            
            return true
        } catch {
            print("❌ \(L10n.errorCleanupFailed): \(error)")  // ✅ 本地化
            return false
        }
    }
    
    /// 检查收藏限制（返回当前收藏数和是否可以继续收藏）
    /// - Parameter context: Core Data 上下文
    /// - Returns: (当前收藏数, 是否可以收藏)
    static func checkStarredLimit(context: NSManagedObjectContext) -> (currentCount: Int, canStar: Bool) {
        // Pro 版无限制
        if ProManager.shared.isPro {
            return (0, true)
        }
        
        let request: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
        request.predicate = NSPredicate(format: "isStarred == %@", NSNumber(value: true))
        
        do {
            let count = try context.count(for: request)
            let canStar = ProManager.shared.canStarItem(currentStarredCount: count)
            
            print("⭐ \(L10n.logCurrentStarredCount(count, ProManager.shared.getStarredLimit()))")  // ✅ 本地化
            
            return (count, canStar)
        } catch {
            print("❌ \(L10n.errorQueryStarredFailed): \(error)")  // ✅ 本地化
            return (0, false)
        }
    }
}

// MARK: - 筛选类型枚举

enum FilterType: String, CaseIterable {
    case all = "All"
    case text = "Text"
    case link = "Links"
    case image = "Images"
    case starred = "Starred"
    
    /// 本地化显示名称
    var localizedName: String {
        switch self {
        case .all:
            return L10n.filterAll
        case .text:
            return L10n.filterText
        case .link:
            return L10n.filterLink
        case .image:
            return L10n.filterImage
        case .starred:
            return L10n.filterStarred
        }
    }
}
