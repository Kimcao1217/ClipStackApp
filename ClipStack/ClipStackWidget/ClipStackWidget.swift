//
//  ClipStackWidget.swift
//  ClipStackWidget
//
//  桌面小组件主文件
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct ClipStackEntry: TimelineEntry {
    let date: Date
    let items: [WidgetClipItem]
}

// MARK: - Timeline Provider

struct ClipStackProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> ClipStackEntry {
        print("📦 Widget placeholder called")
        return ClipStackEntry(date: Date(), items: [
            WidgetClipItem(
                id: UUID(),
                content: L10n.widgetPlaceholderContent,
                contentType: "text",
                sourceApp: "ClipStack",
                createdAt: Date(),
                isStarred: false,
                imageData: nil,
                imageFormat: nil,
                imageWidth: 0,
                imageHeight: 0,
                thumbnailSize: 0
            )
        ])
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ClipStackEntry) -> Void) {
        print("📸 Widget getSnapshot called")
        let items = WidgetDataProvider.shared.fetchRecentItems(limit: 5)
        let entry = ClipStackEntry(date: Date(), items: items)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ClipStackEntry>) -> Void) {
        print("📅 Widget generating timeline...")
        
        let items = WidgetDataProvider.shared.fetchRecentItems(limit: 5)
        print("📊 Widget loaded \(items.count) items")
        
        let currentEntry = ClipStackEntry(date: Date(), items: items)
        let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [currentEntry], policy: .after(nextUpdateDate))
        
        print("✅ Widget timeline completed, next refresh: \(nextUpdateDate)")
        
        completion(timeline)
    }
}

// MARK: - Widget Views

/// 小尺寸 Widget（2×2，显示 1 条）
struct SmallWidgetView: View {
    let item: WidgetClipItem?
    
    var body: some View {
        Group {
            if let item = item {
                Link(destination: URL(string: "clipstack://copy/\(item.id.uuidString)")!) {
                    VStack(alignment: .leading, spacing: 4) {
                        // 标题栏
                        HStack {
                            Text("📋")
                                .font(.caption)
                            Text("ClipStack")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Spacer()
                            if item.isStarred {
                                Text("⭐")
                                    .font(.caption2)
                            }
                        }
                        .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // 内容区域
                        if item.hasImage, let image = item.thumbnailImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 60)
                                .clipped()
                                .cornerRadius(6)
                            
                            Text(item.imageDescription)
                                .font(.caption2)
                                .lineLimit(1)
                                .foregroundColor(.primary)
                        } else {
                            Text(item.typeIcon)
                                .font(.title2)
                            
                            Text(item.preview)
                                .font(.caption)
                                .lineLimit(2)
                                .foregroundColor(.primary)
                        }
                        
                        // 底部信息
                        HStack {
                            Text(item.sourceApp)
                                .font(.caption2)
                            Spacer()
                            Text(item.timeAgo)
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding(12)
                }
            } else {
                emptyView
            }
        }
        .widgetBackground()
    }
}

/// 中尺寸 Widget（4×2，显示 3 条）
struct MediumWidgetView: View {
    let items: [WidgetClipItem]
    
