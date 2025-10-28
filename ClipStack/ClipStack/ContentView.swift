//
//  ContentView.swift
//  ClipStack
//
//  主界面视图 - 显示剪贴板历史记录列表

import SwiftUI
import CoreData
import WidgetKit
import UIKit

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var proManager = ProManager.shared
    
    // ✅ 改回 @FetchRequest（自动监听 Core Data 变化）
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ClipItem.createdAt, ascending: false)],
        animation: .default
    )
    private var allItems: FetchedResults<ClipItem>
    
    // ✅ 搜索和筛选用计算属性过滤（不重新查询数据库）
    @State private var searchText = ""
    @State private var selectedFilter: FilterType = .all
    
    
    // ✅ 计算属性：根据搜索和筛选过滤数据
    private var filteredItems: [ClipItem] {
        var items = Array(allItems)
        
        // 筛选类型
        switch selectedFilter {
        case .text:
            items = items.filter { $0.contentType == "text" }
        case .link:
            items = items.filter { $0.contentType == "link" }
        case .image:
            items = items.filter { $0.contentType == "image" }
        case .starred:
            items = items.filter { $0.isStarred }
        case .all:
            break
        }
        
        // 搜索文本
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items = items.filter { item in
                (item.content ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return items
    }
    
    @State private var showingAddSheet = false
    @State private var newItemContent = ""
    @State private var newItemSource = "手动添加"
    
    @State private var selectedImageItem: ClipItem?
    @State private var showingImageViewer = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if !proManager.isPro {
                    limitBannerView
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                
                searchBarView
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                filterSegmentedControl
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                if filteredItems.isEmpty {
                    emptyStateView
                } else {
                    clipItemsList
                }
            }
            .navigationTitle("📋 ClipStack")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .foregroundColor(.primary)
                    }
                }
            }
            .fullScreenCover(isPresented: $showingAddSheet) {
                AddItemSheetView(
                    content: $newItemContent,
                    source: $newItemSource,
                    onSave: { content, source in
                        addNewItem(content: content, source: source)
                    },
                    onCancel: {
                        dismissAddSheet()
                    }
                )
            }
        }
        .onAppear {
            setupDarwinNotificationObserver()
        }
        // ✅ 删除 onChange 监听（不需要手动刷新）
    }

    // MARK: - Darwin 跨进程通知监听
    @State private var lastHistoryToken: NSPersistentHistoryToken?

private func setupDarwinNotificationObserver() {
    DarwinNotificationCenter.shared.addObserver {
        print("🔔 检测到 Share Extension 保存数据，启动历史变更合并")
        mergePersistentHistoryChanges()
    }
}

