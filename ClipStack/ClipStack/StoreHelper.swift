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
        print("🛒 \(L10n.logStoreHelperInit)")  // ✅ 本地化
        
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
            print("⚠️ \(L10n.logProductsAlreadyLoaded)")  // ✅ 本地化
            return
        }
        
        isLoading = true
        print("📦 \(L10n.logLoadingProducts)...")  // ✅ 本地化
        
        do {
            let loadedProducts = try await Product.products(for: [
                ProductID.monthly,
                ProductID.yearly,
                ProductID.lifetime
            ])
            
            self.products = loadedProducts.sorted { $0.price < $1.price }
            
            print("✅ \(L10n.logProductsLoadedSuccess), \(L10n.logProductsCount): \(loadedProducts.count)")  // ✅ 本地化
            for product in loadedProducts {
                print("   - \(product.id): \(product.displayPrice)")
            }
        } catch {
            print("❌ \(L10n.logLoadProductsFailed): \(error)")  // ✅ 本地化
        }
        
        isLoading = false
    }
    
    /// 购买指定产品
    func purchase(_ product: Product) async {
        purchaseState = .purchasing
        print("🛒 \(L10n.logStartPurchase): \(product.displayName)")  // ✅ 本地化
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                purchaseState = .verifying
                print("🔐 \(L10n.logVerifyingPurchase)...")  // ✅ 本地化
                
                let transaction = try checkVerified(verification)
                
                // ✅ 解锁 Pro 权限
                await unlockPro(for: transaction)
                
                // ✅ 标记交易已完成
                await transaction.finish()
                
                purchaseState = .success
                print("✅ \(L10n.logPurchaseSuccess): \(product.displayName)")  // ✅ 本地化
                
            case .userCancelled:
                purchaseState = .idle
                print("⚠️ \(L10n.logPurchaseCancelled)")  // ✅ 本地化
                
            case .pending:
                purchaseState = .idle
                print("⏳ \(L10n.logPurchasePending)")  // ✅ 本地化
                
            @unknown default:
                purchaseState = .idle
                print("⚠️ \(L10n.logPurchaseUnknown)")  // ✅ 本地化
            }
            
        } catch {
            purchaseState = .failed(error.localizedDescription)
            print("❌ \(L10n.logPurchaseFailed): \(error)")  // ✅ 本地化
        }
        
        // ✅ 刷新订阅状态
        await updateSubscriptionStatus()
    }
    
    /// 恢复购买（从 App Store 拉取历史购买记录）
    func restorePurchases() async {
        print("🔄 \(L10n.logRestoreStart)...")  // ✅ 本地化
        purchaseState = .purchasing
        
        do {
            try await AppStore.sync()
            
            await updateSubscriptionStatus()
            
            if subscriptionStatus != .notSubscribed {
                purchaseState = .restored
                print("✅ \(L10n.logRestoreSuccess)")  // ✅ 本地化
            } else {
                purchaseState = .failed(L10n.logRestoreNoRecords)  // ✅ 本地化
                print("⚠️ \(L10n.logRestoreNoRecords)")  // ✅ 本地化
            }
            
        } catch {
            purchaseState = .failed(String(format: L10n.logRestoreFailed, error.localizedDescription))  // ✅ 本地化
            print("❌ \(L10n.logRestoreFailed): \(error)")  // ✅ 本地化
        }
    }
    
    /// 重置购买状态（用于关闭弹窗）
    func resetPurchaseState() {
        purchaseState = .idle
    }
    
    // MARK: - 私有方法
    
    /// 监听事务更新（✅ 修复：不重复触发 UI 更新）
    private func listenForTransactions() async {
        print("👂 \(L10n.logListeningTransactions)...")  // ✅ 本地化
        
        for await result in StoreTransaction.updates {
            do {
                let transaction = try checkVerified(result)
                
                // ✅ 只解锁权限，不触发 UI 弹窗
                await unlockProSilently(for: transaction)
                await transaction.finish()
                
                print("📬 \(L10n.logReceivedTransaction): \(transaction.productID)")  // ✅ 本地化
            } catch {
                print("❌ \(L10n.logTransactionVerifyFailed): \(error)")  // ✅ 本地化
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
        print("🔓 \(L10n.logUnlockPro): \(transaction.productID)")  // ✅ 本地化
        
        ProManager.shared.setProStatus(true)
        await updateSubscriptionStatus()
    }
    
    /// 静默解锁 Pro 权限（✅ 新增：不触发重复刷新）
    private func unlockProSilently(for transaction: StoreTransaction) async {
        print("🔓 \(L10n.logUnlockProSilent): \(transaction.productID)")  // ✅ 本地化
        
        ProManager.shared.setProStatus(true)
        await updateSubscriptionStatusSilently()
    }
    
    /// 更新订阅状态（✅ 优化：按优先级检查）
    private func updateSubscriptionStatus() async {
        print("🔍 \(L10n.logCheckingSubscription)...")  // ✅ 本地化
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
                    print("✅ \(L10n.logCurrentStatusLifetime) (ID: \(transaction.id))")  // ✅ 本地化
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
                    print("✅ \(L10n.logCurrentStatusYearly) (ID: \(transaction.id), \(L10n.logExpiration): \(transaction.expirationDate?.formatted() ?? L10n.timeUnknown))")  // ✅ 本地化
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
                    print("✅ \(L10n.logCurrentStatusMonthly) (ID: \(transaction.id), \(L10n.logExpiration): \(transaction.expirationDate?.formatted() ?? L10n.timeUnknown))")  // ✅ 本地化
                    return
                }
            }
        }
        
        // 没有任何有效订阅
        subscriptionStatus = .notSubscribed
        ProManager.shared.setProStatus(false)
        print("⚠️ \(L10n.logCurrentStatusNone)")  // ✅ 本地化
    }
    
    /// 检查交易是否有效（✅ 新增：验证过期时间和撤销状态）
    private func isTransactionValid(_ transaction: StoreTransaction) -> Bool {
        // 1. 检查是否被撤销
        if transaction.revocationDate != nil {
            print("⚠️ \(L10n.logTransactionRevoked): \(transaction.productID)")  // ✅ 本地化
            return false
        }
        
        // 2. 检查是否过期（仅订阅类型）
        if let expirationDate = transaction.expirationDate {
            let now = Date()
            if expirationDate < now {
                print("⚠️ \(L10n.logSubscriptionExpired): \(transaction.productID), \(L10n.logExpiration): \(expirationDate)")  // ✅ 本地化
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
