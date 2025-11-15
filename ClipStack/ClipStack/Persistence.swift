//
//  Persistence.swift
//  ClipStack
//
//  Core Data 持久化控制器
//  负责管理 SQLite 数据库和 CloudKit 同步
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentCloudKitContainer
    
    // MARK: - 初始化
    
    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "ClipStack")
        
        // ✅ 获取 App Group 共享目录
        guard let appGroupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.kimcao.clipstack"
        ) else {
            fatalError("❌ 无法访问 App Group：group.com.kimcao.clipstack")
        }
        
        let storeURL = appGroupURL.appendingPathComponent("ClipStack.sqlite")
        let description = NSPersistentStoreDescription(url: storeURL)
        
        // ✅ 核心配置：启用自动合并
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // ✅ CloudKit 配置（仅在登录 iCloud 时启用）
        if FileManager.default.ubiquityIdentityToken != nil {
            let cloudKitOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.kimcao.clipstack"
            )
            description.cloudKitContainerOptions = cloudKitOptions
            print("☁️ iCloud 同步已启用")
        } else {
            description.cloudKitContainerOptions = nil
            print("⚠️ 未登录 iCloud，仅使用本地存储")
        }
        
        // ✅ 内存模式（用于测试）
        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.persistentStoreDescriptions = [description]
        
        // ✅ 加载持久化存储
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                print("❌ Core Data 加载失败:")
                print("   - URL: \(storeDescription.url?.path ?? "N/A")")
                print("   - Error: \(error.localizedDescription)")
                print("   - UserInfo: \(error.userInfo)")
                
                // ⚠️ 开发阶段：如果数据库损坏，自动删除重建
                #if DEBUG
                if let storeURL = storeDescription.url {
                    try? FileManager.default.removeItem(at: storeURL)
                    print("🗑️ 已删除损坏的数据库，重新启动 App 将自动重建")
                }
                #endif
                
                fatalError("Core Data 无法加载，请检查 App Group 配置")
            }
            
            print("✅ Core Data 加载成功: \(storeDescription.url?.path ?? "N/A")")
        }
        
        // ✅ 启用自动合并（关键配置）
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // ✅ 设置查询生成（支持历史追踪）
        do {
            try container.viewContext.setQueryGenerationFrom(.current)
            print("✅ 查询生成已启用")
        } catch {
            print("⚠️ 查询生成启用失败: \(error.localizedDescription)")
        }
        
        print("✅ PersistenceController 初始化完成")
    }
    
    // MARK: - 预览数据（SwiftUI Canvas 专用）
    
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext
        
        // 创建示例数据
        let previewItems = [
            ("这是一段测试文本", "text", ClipItemSource.preview.rawValue),
            ("https://www.apple.com", "link", ClipItemSource.preview.rawValue),
            ("预览数据示例", "text", ClipItemSource.preview.rawValue)
        ]
        
        for (content, type, source) in previewItems {
            let item = ClipItem(
                content: content,
                contentType: type,
                sourceApp: source,
                context: viewContext
            )
            item.createdAt = Date()
        }
        
        do {
            try viewContext.save()
            print("✅ 预览数据创建成功")
        } catch {
            print("❌ 预览数据创建失败: \(error.localizedDescription)")
        }
        
        return controller
    }()
    
    // MARK: - 清理旧数据（后台任务）
    
    /// 强制执行历史记录限制（免费版 5 条，Pro 版无限）
    /// - Parameter context: 后台 context
    /// - Returns: 被删除的条目数量
    @discardableResult
    static func enforceHistoryLimit(context: NSManagedObjectContext) -> Int {
        let proManager = ProManager.shared
        let limit = proManager.getHistoryLimit()
        
        // Pro 版无限制，直接返回
        if proManager.isPro {
            return 0
        }
        
        var deletedCount = 0
        
        context.performAndWait {
            // 查询非收藏条目（按时间降序）
            let fetchRequest: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "isStarred == %@", NSNumber(value: false))
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipItem.createdAt, ascending: false)]
            
            do {
                let allNonStarred = try context.fetch(fetchRequest)
                let currentCount = allNonStarred.count
                
                print("📊 当前非收藏条目: \(currentCount)，限制: \(limit)")
                
                // 超出限制时删除最旧的条目
                if currentCount > limit {
                    let itemsToDelete = allNonStarred.dropFirst(limit)
                    for item in itemsToDelete {
                        print("🗑️ 自动删除旧条目: \(item.content?.prefix(30) ?? "")")
                        context.delete(item)
                        deletedCount += 1
                    }
                    
                    try context.save()
                    print("✅ 清理完成，删除了 \(deletedCount) 条旧记录")
                }
            } catch {
                print("❌ 清理历史记录失败: \(error.localizedDescription)")
            }
        }
        
        return deletedCount
    }
    
    /// 检查收藏数量是否超出限制
    /// - Parameter context: 查询用的 context
    /// - Returns: (当前数量, 限制数量, 是否超出)
    static func checkStarredLimit(context: NSManagedObjectContext) -> (current: Int, limit: Int, exceeded: Bool) {
        let proManager = ProManager.shared
        let limit = proManager.getStarredLimit()
        
        var current = 0
        context.performAndWait {
            let fetchRequest: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "isStarred == %@", NSNumber(value: true))
            
            do {
                current = try context.count(for: fetchRequest)
            } catch {
                print("❌ 查询收藏数失败: \(error.localizedDescription)")
            }
        }
        
        let exceeded = !proManager.isPro && current >= limit
        print("📊 当前收藏数: \(current)，限制: \(limit)，\(exceeded ? "已满" : "正常")")
        
        return (current, limit, exceeded)
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
