//
//  ClipItem+Extensions.swift
//  ClipStack
//
//  Created by Kim Cao on 14/10/2025.
//
//  为ClipItem实体添加便利方法和计算属性
//

import Foundation
import CoreData
import UIKit

extension ClipItem {
    
    // MARK: - 便利初始化方法
    
    /// 创建新的剪贴板条目的便利方法
    /// - Parameters:
    ///   - content: 内容文本
    ///   - contentType: 内容类型（text/link/image）
    ///   - sourceApp: 来源应用名称
    ///   - context: Core Data管理上下文
    convenience init(content: String,
                    contentType: String = "text",
                    sourceApp: String = "ClipStack",
                    context: NSManagedObjectContext) {
        // 调用Core Data的指定初始化方法
        self.init(context: context)
        
        // 设置基本属性
        self.id = UUID()
        self.content = content
        self.contentType = contentType
        self.sourceApp = sourceApp
        self.createdAt = Date()
        self.isStarred = false
    }
    
    // MARK: - 计算属性
    
    /// 获取内容类型对应的图标
    var typeIcon: String {
        switch contentType {
        case "text":
            return "📄"
        case "link":
            return "🔗"
        case "image":
            return "🖼️"
        default:
            return "📄"
        }
    }
    
    /// 获取来源应用对应的图标
    var sourceIcon: String {
        // 使用nil合并运算符(??)提供默认值，然后安全地调用lowercased()
        switch (sourceApp ?? "").lowercased() {
        case "wechat", "微信":  // ✅ 支持中英文
            return "💬"
        case "safari":
            return "🌐"
        case "notes", "备忘录":  // ✅ 支持中英文
            return "📝"
        case "mail", "邮件":  // ✅ 支持中英文
            return "✉️"
        default:
            return "📱"
        }
    }
    
    /// 获取相对时间显示文本（如"刚刚"、"5分钟前"、"1小时前"）
    var relativeTimeString: String {
        guard let createdAt = createdAt else { return L10n.timeUnknown }  // ✅ 本地化
        
        let now = Date()
        let interval = now.timeIntervalSince(createdAt)
        
        // 根据iOS用户习惯优化时间显示
        if interval < 60 {
            // 0-60秒显示"刚刚"
            return L10n.justNow
        } else if interval < 3600 {
            // 1-59分钟显示分钟数
            let minutes = Int(interval / 60)
            return String(format: L10n.minutesAgo, minutes)
        } else if interval < 86400 {
            // 1-23小时显示小时数
            let hours = Int(interval / 3600)
            return String(format: L10n.hoursAgo, hours)
        } else if interval < 172800 {
            // 24-48小时显示"昨天"
            return L10n.yesterday
        } else if interval < 604800 {
            // 2-6天显示天数
            let days = Int(interval / 86400)
            return String(format: L10n.daysAgo, days)
        } else {
            // 7天以上显示具体日期
            let formatter = DateFormatter()
            formatter.locale = Locale.current  // ✅ 自动适应当前语言
            
            let calendar = Calendar.current
            let currentYear = calendar.component(.year, from: now)
            let createdYear = calendar.component(.year, from: createdAt)
            
            // 如果是今年，只显示月/日；如果是往年，显示年/月/日
            if currentYear == createdYear {
                formatter.setLocalizedDateFormatFromTemplate("MMMMd")  // ✅ 自动适配语言格式
            } else {
                formatter.setLocalizedDateFormatFromTemplate("yMMMMd")
            }
            
            return formatter.string(from: createdAt)
        }
    }
    
    /// 获取内容的预览文本（最多显示100个字符）
    var previewContent: String {
        // 安全地处理可选的content属性
        guard let content = content else { return "" }
        
        if content.count <= 100 {
            return content
        } else {
            let index = content.index(content.startIndex, offsetBy: 97)
            return String(content[..<index]) + "..."
        }
    }
    
    // MARK: - 业务方法
    
    /// 切换收藏状态
    func toggleStarred() {
        self.isStarred.toggle()
    }
    
    /// 检查是否为链接类型内容
    var isLink: Bool {
        return contentType == "link" || (content?.starts(with: "http") == true)
    }
    
    /// 检查是否为图片类型内容
    var isImage: Bool {
        return contentType == "image"
    }
}

// MARK: - Core Data便利方法

extension ClipItem {
    
    /// 获取所有剪贴板条目的请求（按创建时间倒序）
    static func allItemsFetchRequest() -> NSFetchRequest<ClipItem> {
        let request: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ClipItem.createdAt, ascending: false)
        ]
        return request
    }
    
    /// 获取收藏的剪贴板条目的请求
    static func starredItemsFetchRequest() -> NSFetchRequest<ClipItem> {
        let request: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
        request.predicate = NSPredicate(format: "isStarred == %@", NSNumber(value: true))
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ClipItem.createdAt, ascending: false)
        ]
        return request
    }
    
    /// 根据内容类型获取条目的请求
    /// - Parameter type: 内容类型（text/link/image）
    /// - Returns: 配置好的获取请求
    static func itemsByTypeFetchRequest(type: String) -> NSFetchRequest<ClipItem> {
        let request: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
        request.predicate = NSPredicate(format: "contentType == %@", type)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ClipItem.createdAt, ascending: false)
        ]
        return request
    }
}

// MARK: - 图片相关扩展（⭐ 新增）

extension ClipItem {
    
    /// 是否包含图片数据
    var hasImage: Bool {
        return imageData != nil && contentType == "image"
    }
    
    /// 获取缩略图 UIImage
    var thumbnailImage: UIImage? {
        guard let imageData = imageData else { return nil }
        return UIImage(data: imageData)
    }
    
    /// 图片尺寸描述（如 "1920×1080"）
    var imageSizeDescription: String {
        guard hasImage else { return "" }
        return "\(imageWidth) × \(imageHeight)"
    }
    
    /// 图片文件大小描述（优先显示缩略图大小）
    var imageSizeText: String {
        guard hasImage else { return "" }
        
        // ⭐ 修改：优先显示缩略图大小（实际存储的大小）
        let size = thumbnailSize > 0 ? thumbnailSize : originalSize
        
        if size < 1024 {
            return "\(size) B"
        } else if size < 1024 * 1024 {
            return String(format: "%.1f KB", Double(size) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(size) / 1024.0 / 1024.0)
        }
    }

    /// ⭐ 新增：原图大小描述（用于详情页展示）
    var originalSizeText: String {
        guard hasImage, originalSize > 0 else { return "" }
        
        if originalSize < 1024 {
            return "\(originalSize) B"
        } else if originalSize < 1024 * 1024 {
            return String(format: "%.1f KB", Double(originalSize) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(originalSize) / 1024.0 / 1024.0)
        }
    }

    /// ⭐ 新增：图片压缩比例描述（如 "Original 2.3MB → Compressed 45KB (1.9%)"）
    var compressionDescription: String {
        guard hasImage, originalSize > 0, thumbnailSize > 0 else { return "" }
        
        let ratio = Double(thumbnailSize) / Double(originalSize) * 100.0
        return String(format: L10n.imageCompressionDescription,  // ✅ 本地化
                      originalSizeText, imageSizeText, ratio)
    }
    
    /// 图片格式+尺寸+大小的完整描述（如 "JPEG • 1920×1080 • 2.3 MB"）
    var imageFullDescription: String {
        guard hasImage else { return "" }
        
        var parts: [String] = []
        
        if let format = imageFormat, !format.isEmpty {
            parts.append(format)
        }
        
        parts.append(imageSizeDescription)
        parts.append(imageSizeText)
        
        return parts.joined(separator: " • ")
    }
}
