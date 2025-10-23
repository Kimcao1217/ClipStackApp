//
//  WidgetDataProvider.swift
//  ClipStackWidget
//
//  Widget 数据提供器 - 负责从 Core Data 加载数据（⭐ 支持图片）
//

import Foundation
import CoreData
import UIKit

/// Widget 使用的简化数据模型（⭐ 新增图片支持）
struct WidgetClipItem: Identifiable {
    let id: UUID
    let content: String
    let contentType: String
    let sourceApp: String
    let createdAt: Date
    let isStarred: Bool
    
    // ⭐ 新增：图片相关属性
    let imageData: Data?
    let imageFormat: String?
    let imageWidth: Int
    let imageHeight: Int
    let thumbnailSize: Int
    
    // 类型图标
    var typeIcon: String {
        switch contentType {
        case "text": return "📄"
        case "link": return "🔗"
        case "image": return "🖼️"
        default: return "📄"
        }
    }
    
    // ⭐ 是否有图片
    var hasImage: Bool {
        return contentType == "image" && imageData != nil
    }
    
    // ⭐ 获取缩略图 UIImage
    var thumbnailImage: UIImage? {
        guard let imageData = imageData else { return nil }
        return UIImage(data: imageData)
    }
    
    // ⭐ 图片描述（格式 • 尺寸 • 大小）
    var imageDescription: String {
        guard hasImage else { return "" }
        
        var parts: [String] = []
        
        if let format = imageFormat, !format.isEmpty {
            parts.append(format)
        }
        
        if imageWidth > 0 && imageHeight > 0 {
            parts.append("\(imageWidth)×\(imageHeight)")
        }
        
        if thumbnailSize > 0 {
            if thumbnailSize < 1024 {
                parts.append("\(thumbnailSize)B")
            } else if thumbnailSize < 1024 * 1024 {
                parts.append(String(format: "%.1fKB", Double(thumbnailSize) / 1024.0))
            } else {
                parts.append(String(format: "%.1fMB", Double(thumbnailSize) / 1024.0 / 1024.0))
            }
        }
        
        return parts.joined(separator: " • ")
    }
    
    // 内容预览（最多50字符）
    var preview: String {
        // ⭐ 图片类型显示图片信息
        if hasImage {
            return imageDescription
        }
        
        // 文本/链接类型显示内容
        if content.count <= 50 {
            return content
        } else {
            let index = content.index(content.startIndex, offsetBy: 47)
            return String(content[..<index]) + "..."
        }
    }
    
    // 相对时间字符串
    var timeAgo: String {
        let interval = Date().timeIntervalSince(createdAt)
        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            return "\(Int(interval / 60))分钟前"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))小时前"
        } else if interval < 172800 {
            return "昨天"
        } else {
            return "\(Int(interval / 86400))天前"
        }
    }
}

/// Widget 数据加载器
class WidgetDataProvider {
    static let shared = WidgetDataProvider()
    
    private let appGroupIdentifier = "group.com.kimcao.clipstack"
    
    /// 获取最新的剪贴板条目
    /// - Parameter limit: 最多返回多少条（小号1条，中号3条，大号5条）
    /// - Returns: 剪贴板条目数组
    func fetchRecentItems(limit: Int) -> [WidgetClipItem] {
        print("📱 Widget 开始加载数据，限制 \(limit) 条...")
        
        // 创建持久化容器
        let container = NSPersistentContainer(name: "ClipStack")
        
        // 配置存储路径（必须与主 App 一致）
        guard let appGroupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            print("❌ 无法获取 App Group 路径")
            return []
        }
        
        let storeURL = appGroupURL.appendingPathComponent("ClipStack.sqlite")
        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        
        // 只读模式（Widget 只读取，不修改）
        storeDescription.setOption(true as NSNumber, forKey: NSReadOnlyPersistentStoreOption)
        
        container.persistentStoreDescriptions = [storeDescription]
        
        var items: [WidgetClipItem] = []
        let semaphore = DispatchSemaphore(value: 0)
        
        // 加载持久化存储
        container.loadPersistentStores { description, error in
            if let error = error {
                print("❌ Widget 加载 Core Data 失败: \(error)")
                semaphore.signal()
                return
            }
            
            print("✅ Widget Core Data 加载成功")
            
            // 创建查询请求
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ClipItem")
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "createdAt", ascending: false)
            ]
            fetchRequest.fetchLimit = limit
            
            do {
                let results = try container.viewContext.fetch(fetchRequest)
                
                items = results.compactMap { object in
                    guard let id = object.value(forKey: "id") as? UUID,
                          let contentType = object.value(forKey: "contentType") as? String,
                          let sourceApp = object.value(forKey: "sourceApp") as? String,
                          let createdAt = object.value(forKey: "createdAt") as? Date,
                          let isStarred = object.value(forKey: "isStarred") as? Bool else {
                        return nil
                    }
                    
                    // ⭐ 获取内容（图片类型可能为空）
                    let content = object.value(forKey: "content") as? String ?? ""
                    
                    // ⭐ 获取图片相关属性
                    let imageData = object.value(forKey: "imageData") as? Data
                    let imageFormat = object.value(forKey: "imageFormat") as? String
                    let imageWidth = object.value(forKey: "imageWidth") as? Int ?? 0
                    let imageHeight = object.value(forKey: "imageHeight") as? Int ?? 0
                    let thumbnailSize = object.value(forKey: "thumbnailSize") as? Int ?? 0
                    
                    return WidgetClipItem(
                        id: id,
                        content: content,
                        contentType: contentType,
                        sourceApp: sourceApp,
                        createdAt: createdAt,
                        isStarred: isStarred,
                        imageData: imageData,
                        imageFormat: imageFormat,
                        imageWidth: imageWidth,
                        imageHeight: imageHeight,
                        thumbnailSize: thumbnailSize
                    )
                }
                
                print("✅ Widget 成功加载 \(items.count) 条数据")
            } catch {
                print("❌ Widget 查询数据失败: \(error)")
            }
            
            semaphore.signal()
        }
        
        // 等待加载完成（最多 3 秒）
        _ = semaphore.wait(timeout: .now() + 3)
        
        return items
    }
}
