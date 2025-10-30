//
//  SettingsView.swift
//  ClipStack
//
//  设置页面 - 显示账户信息、存储管理、版本信息
//

import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var proManager = ProManager.shared
    @StateObject private var storeHelper = StoreHelper.shared
    
    @State private var historyCount = 0
    @State private var starredCount = 0
    @State private var totalSize: Int64 = 0
    @State private var showPaywall = false
    
    // 确认弹窗的显示状态
    @State private var showClearHistoryAlert = false
    @State private var showClearStarredAlert = false
    @State private var showResetAllAlert = false
    
    var body: some View {
        List {
            // MARK: - 账户信息区
            
            Section {
                HStack(spacing: 16) {
                    Image(systemName: proManager.isPro ? "crown.fill" : "person.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(proManager.isPro ? .yellow : .blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(proManager.isPro ? "Pro 版本" : "免费版本")
                            .font(.headline)
                        
                        if proManager.isPro {
                            Text("无限制，感谢支持！")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("历史 \(historyCount)/5 • 收藏 \(starredCount)/5")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
                
                // 升级按钮或订阅状态
                if !proManager.isPro {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack {
                            Image(systemName: "star.fill")
                            Text("升级到 Pro 版")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                    }
                    .foregroundColor(.blue)
                } else {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pro 版已激活")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Text(subscriptionStatusText)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        // 订阅管理按钮（仅订阅用户显示）
                        if needsSubscriptionManagement {
                            Button {
                                openSubscriptionManagement()
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.up.forward.app")
                                    Text("管理订阅")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } header: {
                Text("账户")
            }
            
            // MARK: - 存储管理区
            
            Section {
                // 统计信息（只读显示）
                HStack {
                    Label("历史记录", systemImage: "clock")
                    Spacer()
                    Text("\(historyCount) 条")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label("收藏", systemImage: "star.fill")
                    Spacer()
                    Text("\(starredCount) 条")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label("占用空间", systemImage: "externaldrive")
                    Spacer()
                    Text(formatBytes(totalSize))
                        .foregroundColor(.secondary)
                }
                
                // 危险操作按钮
                Button {
                    showClearHistoryAlert = true
                } label: {
                    Label("清空历史记录", systemImage: "trash")
                }
                .foregroundColor(.orange)
                .disabled(historyCount == 0)
                
                Button {
                    showClearStarredAlert = true
                } label: {
                    Label("清空收藏", systemImage: "star.slash")
                }
                .foregroundColor(.orange)
                .disabled(starredCount == 0)
                
                Button {
                    showResetAllAlert = true
                } label: {
                    Label("完全重置", systemImage: "exclamationmark.triangle")
                }
                .foregroundColor(.red)
                .disabled(historyCount == 0 && starredCount == 0)
                
            } header: {
                Text("存储管理")
            } footer: {
                Text("• 清空历史记录：删除所有非收藏条目\n• 清空收藏：删除所有收藏条目\n• 完全重置：删除所有数据（不可恢复）")
                    .font(.caption)
            }
            
            // MARK: - 其他设置区
            
            Section {
                Link(destination: URL(string: "https://github.com/yourusername/clipstack")!) {
                    HStack {
                        Label("使用帮助", systemImage: "questionmark.circle")
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button {
                    // 后续实现反馈功能
                    sendFeedback()
                } label: {
                    Label("意见反馈", systemImage: "envelope")
                }
                
                Link(destination: URL(string: "https://apps.apple.com/app/idXXXXXXXXXX?action=write-review")!) {
                    HStack {
                        Label("App Store 评分", systemImage: "star")
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("其他")
            }
            
            // MARK: - 关于区
            
            Section {
                HStack {
                    Text("版本")
                    Spacer()
                    Text(getAppVersion())
                        .foregroundColor(.secondary)
                }
                
                // ⚠️ 测试用：手动切换 Pro 状态（正式版删除）
                #if DEBUG
                Button {
                    proManager.setProStatus(!proManager.isPro)
                    loadData()
                } label: {
                    HStack {
                        Label("测试：切换 Pro 状态", systemImage: "ant")
                        Spacer()
                        Text(proManager.isPro ? "ON" : "OFF")
                            .foregroundColor(proManager.isPro ? .green : .red)
                    }
                }
                #endif
            } header: {
                Text("关于")
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadData()
        }
        
        // MARK: - 确认弹窗
        
        .alert("清空历史记录", isPresented: $showClearHistoryAlert) {
            Button("取消", role: .cancel) { }
            Button("清空", role: .destructive) {
                clearHistory()
            }
        } message: {
            Text("将删除所有非收藏的 \(historyCount) 条历史记录\n收藏的内容会保留\n\n此操作不可恢复")
        }
        
        .alert("清空收藏", isPresented: $showClearStarredAlert) {
            Button("取消", role: .cancel) { }
            Button("清空", role: .destructive) {
                clearStarred()
            }
        } message: {
            Text("将删除所有 \(starredCount) 条收藏内容\n历史记录会保留\n\n此操作不可恢复")
        }
        
        .alert("完全重置", isPresented: $showResetAllAlert) {
            Button("取消", role: .cancel) { }
            Button("全部删除", role: .destructive) {
                resetAll()
            }
        } message: {
            Text("将删除所有数据：\n• \(historyCount) 条历史记录\n• \(starredCount) 条收藏\n\n此操作不可恢复！")
        }
        
        // 付费墙弹窗
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
    
    // MARK: - 数据加载
    
    private func loadData() {
        let historyRequest: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
        historyRequest.predicate = NSPredicate(format: "isStarred == %@", NSNumber(value: false))
        
        let starredRequest: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
        starredRequest.predicate = NSPredicate(format: "isStarred == %@", NSNumber(value: true))
        
        let allRequest: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
        
        do {
            historyCount = try viewContext.count(for: historyRequest)
            starredCount = try viewContext.count(for: starredRequest)
            
            let allItems = try viewContext.fetch(allRequest)
            totalSize = allItems.reduce(0) { $0 + ($1.thumbnailSize > 0 ? $1.thumbnailSize : 0) }
            
            print("📊 设置页面数据：历史 \(historyCount)，收藏 \(starredCount)，占用 \(formatBytes(totalSize))")
        } catch {
            print("❌ 加载设置数据失败: \(error)")
        }
    }
    
    // MARK: - 数据清理方法
    
    /// 清空历史记录（保留收藏）
    private func clearHistory() {
        let request: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
        request.predicate = NSPredicate(format: "isStarred == %@", NSNumber(value: false))
        
        performDelete(request: request, successMessage: "✅ 已清空 \(historyCount) 条历史记录")
    }
    
    /// 清空收藏（保留历史）
    private func clearStarred() {
        let request: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
        request.predicate = NSPredicate(format: "isStarred == %@", NSNumber(value: true))
        
        performDelete(request: request, successMessage: "✅ 已清空 \(starredCount) 条收藏")
    }
    
    /// 完全重置（删除所有数据）
    private func resetAll() {
        let request: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
        
        performDelete(request: request, successMessage: "✅ 已完全重置，所有数据已清空")
    }
    
    /// 通用删除方法（避免代码重复）
    private func performDelete(request: NSFetchRequest<ClipItem>, successMessage: String) {
        do {
            let items = try viewContext.fetch(request)
            let count = items.count
            
            // 逐个删除条目
            for item in items {
                viewContext.delete(item)
            }
            
            // 保存到数据库
            try viewContext.save()
            
            print(successMessage)
            
            // 刷新统计数据
            loadData()
            
            // 显示成功提示
            showSuccessHUD(message: successMessage)
            
        } catch {
            print("❌ 删除失败: \(error)")
            showErrorAlert(message: "删除失败：\(error.localizedDescription)")
        }
    }
    
    // MARK: - 工具方法
    
    private func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(bytes) / 1024.0 / 1024.0)
        }
    }
    
    private func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    /// 显示成功提示（HUD 样式）
    private func showSuccessHUD(message: String) {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                return
            }
            
            let hud = UILabel()
            hud.text = message
            hud.textColor = .white
            hud.backgroundColor = UIColor.black.withAlphaComponent(0.8)
            hud.font = .systemFont(ofSize: 15, weight: .medium)
            hud.textAlignment = .center
            hud.layer.cornerRadius = 12
            hud.layer.masksToBounds = true
            hud.numberOfLines = 0
            hud.translatesAutoresizingMaskIntoConstraints = false
            
            window.addSubview(hud)
            
            NSLayoutConstraint.activate([
                hud.centerXAnchor.constraint(equalTo: window.centerXAnchor),
                hud.centerYAnchor.constraint(equalTo: window.centerYAnchor),
                hud.widthAnchor.constraint(lessThanOrEqualTo: window.widthAnchor, multiplier: 0.8),
                hud.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
            ])
            
            hud.layoutIfNeeded()
            
            // 2 秒后自动消失
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                hud.removeFromSuperview()
            }
        }
    }
    
    /// 显示错误提示（Alert 样式）
    private func showErrorAlert(message: String) {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootVC = window.rootViewController else {
                return
            }
            
            let alert = UIAlertController(title: "操作失败", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "好的", style: .default))
            rootVC.present(alert, animated: true)
        }
    }
    
    /// 发送反馈（打开邮件客户端）
    private func sendFeedback() {
        let email = "your-email@example.com"
        let subject = "ClipStack 反馈"
        let body = """
        
        
        ---
        版本: \(getAppVersion())
        系统: \(UIDevice.current.systemVersion)
        设备: \(UIDevice.current.model)
        """
        
        let urlString = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
            print("📧 已打开邮件客户端")
        }
    }
    
    // MARK: - 订阅状态描述
    
    private var subscriptionStatusText: String {
        switch storeHelper.subscriptionStatus {
        case .lifetime:
            return "终身买断"
        case .yearly:
            return "年付订阅"
        case .monthly:
            return "月付订阅"
        case .notSubscribed:
            return "未订阅"
        }
    }
    
    // MARK: - 订阅管理
    
    /// 是否需要显示订阅管理按钮（终身买断不需要）
    private var needsSubscriptionManagement: Bool {
        return storeHelper.subscriptionStatus == .monthly || storeHelper.subscriptionStatus == .yearly
    }
    
    /// 打开 App Store 订阅管理页面
    private func openSubscriptionManagement() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else {
            return
        }
        
        UIApplication.shared.open(url)
        print("📱 已打开订阅管理页面")
    }
}

// MARK: - 预览

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
}