    var body: some View {
        Group {
            if items.isEmpty {
                emptyView
            } else {
                VStack(spacing: 0) {
                    // 标题栏
                    HStack {
                        Text(L10n.widgetTitle)  
                            .font(.caption)
                            .fontWeight(.semibold)
                        Spacer()
                        Link(destination: URL(string: "clipstack://refresh")!) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    
                    Divider()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                    
                    // 条目列表
                    VStack(spacing: 8) {
                        ForEach(items.prefix(3)) { item in
                            Link(destination: URL(string: "clipstack://copy/\(item.id.uuidString)")!) {
                                MediumItemRow(item: item)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
        }
        .widgetBackground()
    }
}

/// 中号 Widget 的单行视图
struct MediumItemRow: View {
    let item: WidgetClipItem
    
    var body: some View {
        HStack(spacing: 8) {
            if item.hasImage, let image = item.thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipped()
                    .cornerRadius(4)
            } else {
                Text(item.typeIcon)
                    .font(.body)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.preview)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                HStack {
                    Text(item.sourceApp)
                        .font(.caption2)
                    Text(L10n.widgetSeparator) 
                        .font(.caption2)
                    Text(item.timeAgo)
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if item.isStarred {
                Text("⭐")
                    .font(.caption2)
            }
        }
        .padding(.vertical, 4)
    }
}

/// 大尺寸 Widget（4×4，显示 5 条）
struct LargeWidgetView: View {
    let items: [WidgetClipItem]
    
    var body: some View {
        Group {
            if items.isEmpty {
                emptyView
            } else {
                VStack(spacing: 0) {
                    // 标题栏
                    HStack {
                        Text(L10n.widgetTitle)  
                            .font(.body)
                            .fontWeight(.semibold)
                        Spacer()
                        Link(destination: URL(string: "clipstack://refresh")!) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                Text(L10n.widgetRefresh) 
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    
                    Divider()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    
                    // 条目列表
                    VStack(spacing: 12) {
                        ForEach(items.prefix(5)) { item in
                            Link(destination: URL(string: "clipstack://copy/\(item.id.uuidString)")!) {
                                LargeItemRow(item: item)
                            }
                            
                            if item.id != items.prefix(5).last?.id {
                                Divider()
                                    .padding(.horizontal, 8)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
        }
        .widgetBackground()
    }
}

/// 大号 Widget 的单行视图
struct LargeItemRow: View {
    let item: WidgetClipItem
    
    var body: some View {
        HStack(spacing: 10) {
            if item.hasImage, let image = item.thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipped()
                    .cornerRadius(6)
            } else {
                Text(item.typeIcon)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.preview)
                    .font(.callout)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                HStack {
                    Text(item.sourceApp)
                        .font(.caption)
                    Text(L10n.widgetSeparator)
                        .font(.caption)
                    Text(item.timeAgo)
                        .font(.caption)
                    
                    if item.isStarred {
                        Text("⭐")
                            .font(.caption)
                    }
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: item.hasImage ? "photo" : "doc.on.doc")
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }
}

/// 空状态视图
private var emptyView: some View {
    VStack(spacing: 12) {
        Image(systemName: "clipboard")
            .font(.largeTitle)
            .foregroundColor(.secondary)
        
        Text(L10n.widgetEmptyTitle)
            .font(.caption)
            .foregroundColor(.secondary)
        
        Text(L10n.widgetEmptyMessage)
            .font(.caption2)
            .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}

// MARK: - Widget Entry View

struct ClipStackWidgetEntryView: View {
    var entry: ClipStackProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(item: entry.items.first)
        case .systemMedium:
            MediumWidgetView(items: entry.items)
        case .systemLarge:
            LargeWidgetView(items: entry.items)
        @unknown default:
            emptyView
        }
    }
}

// MARK: - Widget Configuration

@main
struct ClipStackWidget: Widget {
    let kind: String = "ClipStackWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClipStackProvider()) { entry in
            ClipStackWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(L10n.widgetConfigName)  
        .description(L10n.widgetConfigDescription)  
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - iOS 17+ containerBackground 兼容扩展

extension View {
    @ViewBuilder
    func widgetBackground() -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) {
                Color.clear
            }
        } else {
            self.background(Color.clear)
        }
    }
}

// MARK: - Preview

struct ClipStackWidget_Previews: PreviewProvider {
    static var previews: some View {
        let redPixelData: Data = {
            let size = CGSize(width: 100, height: 100)
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { context in
                UIColor.systemRed.setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            return image.jpegData(compressionQuality: 0.8) ?? Data()
        }()
        
        let sampleItems = [
            WidgetClipItem(
                id: UUID(),
                content: L10n.widgetPreviewText,
                contentType: "text",
                sourceApp: "WeChat",
                createdAt: Date().addingTimeInterval(-300),
                isStarred: false,
                imageData: nil,
                imageFormat: nil,
                imageWidth: 0,
                imageHeight: 0,
                thumbnailSize: 0
            ),
            WidgetClipItem(
                id: UUID(),
                content: "https://developer.apple.com/documentation/widgetkit",
                contentType: "link",
                sourceApp: "Safari",
                createdAt: Date().addingTimeInterval(-3600),
                isStarred: true,
                imageData: nil,
                imageFormat: nil,
                imageWidth: 0,
                imageHeight: 0,
                thumbnailSize: 0
            ),
            WidgetClipItem(
                id: UUID(),
                content: "",
                contentType: "image",
                sourceApp: L10n.widgetPreviewPhotoSource,
                createdAt: Date().addingTimeInterval(-7200),
                isStarred: false,
                imageData: redPixelData,
                imageFormat: "JPEG",
                imageWidth: 1920,
                imageHeight: 1080,
                thumbnailSize: Int(redPixelData.count)
            )
        ]
        
        Group {
            ClipStackWidgetEntryView(entry: ClipStackEntry(date: Date(), items: sampleItems))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName(L10n.widgetPreviewSmall)
            
            ClipStackWidgetEntryView(entry: ClipStackEntry(date: Date(), items: sampleItems))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName(L10n.widgetPreviewMedium)
            
            ClipStackWidgetEntryView(entry: ClipStackEntry(date: Date(), items: sampleItems))
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .previewDisplayName(L10n.widgetPreviewLarge)
        }
    }
}

