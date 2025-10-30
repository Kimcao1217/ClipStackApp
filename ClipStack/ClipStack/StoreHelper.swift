//
//  StoreHelper.swift
//  ClipStack
//
//  StoreKit 2 购买管理器 - 处理产品查询、购买、验证
//

import StoreKit
import SwiftUI

// ✅ 添加类型别名避免命名冲突
typealias StoreTransaction = StoreKit.Transaction

/// StoreKit 2 购买管理器（单例）
@MainActor
class StoreHelper: ObservableObject {
    
    // MARK: - 单例
    
    static let shared = StoreHelper()
    
    // MARK: - 产品 ID（必须与 Configuration.storekit 一致）
    
    private enum ProductID {
        static let monthly = "clipstack.pro.monthly"
        static let yearly = "clipstack.pro.yearly"
        static let lifetime = "clipstack.pro.lifetime"
    }
    
    // MARK: - 发布属性
    
    /// 所有可购买的产品（异步加载完成后填充）
    @Published private(set) var products: [Product] = []
    
    /// 是否正在加载产品
    @Published private(set) var isLoading = false
    
    /// 当前的购买状态（用于显示 Loading）
    @Published private(set) var purchaseState: PurchaseState = .idle
    
    /// 用户当前的订阅状态
    @Published private(set) var subscriptionStatus: SubscriptionStatus = .notSubscribed
    
    // MARK: - 枚举定义
    
    enum PurchaseState: Equatable {
        case idle              // 空闲状态
        case purchasing        // 正在购买
        case verifying         // 正在验证
        case success           // 购买成功
        case restored          // 恢复购买成功
        case failed(String)    // 购买失败
        
