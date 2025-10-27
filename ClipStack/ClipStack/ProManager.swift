//
//  ProManager.swift
//  ClipStack
//
//  Pro 版本管理器 - 管理用户的订阅状态和功能权限
//

import Foundation

/// Pro 版本管理器（单例）
class ProManager: ObservableObject {
    
    // MARK: - 单例
    
    static let shared = ProManager()
    
    // MARK: - 发布属性（自动触发 UI 更新）
    
    /// 用户是否是 Pro 版本（当前硬编码为 false，后续接入 StoreKit）
    @Published var isPro: Bool = false
    
    // MARK: - 常量配置
    
    /// 免费版历史记录限制（不含收藏）
    static let freeHistoryLimit = 5
    
    /// 免费版收藏限制
    static let freeStarredLimit = 5
    
    // MARK: - 初始化
    
    private init() {
        // 从 UserDefaults 读取 Pro 状态
        self.isPro = UserDefaults.standard.bool(forKey: "isPro")
        print("🔐 ProManager 初始化，当前状态：\(isPro ? "Pro版" : "免费版")")
    }
    
    // MARK: - 公开方法
    
    /// 获取历史记录限制（不含收藏）
    func getHistoryLimit() -> Int {
        return isPro ? Int.max : ProManager.freeHistoryLimit
    }
    
    /// 获取收藏限制
    func getStarredLimit() -> Int {
    if isPro { return Int.max / 1000 }      // 不用满长整型，防止 CoreData 比较溢出
    return ProManager.freeStarredLimit
}
    
    /// 设置 Pro 状态（手动解锁，仅用于测试）
    func setProStatus(_ status: Bool) {
    DispatchQueue.main.async {
        self.isPro = status
    }
    UserDefaults.standard.set(status, forKey: "isPro")
    print("🔓 Pro 状态已更新：\(status ? "Pro版" : "免费版")")
}
    
    /// 检查是否可以添加新的历史记录（不含收藏）
    /// - Parameter currentCount: 当前非收藏条目数量
    /// - Returns: 是否可以添加
    func canAddHistoryItem(currentCount: Int) -> Bool {
        if isPro {
            return true  // Pro 版无限制
        }
        return currentCount < ProManager.freeHistoryLimit
    }
    
    /// 检查是否可以收藏新条目
    /// - Parameter currentStarredCount: 当前收藏数量
    /// - Returns: 是否可以收藏
    func canStarItem(currentStarredCount: Int) -> Bool {
        if isPro {
            return true  // Pro 版无限制
        }
        return currentStarredCount < ProManager.freeStarredLimit
    }
}
