//
//  PaywallView.swift
//  ClipStack
//
//  付费墙界面 - 展示 3 个套餐选项并处理购买流程
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeHelper = StoreHelper.shared
    
    // ✅ 修复：用产品 ID 而不是索引
    @State private var selectedProductID: String = "clipstack.pro.yearly"
    
    // 控制显示购买结果弹窗
    @State private var showResultAlert = false
    @State private var resultMessage = ""
    @State private var shouldDismissAfterAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景渐变
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 头部标题
                        headerView
                        
                        // 功能特性列表
                        featuresView
                        
                        // 3 个套餐卡片
                        if storeHelper.isLoading {
                            ProgressView("加载套餐中...")
                                .padding(.vertical, 60)
                        } else if storeHelper.products.isEmpty {
                            errorView
                        } else {
                            productCardsView
                        }
                        
                        // 购买按钮
                        purchaseButton
                        
                        // 恢复购买按钮
                        restoreButton
                        
                        // 法律条款
                        legalLinksView
                    }
                    .padding()
                }
            }
            .navigationTitle("升级到 Pro 版")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .alert("购买结果", isPresented: $showResultAlert) {
                Button("好的") {
                    if shouldDismissAfterAlert {
                        dismiss()
                    }
                }
            } message: {
                Text(resultMessage)
            }
            .onChange(of: storeHelper.purchaseState) { newState in
                handlePurchaseStateChange(newState)
            }
        }
    }
    
    // MARK: - 子视图
    
    /// 头部标题区域
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .yellow.opacity(0.3), radius: 10, x: 0, y: 5)
            
            Text("解锁全部功能")
                .font(.title)
                .fontWeight(.bold)
            
            Text("无限制使用 ClipStack")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
    }
    
    /// 功能特性列表
    private var featuresView: some View {
        VStack(alignment: .leading, spacing: 16) {
            FeatureRow(icon: "infinity", title: "无限历史记录", description: "保存任意数量的剪贴板内容")
            FeatureRow(icon: "star.fill", title: "无限收藏", description: "收藏重要内容不受限制")
            FeatureRow(icon: "icloud.fill", title: "iCloud 同步", description: "多设备自动同步（即将推出）")
            FeatureRow(icon: "sparkles", title: "优先支持", description: "新功能优先体验")
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
    }
    
    /// 套餐卡片列表（✅ 修复：按固定顺序显示）
    private var productCardsView: some View {
        VStack(spacing: 12) {
            // ✅ 按价格排序：月付 < 年付 < 终身
            ForEach(storeHelper.products.sorted(by: { $0.price < $1.price }), id: \.id) { product in
                ProductCard(
                    product: product,
                    isSelected: selectedProductID == product.id,
                    isRecommended: product.id == "clipstack.pro.yearly",
                    onTap: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedProductID = product.id
                        }
                        
                        // 触觉反馈
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                )
            }
        }
    }
    
    /// 购买按钮
    private var purchaseButton: some View {
        Button {
            Task {
                await purchaseSelectedProduct()
            }
        } label: {
            HStack {
                if case .purchasing = storeHelper.purchaseState {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if case .verifying = storeHelper.purchaseState {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("验证中...")
                } else {
                    Text("立即购买")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .foregroundColor(.white)
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .disabled(storeHelper.purchaseState == .purchasing || storeHelper.purchaseState == .verifying)
    }
    
    /// 恢复购买按钮
    private var restoreButton: some View {
        Button {
            Task {
                await storeHelper.restorePurchases()
            }
        } label: {
            Text("恢复购买")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .disabled(storeHelper.purchaseState == .purchasing || storeHelper.purchaseState == .verifying)
    }
    
    /// 法律条款链接
    private var legalLinksView: some View {
        HStack(spacing: 20) {
            Link("隐私政策", destination: URL(string: "https://github.com/yourusername/clipstack/privacy")!)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("•")
                .foregroundColor(.secondary)
            
            Link("服务条款", destination: URL(string: "https://github.com/yourusername/clipstack/terms")!)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 20)
    }
    
    /// 错误提示视图
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("无法加载套餐")
                .font(.headline)
            
            Text("请检查网络连接后重试")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("重新加载") {
                Task {
                    await storeHelper.loadProducts()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 60)
    }
    
    // MARK: - 业务逻辑
    
    /// 购买选中的产品（✅ 修复：用产品 ID 查找）
    private func purchaseSelectedProduct() async {
        guard let selectedProduct = storeHelper.products.first(where: { $0.id == selectedProductID }) else {
            print("❌ 未找到选中的产品: \(selectedProductID)")
            return
        }
        
        print("🛒 准备购买: \(selectedProduct.displayName) (ID: \(selectedProduct.id))")
        await storeHelper.purchase(selectedProduct)
    }
    
    /// 处理购买状态变化
    private func handlePurchaseStateChange(_ state: StoreHelper.PurchaseState) {
        switch state {
        case .success:
            resultMessage = "🎉 购买成功！\n已解锁 Pro 版全部功能"
            shouldDismissAfterAlert = true
            showResultAlert = true
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
        case .restored:
            resultMessage = "✅ 恢复购买成功！\nPro 版权限已激活"
            shouldDismissAfterAlert = true
            showResultAlert = true
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
        case .failed(let error):
            resultMessage = "购买失败\n\(error)"
            shouldDismissAfterAlert = false
            showResultAlert = true
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            
        default:
            break
        }
        
        if showResultAlert {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                storeHelper.resetPurchaseState()
            }
        }
    }
}

// MARK: - 功能特性行视图

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - 产品卡片视图

struct ProductCard: View {
    let product: Product
    let isSelected: Bool
    let isRecommended: Bool
    let onTap: () -> Void
    
    private var discountInfo: String? {
        if product.id.contains("yearly") {
            return "省 33%"
        } else if product.id.contains("lifetime") {
            return "最划算"
        }
        return nil
    }
    
    private var productTitle: String {
        if product.id.contains("monthly") {
            return "月付订阅"
        } else if product.id.contains("yearly") {
            return "年付订阅"
        } else if product.id.contains("lifetime") {
            return "终身买断"
        }
        return product.displayName
    }
    
    private var productDescription: String {
        if product.id.contains("monthly") {
            return "按月支付，随时取消"
        } else if product.id.contains("yearly") {
            let monthlyPrice = (product.price as NSDecimalNumber).doubleValue / 12.0
            return String(format: "相当于每月 $%.2f", monthlyPrice)
        } else if product.id.contains("lifetime") {
            return "一次购买，永久使用"
        }
        return ""
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                if isRecommended {
                    HStack {
                        Spacer()
                        Text("🔥 最受欢迎")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.orange)
                            .cornerRadius(8, corners: [.topLeft, .topRight])
                        Spacer()
                    }
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(productTitle)
                                .font(.headline)
                            
                            if let discount = discountInfo {
                                Text(discount)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                        
                        Text(productDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(product.displayPrice)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? .blue : .primary)
                }
                .padding()
            }
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
            .cornerRadius(12)
            .shadow(color: isSelected ? .blue.opacity(0.2) : .clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        PaywallView()
    }
}
