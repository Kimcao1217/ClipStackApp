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
    
    /// 用户是否是 Pro 版本
    @Published var isPro: Bool = false
    
    // MARK: - 常量配置
    
    /// 免费版历史记录限制（不含收藏）
    static let freeHistoryLimit = 5
    
    /// 免费版收藏限制
    static let freeStarredLimit = 5
    
    // MARK: - 初始化
    
    private init() {
        // 从 UserDefaults 读取 Pro 状态（作为缓存）
        self.isPro = UserDefaults.standard.bool(forKey: "isPro")
        print("🔐 ProManager 初始化，当前状态：\(isPro ? "Pro版" : "免费版")")
        
        // ✅ 只在主 App 中验证 StoreKit 状态（键盘扩展跳过）
        #if !KEYBOARD_EXTENSION
        Task {
            // 延迟导入，避免键盘扩展编译错误
            await verifyStoreKitStatus()
        }
        #endif
    }
    
    // MARK: - 公开方法
    
    /// 获取历史记录限制（不含收藏）
    func getHistoryLimit() -> Int {
        return isPro ? Int.max : ProManager.freeHistoryLimit
    }
    
    /// 获取收藏限制
    func getStarredLimit() -> Int {
        if isPro { return Int.max / 1000 }  // 不用满长整型，防止 CoreData 比较溢出
        return ProManager.freeStarredLimit
    }
    
    /// 设置 Pro 状态（由 StoreHelper 调用）
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
    
    // MARK: - 私有方法
    
    /// 验证 StoreKit 状态（仅主 App 调用）
    private func verifyStoreKitStatus() async {
        // 动态检查 StoreHelper 是否存在（避免键盘扩展编译错误）
        guard let storeHelperClass = NSClassFromString("ClipStack.StoreHelper") else {
            print("⚠️ StoreHelper 不可用（当前环境：键盘扩展）")
            return
        }
        
        // 使用反射调用 StoreHelper.shared.loadProducts()
        if let sharedMethod = class_getClassMethod(storeHelperClass, NSSelectorFromString("shared")),
           let loadProductsMethod = class_getInstanceMethod(storeHelperClass, NSSelectorFromString("loadProducts")) {
            print("✅ StoreHelper 可用，开始加载产品...")
            // 直接在 ClipStackApp 启动时调用 StoreHelper
        }
    }
}
