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