/// 合并历史变更（Apple 推荐的做法）
private func mergePersistentHistoryChanges() {
    let container = PersistenceController.shared.container
    let viewContext = container.viewContext

    // ✅ 在后台队列执行
    container.performBackgroundTask { backgroundContext in
        // 获取最近的历史变更
        let fetchRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: self.lastHistoryToken)
        do {
            if let result = try backgroundContext.execute(fetchRequest) as? NSPersistentHistoryResult,
               let transactions = result.result as? [NSPersistentHistoryTransaction],
               !transactions.isEmpty {

                print("📦 合并 \(transactions.count) 个历史事务")

                // 保存最后 token，防止重复合并
                self.lastHistoryToken = transactions.last?.token

                // 合并到主 context（Apple 推荐方式）
                viewContext.perform {
                    for transaction in transactions {
                        viewContext.mergeChanges(fromContextDidSave: transaction.objectIDNotification())
                    }
                    print("✅ 主 App 已合并 Share Extension 修改")
                }
            }
        } catch {
            print("❌ 合并历史变更失败: \(error)")
        }
    }
}
    
    // MARK: - 子视图
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: searchText.isEmpty ? "clipboard" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                if !searchText.isEmpty {
                    Text("没有找到\"\(searchText)\"")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("试试其他关键词或切换筛选类型")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else if selectedFilter != .all {
                    Text("暂无\(selectedFilter.rawValue)内容")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("切换到\"全部\"查看所有内容")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("还没有剪贴板历史")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("从分享菜单或点击右上角的 + 按钮添加内容开始使用")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索历史内容...", text: $searchText)
                .textFieldStyle(.plain)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        // ✅ 删除 onChange（过滤在计算属性中自动完成）
    }
    
    private var filterSegmentedControl: some View {
        Picker("筛选", selection: $selectedFilter) {
            ForEach(FilterType.allCases, id: \.self) { filterType in
                Text(filterType.rawValue)
                    .tag(filterType)
            }
        }
        .pickerStyle(.segmented)
        // ✅ 删除 onChange（过滤在计算属性中自动完成）
    }
    
    private var clipItemsList: some View {
    List {
        ForEach(filteredItems) { clipItem in
            NavigationLink(
                destination: ClipItemDetailView(clipItem: clipItem)
            ) {
                ClipItemRowView(
                    clipItem: clipItem,
                    onImageTap: {
                        selectedImageItem = clipItem
                        showingImageViewer = true
                    }
                )
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            
            // ✅ 长按上下文菜单（快速操作）
            .contextMenu {
                // 1️⃣ 复制按钮（首位，最常用）
                Button {
                    copyItem(clipItem)
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                }
                
                // 2️⃣ 收藏按钮
                Button {
                    toggleStarred(clipItem)
                } label: {
                    Label(
                        clipItem.isStarred ? "取消收藏" : "收藏",
                        systemImage: clipItem.isStarred ? "star.slash" : "star.fill"
                    )
                }
                
                // 3️⃣ 分享按钮
                Button {
                    shareItem(clipItem)
                } label: {
                    Label("分享", systemImage: "square.and.arrow.up")
                }
                
                Divider()
                
                // 4️⃣ 删除按钮（危险操作放最后）
                Button(role: .destructive) {
                    deleteItem(clipItem)
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
            
            // ✅ 向左滑动：只显示删除（红色）
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    deleteItem(clipItem)
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
            
            // ✅ 向右滑动：只显示收藏（黄色）
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    toggleStarred(clipItem)
                } label: {
                    Label(
                        clipItem.isStarred ? "取消收藏" : "收藏",
                        systemImage: clipItem.isStarred ? "star.slash.fill" : "star.fill"
                    )
                }
                .tint(.yellow)
            }
        }
    }
    .listStyle(.plain)
    .refreshable {
        print("♻️ 下拉刷新（@FetchRequest 自动更新）")
    }
}
    
    // MARK: - 数据操作方法
    // ✅ 新增：复制条目内容
private func copyItem(_ item: ClipItem) {
    if item.hasImage {
        if let image = item.thumbnailImage {
            UIPasteboard.general.image = image
            showToast(message: "✅ 图片已复制")
        }
    } else {
        if let content = item.content {
            UIPasteboard.general.string = content
            showToast(message: "✅ 已复制")
        }
    }
    
    // ✅ 更新使用次数
    item.usageCount += 1
    item.lastUsedAt = Date()
    
    do {
        try viewContext.save()
        print("✅ 复制记录已保存（使用次数：\(item.usageCount)）")
    } catch {
        print("❌ 复制记录保存失败: \(error)")
    }
    
    // ✅ 触觉反馈
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)
}

// ✅ 新增：分享条目
private func shareItem(_ item: ClipItem) {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let rootVC = windowScene.windows.first?.rootViewController else {
        return
    }
    
    var activityItems: [Any] = []
    
    if item.hasImage, let image = item.thumbnailImage {
        activityItems = [image]
    } else if let content = item.content {
        activityItems = [content]
    }
    
    guard !activityItems.isEmpty else { return }
    
    let activityVC = UIActivityViewController(
        activityItems: activityItems,
        applicationActivities: nil
    )
    
    // ✅ iPad 支持（避免崩溃）
    if let popover = activityVC.popoverPresentationController {
        popover.sourceView = rootVC.view
        popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
        popover.permittedArrowDirections = []
    }
    
    rootVC.present(activityVC, animated: true)
}

    
    private func addNewItem(content: String, source: String) {
    let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedContent.isEmpty else { return }
    
    // ✅ 先在主上下文检查限制（同步执行）
    PersistenceController.enforceHistoryLimit(context: viewContext)
    
    // ✅ 再用后台上下文保存（异步执行）
    let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
    
    backgroundContext.perform {
        let newItem = ClipItem(
            content: trimmedContent,
            contentType: self.determineContentType(content: trimmedContent),
            sourceApp: source,
            context: backgroundContext
        )
        
        do {
            try backgroundContext.save()
            
            DispatchQueue.main.async {
                self.dismissAddSheet()
                print("✅ 新条目已保存，UI 将自动更新")
            }
        } catch {
            print("❌ 保存失败: \(error)")
        }
    }
}
    
    private func deleteItem(_ item: ClipItem) {
        // ✅ 直接在主上下文删除（SwiftUI 自动更新 UI）
        viewContext.delete(item)
        
        do {
            try viewContext.save()
            print("🗑️ 已删除条目")
        } catch {
            print("❌ 删除失败: \(error)")
        }
    }
    
    private func toggleStarred(_ item: ClipItem) {
    // ✅ 收藏前检查限制
    if !item.isStarred {
        let (currentCount, canStar) = PersistenceController.checkStarredLimit(context: viewContext)
        if !canStar {
            showToast(message: "⚠️ 收藏已满（\(currentCount)/\(ProManager.freeStarredLimit)），请先取消收藏其他条目")
            return
        }
    }
    
    // ✅ 添加触觉反馈（轻微震动）
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.impactOccurred()
    
    // ✅ 直接修改对象（SwiftUI 自动更新 UI）
    item.isStarred.toggle()
    
    do {
        try viewContext.save()
        
        // ✅ 显示优雅的 Toast 提示
        let message = item.isStarred ? "⭐ 已收藏" : "☆ 已取消收藏"
        showToast(message: message)
        print(message)
        
        // ✅ 取消收藏后检查历史记录限制
        if !item.isStarred {
            PersistenceController.enforceHistoryLimit(context: viewContext)
        }
    } catch {
        print("❌ 保存失败: \(error)")
        item.isStarred.toggle()  // 回滚
        
        // ❌ 回滚时再次震动（错误提示）
        let errorGenerator = UINotificationFeedbackGenerator()
        errorGenerator.notificationOccurred(.error)
    }
}
    
    private func showToast(message: String) {
    DispatchQueue.main.async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }
        
        // ✅ 创建原生风格的 Toast（类似 iOS 系统提示）
        let hud = UIView()
        hud.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        hud.layer.cornerRadius = 16
        hud.layer.shadowColor = UIColor.black.cgColor
        hud.layer.shadowOpacity = 0.15
        hud.layer.shadowOffset = CGSize(width: 0, height: 2)
        hud.layer.shadowRadius = 8
        hud.translatesAutoresizingMaskIntoConstraints = false
        hud.alpha = 0
        
        let label = UILabel()
        label.text = message
        label.textColor = .label
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        hud.addSubview(label)
        window.addSubview(hud)
        
        NSLayoutConstraint.activate([
            hud.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            hud.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -80),
            label.leadingAnchor.constraint(equalTo: hud.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: hud.trailingAnchor, constant: -20),
            label.topAnchor.constraint(equalTo: hud.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: hud.bottomAnchor, constant: -12)
        ])
        
        // ✅ 优雅的淡入淡出动画
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            hud.alpha = 1
            hud.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        }) { _ in
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn, animations: {
                hud.transform = .identity
            })
        }
        
        // ✅ 1.5 秒后自动消失
        UIView.animate(withDuration: 0.3, delay: 1.5, options: .curveEaseIn, animations: {
            hud.alpha = 0
            hud.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            hud.removeFromSuperview()
        }
    }
}
    
    private func dismissAddSheet() {
        showingAddSheet = false
        newItemContent = ""
        newItemSource = "手动添加"
    }
    
    private func determineContentType(content: String) -> String {
        if content.lowercased().hasPrefix("http://") || content.lowercased().hasPrefix("https://") {
            return "link"
        }
        return "text"
    }
    
    // MARK: - 限制提示横幅
    
    private var limitBannerView: some View {
    // ✅ 正确：统计所有条目，不受搜索/筛选影响
    let historyCount = allItems.filter { !$0.isStarred }.count
    let starredCount = allItems.filter { $0.isStarred }.count
    
    return HStack(spacing: 12) {
        Image(systemName: "info.circle.fill")
            .foregroundColor(.blue)
            .font(.title3)
        
        VStack(alignment: .leading, spacing: 2) {
            Text("免费版限制")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text("历史 \(historyCount)/5 • 收藏 \(starredCount)/5")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        Spacer()
        
        NavigationLink(destination: SettingsView()) {
            Text("升级")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue)
                .cornerRadius(8)
        }
    }
    .padding(12)
    .background(Color.blue.opacity(0.1))
    .cornerRadius(12)
}
}