        static func == (lhs: PurchaseState, rhs: PurchaseState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle):
                return true
            case (.purchasing, .purchasing):
                return true
            case (.verifying, .verifying):
                return true
            case (.success, .success):
                return true
            case (.restored, .restored):
                return true
            case (.failed(let lhsMsg), .failed(let rhsMsg)):
                return lhsMsg == rhsMsg
            default:
                return false
            }
        }
    }
    
    enum SubscriptionStatus {
        case notSubscribed     // 未订阅
        case monthly           // 月付订阅中
        case yearly            // 年付订阅中
        case lifetime          // 终身买断
    }
    
    // MARK: - 事务监听任务
    
    private var transactionListener: Task<Void, Error>?
    
    // MARK: - 初始化
    
    private init() {
        print("🛒 StoreHelper 初始化")
        
        // 启动事务监听器（监听购买状态变化）
        transactionListener = Task {
            await listenForTransactions()
        }
        
        // 异步加载产品列表
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - 公开方法
    
    /// 加载产品列表（从 App Store 获取）
    func loadProducts() async {
        guard products.isEmpty else {
            print("⚠️ 产品已加载，跳过重复请求")
            return
        }
        
        isLoading = true
        print("📦 开始加载产品列表...")
        
        do {
            let loadedProducts = try await Product.products(for: [
                ProductID.monthly,
                ProductID.yearly,
                ProductID.lifetime
            ])
            
            self.products = loadedProducts.sorted { $0.price < $1.price }
            
            print("✅ 加载成功，共 \(loadedProducts.count) 个产品:")
            for product in loadedProducts {
                print("   - \(product.id): \(product.displayPrice)")
            }
        } catch {
            print("❌ 加载产品失败: \(error)")
        }
        
        isLoading = false
    }
    
    /// 购买指定产品
    func purchase(_ product: Product) async {
        purchaseState = .purchasing
        print("🛒 开始购买: \(product.displayName)")
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                purchaseState = .verifying
                print("🔐 开始验证购买...")
                
                let transaction = try checkVerified(verification)
                
                // ✅ 解锁 Pro 权限
                await unlockPro(for: transaction)
                
                // ✅ 标记交易已完成
                await transaction.finish()
                
                purchaseState = .success
                print("✅ 购买成功: \(product.displayName)")
                
            case .userCancelled:
                purchaseState = .idle
                print("⚠️ 用户取消购买")
                
            case .pending:
                purchaseState = .idle
                print("⏳ 购买等待确认（家长批准或支付验证）")
                
            @unknown default:
                purchaseState = .idle
                print("⚠️ 未知购买结果")
            }
            
        } catch {
            purchaseState = .failed(error.localizedDescription)
            print("❌ 购买失败: \(error)")
        }
        
        // ✅ 刷新订阅状态
        await updateSubscriptionStatus()
    }
    
    /// 恢复购买（从 App Store 拉取历史购买记录）
    func restorePurchases() async {
        print("🔄 开始恢复购买...")
        purchaseState = .purchasing
        
        do {
            try await AppStore.sync()
            
            await updateSubscriptionStatus()
            
            if subscriptionStatus != .notSubscribed {
                purchaseState = .restored
                print("✅ 恢复购买成功")
            } else {
                purchaseState = .failed("未找到有效购买记录")
                print("⚠️ 未找到有效购买")
            }
            
        } catch {
            purchaseState = .failed("恢复失败: \(error.localizedDescription)")
            print("❌ 恢复购买失败: \(error)")
        }
    }
    
    /// 重置购买状态（用于关闭弹窗）
    func resetPurchaseState() {
        purchaseState = .idle
    }
    
    // MARK: - 私有方法
    
    /// 监听事务更新（✅ 修复：不重复触发 UI 更新）
    private func listenForTransactions() async {
        print("👂 开始监听事务更新...")
        
        for await result in StoreTransaction.updates {
            do {
                let transaction = try checkVerified(result)
                
                // ✅ 只解锁权限，不触发 UI 弹窗
                await unlockProSilently(for: transaction)
                await transaction.finish()
                
                print("📬 收到新事务: \(transaction.productID)")
            } catch {
                print("❌ 事务验证失败: \(error)")
            }
        }
    }
    
    /// 验证交易签名（防止越狱破解）
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    /// 解锁 Pro 权限（会触发 UI 更新）
    private func unlockPro(for transaction: StoreTransaction) async {
        print("🔓 解锁 Pro: \(transaction.productID)")
        
        ProManager.shared.setProStatus(true)
        await updateSubscriptionStatus()
    }
    
    /// 静默解锁 Pro 权限（✅ 新增：不触发重复刷新）
    private func unlockProSilently(for transaction: StoreTransaction) async {
        print("🔓 静默解锁 Pro: \(transaction.productID)")
        
        ProManager.shared.setProStatus(true)
        await updateSubscriptionStatusSilently()
    }
    
    /// 更新订阅状态（✅ 优化：按优先级检查）
    private func updateSubscriptionStatus() async {
        print("🔍 检查订阅状态...")
        await updateSubscriptionStatusSilently()
    }
    
    /// 静默更新订阅状态（✅ 修复：检查交易有效期）
    private func updateSubscriptionStatusSilently() async {
        // ✅ 优先级：终身 > 年付 > 月付
        
        // 检查终身买断
        if let lifetimeTransaction = await StoreTransaction.currentEntitlement(for: ProductID.lifetime) {
            if case .verified(let transaction) = lifetimeTransaction {
                // ✅ 检查交易是否有效（未撤销、未过期）
                if isTransactionValid(transaction) {
                    subscriptionStatus = .lifetime
                    ProManager.shared.setProStatus(true)
                    print("✅ 当前状态: 终身买断 (ID: \(transaction.id))")
                    return
                }
            }
        }
        
        // 检查年付订阅
        if let yearlyTransaction = await StoreTransaction.currentEntitlement(for: ProductID.yearly) {
            if case .verified(let transaction) = yearlyTransaction {
                if isTransactionValid(transaction) {
                    subscriptionStatus = .yearly
                    ProManager.shared.setProStatus(true)
                    print("✅ 当前状态: 年付订阅 (ID: \(transaction.id), 到期: \(transaction.expirationDate?.formatted() ?? "未知"))")
                    return
                }
            }
        }
        
        // 检查月付订阅
        if let monthlyTransaction = await StoreTransaction.currentEntitlement(for: ProductID.monthly) {
            if case .verified(let transaction) = monthlyTransaction {
                if isTransactionValid(transaction) {
                    subscriptionStatus = .monthly
                    ProManager.shared.setProStatus(true)
                    print("✅ 当前状态: 月付订阅 (ID: \(transaction.id), 到期: \(transaction.expirationDate?.formatted() ?? "未知"))")
                    return
                }
            }
        }
        
        // 没有任何有效订阅
        subscriptionStatus = .notSubscribed
        ProManager.shared.setProStatus(false)
        print("⚠️ 当前状态: 未订阅")
    }
    
    /// 检查交易是否有效（✅ 新增：验证过期时间和撤销状态）
    private func isTransactionValid(_ transaction: StoreTransaction) -> Bool {
        // 1. 检查是否被撤销
        if transaction.revocationDate != nil {
            print("⚠️ 交易已撤销: \(transaction.productID)")
            return false
        }
        
        // 2. 检查是否过期（仅订阅类型）
        if let expirationDate = transaction.expirationDate {
            let now = Date()
            if expirationDate < now {
                print("⚠️ 订阅已过期: \(transaction.productID), 过期时间: \(expirationDate)")
                return false
            }
        }
        
        // 3. 对于自动续期订阅，检查是否有更高级的订阅替代
        // （StoreKit 2 会自动处理，这里只需确保当前交易有效）
        
        return true
    }
}

// MARK: - 错误定义

enum StoreError: Error {
    case failedVerification
}
