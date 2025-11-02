//
//  WidgetDataProvider.swift
//  ClipStackWidget
//
//  Widget 数据提供器
//

import Foundation
import CoreData
import UIKit

struct WidgetClipItem: Identifiable {
    let id: UUID
    let content: String
    let contentType: String
    let sourceApp: String
    let createdAt: Date
    let isStarred: Bool
    
    let imageData: Data?
    let imageFormat: String?
    let imageWidth: Int
    let imageHeight: Int
    let thumbnailSize: Int
    
    var typeIcon: String {
        switch contentType {
        case "text": return "📄"
        case "link": return "🔗"
        case "image": return "🖼️"
        default: return "📄"
        }
    }
    
    var hasImage: Bool {
        return contentType == "image" && imageData != nil
    }
    
    var thumbnailImage: UIImage? {
        guard let imageData = imageData else { return nil }
        return UIImage(data: imageData)
    }
    
    // 图片描述
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
        
        return parts.joined(separator: L10n.widgetSeparator)
    }
    
    var preview: String {
        if hasImage {
            return imageDescription
        }
        
        if content.count <= 50 {
            return content
        } else {
            let index = content.index(content.startIndex, offsetBy: 47)
            return String(content[..<index]) + "..."
        }
    }
    
    var timeAgo: String {
        let interval = Date().timeIntervalSince(createdAt)
        if interval < 60 {
            return L10n.justNow
        } else if interval < 3600 {
            return String(format: L10n.minutesAgo, Int(interval / 60))
        } else if interval < 86400 {
            return String(format: L10n.hoursAgo, Int(interval / 3600))
        } else if interval < 172800 {
            return L10n.yesterday
        } else {
            return String(format: L10n.daysAgo, Int(interval / 86400))
        }
    }
}

class WidgetDataProvider {
    static let shared = WidgetDataProvider()
    
    private let appGroupIdentifier = "group.com.kimcao.clipstack"
    
    func fetchRecentItems(limit: Int) -> [WidgetClipItem] {
        print("📱 Widget loading data, limit \(limit)...")
        
        let container = NSPersistentContainer(name: "ClipStack")
        
        guard let appGroupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            print("❌ Cannot get App Group path")
            return []
        }
        
        let storeURL = appGroupURL.appendingPathComponent("ClipStack.sqlite")
        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        storeDescription.setOption(true as NSNumber, forKey: NSReadOnlyPersistentStoreOption)
        
        container.persistentStoreDescriptions = [storeDescription]
        
        var items: [WidgetClipItem] = []
        let semaphore = DispatchSemaphore(value: 0)
        
        container.loadPersistentStores { description, error in
            if let error = error {
                print("❌ Widget Core Data load failed: \(error)")
                semaphore.signal()
                return
            }
            
            print("✅ Widget Core Data loaded")
            
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
                    
                    let content = object.value(forKey: "content") as? String ?? ""
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
                
                print("✅ Widget loaded \(items.count) items")
            } catch {
                print("❌ Widget query failed: \(error)")
            }
            
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .now() + 3)
        
        return items
    }
}