// MARK: - 独立的添加条目弹窗视图

struct AddItemSheetView: View {
    @Binding var content: String
    @Binding var source: String
    let onSave: (String, String) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("内容")
                        .font(.headline)
                    
                    TextEditor(text: $content)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("来源应用")
                        .font(.headline)
                    
                    TextField("输入来源应用名称", text: $source)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("添加新条目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        onSave(content, source)
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}


// MARK: - 剪贴板条目行视图（⭐ 更新支持图片）

struct ClipItemRowView: View {
    @ObservedObject var clipItem: ClipItem
    
    let onImageTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // ✅ 左侧图标（带收藏角标）
            ZStack(alignment: .topLeading) {
                if clipItem.hasImage {
                    Button {
                        presentImageViewer(for: clipItem)
                    } label: {
                        if let thumbnailImage = clipItem.thumbnailImage {
                            Image(uiImage: thumbnailImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipped()
                                .cornerRadius(8)
                        } else {
                            Image(systemName: "photo")
                                .font(.title)
                                .foregroundColor(.secondary)
                                .frame(width: 60, height: 60)
                                .background(Color(.systemGray5))
                                .cornerRadius(8)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    VStack {
                        Text(clipItem.typeIcon)
                            .font(.title2)
                        Spacer()
                    }
                    .frame(width: 40, alignment: .center)
                }
                
                // ✅ 收藏角标（左上角小星星）
                if clipItem.isStarred {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 0.5)
                        .offset(x: -4, y: -4)
                }
            }
            
            // 主要内容
            VStack(alignment: .leading, spacing: 4) {
                if clipItem.hasImage {
                    Text(clipItem.imageFullDescription)
                        .font(.body)
                        .foregroundColor(.primary)
                } else {
                    Text(clipItem.previewContent)
                        .font(.body)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                
                HStack {
                    Label(clipItem.sourceApp ?? "未知", systemImage: "app.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(clipItem.relativeTimeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func presentImageViewer(for item: ClipItem) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            print("❌ 无法找到根视图控制器")
            return
        }
        
        let viewerVC = ImageViewerViewController(clipItem: item)
        rootVC.present(viewerVC, animated: true)
    }
}
