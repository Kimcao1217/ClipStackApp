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
                        Text(proManager.isPro ? L10n.settingsProVersion : L10n.settingsFreeVersion)  // ✅ 本地化
                            .font(.headline)
                        
                        if proManager.isPro {
                            Text(L10n.settingsUnlimitedThanks)  // ✅ 本地化
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text(String(format: L10n.freeLimitCount, historyCount, starredCount))  // ✅ 本地化
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
                            Text(L10n.settingsUpgradeToPro)  // ✅ 本地化
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
                                Text(L10n.settingsProActivated)  // ✅ 本地化
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
                                    Text(L10n.settingsManageSubscription)  // ✅ 本地化
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
                Text(L10n.settingsAccountHeader)  // ✅ 本地化
            }
            
            // MARK: - 存储管理区
            
            Section {
                // 统计信息（只读显示）
                HStack {
                    Label(L10n.settingsHistoryLabel, systemImage: "clock")  // ✅ 本地化
                    Spacer()
                    Text(String(format: L10n.settingsItemCount, historyCount))  // ✅ 本地化
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label(L10n.settingsStarredLabel, systemImage: "star.fill")  // ✅ 本地化
                    Spacer()
                    Text(String(format: L10n.settingsItemCount, starredCount))  // ✅ 本地化
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label(L10n.settingsStorageLabel, systemImage: "externaldrive")  // ✅ 本地化
                    Spacer()
                    Text(formatBytes(totalSize))
                        .foregroundColor(.secondary)
                }
                
                // 危险操作按钮
                Button {
                    showClearHistoryAlert = true
                } label: {
                    Label(L10n.settingsClearHistory, systemImage: "trash")  // ✅ 本地化
                }
                .foregroundColor(.orange)
                .disabled(historyCount == 0)
                
                Button {
                    showClearStarredAlert = true
                } label: {
                    Label(L10n.settingsClearStarred, systemImage: "star.slash")  // ✅ 本地化
                }
                .foregroundColor(.orange)
                .disabled(starredCount == 0)
                
                Button {
                    showResetAllAlert = true
                } label: {
                    Label(L10n.settingsResetAll, systemImage: "exclamationmark.triangle")  // ✅ 本地化
                }
                .foregroundColor(.red)
                .disabled(historyCount == 0 && starredCount == 0)
                
            } header: {
                Text(L10n.settingsStorageHeader)  // ✅ 本地化
            } footer: {
                Text(L10n.settingsStorageFooter)  // ✅ 本地化
                    .font(.caption)
            }
            
            // MARK: - 其他设置区
            
            Section {
                Button {
                    resetOnboarding()
                } label: {
                    Label(L10n.settingsResetOnboarding, systemImage: "arrow.counterclockwise")  // ✅ 本地化
                }

                Link(destination: URL(string: "https://github.com/yourusername/clipstack")!) {
                    HStack {
                        Label(L10n.settingsHelp, systemImage: "questionmark.circle")  // ✅ 本地化
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button {
                    sendFeedback()
                } label: {
                    Label(L10n.settingsFeedback, systemImage: "envelope")  // ✅ 本地化
                }
                
                Link(destination: URL(string: "https://apps.apple.com/app/idXXXXXXXXXX?action=write-review")!) {
                    HStack {
                        Label(L10n.settingsRateApp, systemImage: "star")  // ✅ 本地化
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(L10n.settingsOtherHeader)  // ✅ 本地化
            }
            
            // MARK: - 关于区
            
            Section {
                HStack {
                    Text(L10n.settingsVersion)  // ✅ 本地化
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
                        Label(L10n.settingsTestTogglePro, systemImage: "ant")  // ✅ 本地化
                        Spacer()
                        Text(proManager.isPro ? L10n.settingsTestOn : L10n.settingsTestOff)  // ✅ 本地化
                            .foregroundColor(proManager.isPro ? .green : .red)
                    }
                }
                #endif
            } header: {
                Text(L10n.settingsAboutHeader)  // ✅ 本地化
            }
        }
        .navigationTitle(L10n.settings)  // ✅ 本地化（复用已有 key）
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadData()
        }
        
        // MARK: - 确认弹窗
        
        .alert(L10n.settingsClearHistory, isPresented: $showClearHistoryAlert) {  // ✅ 本地化
            Button(L10n.cancel, role: .cancel) { }
            Button(L10n.settingsClearAction, role: .destructive) {  // ✅ 本地化
                clearHistory()
            }
        } message: {
            Text(String(format: L10n.alertClearHistoryMessage, historyCount))  // ✅ 本地化
        }
        
        .alert(L10n.settingsClearStarred, isPresented: $showClearStarredAlert) {  // ✅ 本地化
            Button(L10n.cancel, role: .cancel) { }
            Button(L10n.settingsClearAction, role: .destructive) {  // ✅ 本地化
                clearStarred()
            }
        } message: {
            Text(String(format: L10n.alertClearStarredMessage, starredCount))  // ✅ 本地化
        }
        
        .alert(L10n.settingsResetAll, isPresented: $showResetAllAlert) {  // ✅ 本地化
            Button(L10n.cancel, role: .cancel) { }
            Button(L10n.settingsDeleteAll, role: .destructive) {  // ✅ 本地化
                resetAll()
            }
        } message: {
            Text(String(format: L10n.alertResetAllMessage, historyCount, starredCount))  // ✅ 本地化
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
            
            print("📊 \(L10n.logSettingsDataLoaded(historyCount, starredCount, formatBytes(totalSize)))")  // ✅ 本地化
        } catch {
            print("❌ \(L10n.errorLoadSettingsFailed): \(error)")  // ✅ 本地化
        }
    }
    
    // MARK: - 数据清理方法
    
    /// 清空历史记录（保留收藏）
    private func clearHistory() {
        let request: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
        request.predicate = NSPredicate(format: "isStarred == %@", NSNumber(value: false))
        
        performDelete(
            request: request,
            successMessage: String(format: L10n.successClearHistory, historyCount)  // ✅ 本地化
        )
    }
    
    /// 清空收藏（保留历史）
    private func clearStarred() {
        let request: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
        request.predicate = NSPredicate(format: "isStarred == %@", NSNumber(value: true))
        
        performDelete(
            request: request,
            successMessage: String(format: L10n.successClearStarred, starredCount)  // ✅ 本地化
        )
    }
    
    /// 完全重置（删除所有数据）
    private func resetAll() {
        let request: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
        
        performDelete(
            request: request,
            successMessage: L10n.successResetAll  // ✅ 本地化
        )
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
            print("❌ \(L10n.errorDeleteFailed): \(error)")  // ✅ 本地化
            showErrorAlert(message: String(format: L10n.errorDeleteFailedDetail, error.localizedDescription))  // ✅ 本地化
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
            
            let alert = UIAlertController(
                title: L10n.errorAlertTitle,  // ✅ 本地化
                message: message,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: L10n.alertOk, style: .default))  // ✅ 本地化
            rootVC.present(alert, animated: true)
        }
    }
    
    /// 发送反馈（打开邮件客户端）
    private func sendFeedback() {
        let email = "your-email@example.com"
        let subject = L10n.feedbackSubject  // ✅ 本地化
        let body = String(
            format: L10n.feedbackBody,  // ✅ 本地化
            getAppVersion(),
            UIDevice.current.systemVersion,
            UIDevice.current.model
        )
        
        let urlString = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
            print("📧 \(L10n.logEmailOpened)")  // ✅ 本地化
        }
    }
    
    // MARK: - 订阅状态描述
    
    private var subscriptionStatusText: String {
        switch storeHelper.subscriptionStatus {
        case .lifetime:
            return L10n.subscriptionLifetime  // ✅ 本地化
        case .yearly:
            return L10n.subscriptionYearly  // ✅ 本地化
        case .monthly:
            return L10n.subscriptionMonthly  // ✅ 本地化
        case .notSubscribed:
            return L10n.subscriptionNone  // ✅ 本地化
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
        print("📱 \(L10n.logSubscriptionPageOpened)")  // ✅ 本地化
    }

    // MARK: - 重置引导流程

    /// 重置引导流程（用于测试或用户手动重新查看）
    private func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        print("🔄 \(L10n.logOnboardingReset)")  // ✅ 本地化
        
        showSuccessHUD(message: L10n.successOnboardingReset)  // ✅ 本地化
        
        // 触觉反馈
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
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
