//
//  ClipStackWidget.swift
//  ClipStackWidget
//
//  桌面小组件主文件
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

/// Widget 的时间线条目（每个时间点显示的数据快照）
struct ClipStackEntry: TimelineEntry {
    let date: Date  // 这个快照的时间
    let items: [WidgetClipItem]  // 要显示的剪贴板条目
}

// MARK: - Timeline Provider

/// 时间线提供器 - 负责告诉系统"什么时候显示什么内容"
struct ClipStackProvider: TimelineProvider {
    
    /// 占位视图（Widget 首次添加到桌面时显示）
    func placeholder(in context: Context) -> ClipStackEntry {
        print("📦 Widget placeholder 被调用")
        return ClipStackEntry(date: Date(), items: [
            WidgetClipItem(
                id: UUID(),
                content: "这是示例文本内容",
                contentType: "text",
                sourceApp: "ClipStack",
                createdAt: Date(),
                isStarred: false
            )
        ])
    }
    
    /// 快照视图（在 Widget 画廊中预览时显示）
    func getSnapshot(in context: Context, completion: @escaping (ClipStackEntry) -> Void) {
        print("📸 Widget getSnapshot 被调用")
        let items = WidgetDataProvider.shared.fetchRecentItems(limit: 5)
        let entry = ClipStackEntry(date: Date(), items: items)
        completion(entry)
    }
    
    /// 时间线（告诉系统"未来一段时间的刷新计划"）
    func getTimeline(in context: Context, completion: @escaping (Timeline<ClipStackEntry>) -> Void) {
        print("📅 Widget 正在生成时间线...")
        
        // 1. 加载最新数据
        let items = WidgetDataProvider.shared.fetchRecentItems(limit: 5)
        print("📊 Widget 加载到 \(items.count) 条数据")
        
        // 2. 创建当前时刻的条目
        let currentEntry = ClipStackEntry(date: Date(), items: items)
        
        // 3. 设置下次刷新时间（15分钟后）
        let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        
        // 4. 创建时间线（告诉系统：显示 currentEntry，然后在 nextUpdateDate 时刷新）
        let timeline = Timeline(entries: [currentEntry], policy: .after(nextUpdateDate))
        
        print("✅ Widget 时间线生成完成，下次刷新: \(nextUpdateDate)")
        
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
                        
                        // 内容
                        Text(item.typeIcon)
                            .font(.title2)
                        
                        Text(item.preview)
                            .font(.caption)
                            .lineLimit(2)
                            .foregroundColor(.primary)
                        
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
                        Text("📋 ClipStack")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Spacer()
                        // 手动刷新按钮
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
            Text(item.typeIcon)
                .font(.body)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.preview)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                HStack {
                    Text(item.sourceApp)
                        .font(.caption2)
                    Text("•")
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
                        Text("📋 ClipStack")
                            .font(.body)
                            .fontWeight(.semibold)
                        Spacer()
                        // 手动刷新按钮
                        Link(destination: URL(string: "clipstack://refresh")!) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                Text("刷新")
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
            Text(item.typeIcon)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.preview)
                    .font(.callout)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                HStack {
                    Text(item.sourceApp)
                        .font(.caption)
                    Text("•")
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
            
            Image(systemName: "doc.on.doc")
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
        
        Text("还没有剪贴板历史")
            .font(.caption)
            .foregroundColor(.secondary)
        
        Text("在应用中添加内容")
            .font(.caption2)
            .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}

// MARK: - Widget Entry View

/// Widget 主视图（根据尺寸显示不同布局）
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

/// Widget 配置（注册到系统）
@main
struct ClipStackWidget: Widget {
    let kind: String = "ClipStackWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClipStackProvider()) { entry in
            ClipStackWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("ClipStack")
        .description("快速访问最近的剪贴板历史")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - iOS 17+ containerBackground 兼容扩展

extension View {
    /// 为 Widget 添加背景（兼容 iOS 15-18）
    @ViewBuilder
    func widgetBackground() -> some View {
        if #available(iOS 17.0, *) {
            // iOS 17+ 使用新 API
            self.containerBackground(for: .widget) {
                Color.clear
            }
        } else {
            // iOS 15-16 使用旧方式
            self.background(Color.clear)
        }
    }
}

// MARK: - Preview

struct ClipStackWidget_Previews: PreviewProvider {
    static var previews: some View {
        let sampleItems = [
            WidgetClipItem(
                id: UUID(),
                content: "这是一个示例文本内容，用于测试 Widget 显示效果",
                contentType: "text",
                sourceApp: "微信",
                createdAt: Date().addingTimeInterval(-300),
                isStarred: false
            ),
            WidgetClipItem(
                id: UUID(),
                content: "https://developer.apple.com/documentation/widgetkit",
                contentType: "link",
                sourceApp: "Safari",
                createdAt: Date().addingTimeInterval(-3600),
                isStarred: true
            )
        ]
        
        Group {
            ClipStackWidgetEntryView(entry: ClipStackEntry(date: Date(), items: sampleItems))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            
            ClipStackWidgetEntryView(entry: ClipStackEntry(date: Date(), items: sampleItems))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
            
            ClipStackWidgetEntryView(entry: ClipStackEntry(date: Date(), items: sampleItems))
                .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}
