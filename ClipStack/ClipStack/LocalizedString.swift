//
//  LocalizedString.swift
//  ClipStack
//
//  多语言工具类
//  使用方法：Text(L10n.searchPlaceholder)
//

import Foundation

/// 本地化字符串枚举（命名简短，符合苹果规范）
enum L10n {
    // MARK: - 通用按钮
    static let cancel = NSLocalizedString("common.cancel", comment: "取消按钮")
    static let confirm = NSLocalizedString("common.confirm", comment: "确认按钮")
    static let delete = NSLocalizedString("common.delete", comment: "删除按钮")
    static let save = NSLocalizedString("common.save", comment: "保存按钮")
    static let done = NSLocalizedString("common.done", comment: "完成按钮")
    static let close = NSLocalizedString("common.close", comment: "关闭按钮")
    static let copy = NSLocalizedString("common.copy", comment: "复制按钮")
    static let share = NSLocalizedString("common.share", comment: "分享按钮")
    static let settings = NSLocalizedString("common.settings", comment: "设置按钮")
    
    // MARK: - 通用状态
    static let loading = NSLocalizedString("common.loading", comment: "加载中状态")
    static let error = NSLocalizedString("common.error", comment: "错误提示")
    static let success = NSLocalizedString("common.success", comment: "成功提示")
    static let empty = NSLocalizedString("common.empty", comment: "空状态")
    
    // MARK: - 通用时间
    static let justNow = NSLocalizedString("time.justNow", comment: "刚刚")
    static let minutesAgo = NSLocalizedString("time.minutesAgo", comment: "X分钟前")
    static let hoursAgo = NSLocalizedString("time.hoursAgo", comment: "X小时前")
    static let yesterday = NSLocalizedString("time.yesterday", comment: "昨天")
    static let daysAgo = NSLocalizedString("time.daysAgo", comment: "X天前")
    
    // 🔹 阶段 1 会添加更多 key（搜索、筛选、列表等）
    // MARK: - 主界面（ContentView）
    static let appTitle = NSLocalizedString("app.title", comment: "应用标题")
    
    // 搜索
    static let searchPlaceholder = NSLocalizedString("search.placeholder", comment: "搜索框占位符")
    static let searchNoResults = NSLocalizedString("search.noResults", comment: "搜索无结果")
    static let searchTryOtherKeywords = NSLocalizedString("search.tryOtherKeywords", comment: "搜索建议")
    
    // 筛选
    static let filterTitle = NSLocalizedString("filter.title", comment: "筛选标题")
    static let filterAll = NSLocalizedString("filter.all", comment: "全部筛选")
    static let filterText = NSLocalizedString("filter.text", comment: "文本筛选")
    static let filterLink = NSLocalizedString("filter.link", comment: "链接筛选")
    static let filterImage = NSLocalizedString("filter.image", comment: "图片筛选")
    static let filterStarred = NSLocalizedString("filter.starred", comment: "收藏筛选")
    static let filterEmpty = NSLocalizedString("filter.empty", comment: "筛选结果为空")
    static let filterSwitchToAll = NSLocalizedString("filter.switchToAll", comment: "切换到全部")
    
    // 空状态
    static let emptyHistoryTitle = NSLocalizedString("empty.history.title", comment: "空历史标题")
    static let emptyHistoryMessage = NSLocalizedString("empty.history.message", comment: "空历史提示")
    
    // 添加条目
    static let addItemTitle = NSLocalizedString("addItem.title", comment: "添加条目标题")
    static let addItemContentLabel = NSLocalizedString("addItem.contentLabel", comment: "内容标签")
    static let addItemSourceLabel = NSLocalizedString("addItem.sourceLabel", comment: "来源标签")
    static let addItemSourcePlaceholder = NSLocalizedString("addItem.sourcePlaceholder", comment: "来源占位符")
    
    // Toast 提示
    static let toastCopied = NSLocalizedString("toast.copied", comment: "复制成功")
    static let toastImageCopied = NSLocalizedString("toast.imageCopied", comment: "图片复制成功")
    static let toastStarred = NSLocalizedString("toast.starred", comment: "收藏成功")
    static let toastUnstarred = NSLocalizedString("toast.unstarred", comment: "取消收藏")
    static let toastStarredFull = NSLocalizedString("toast.starredFull", comment: "收藏已满")
    static let toastError = NSLocalizedString("toast.error", comment: "操作失败")
    
    // 来源
    static let sourceManual = NSLocalizedString("source.manual", comment: "手动添加")
    static let sourceUnknown = NSLocalizedString("source.unknown", comment: "未知来源")
    
    // 免费版限制
    static let freeLimitTitle = NSLocalizedString("freeLimit.title", comment: "免费版限制标题")
    static let freeLimitCount = NSLocalizedString("freeLimit.count", comment: "限制计数")
    
    // 操作按钮
    static let star = NSLocalizedString("filter.starred", comment: "收藏")
    static let unstar = NSLocalizedString("toast.unstarred", comment: "取消收藏")
    static let upgrade = NSLocalizedString("upgrade", comment: "升级")
    // 🔹 阶段 2 会添加键盘扩展专用 key
    // 🔹 阶段 3 会添加分享扩展专用 key
    // 🔹 阶段 4 会添加 Widget 专用 key
}

// MARK: - 格式化工具（支持参数替换）

extension L10n {
    /// 格式化带参数的字符串
    /// 例如：L10n.format("item.count", 5) → "5 个条目"
    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        let format = NSLocalizedString(key, comment: "")
        return String(format: format, arguments: arguments)
    }
}

// MARK: - 格式化工具（扩展）

extension L10n {
    /// 筛选为空的提示（例如："暂无图片内容"）
    static func filterEmptyMessage(for filterName: String) -> String {
        String(format: NSLocalizedString("filter.empty", comment: ""), filterName)
    }
}
