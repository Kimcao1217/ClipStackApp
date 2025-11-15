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
    @StateObject private var syncManager = CloudKitSyncManager.shared  // ✅ 新增
    
    // ✅ @FetchRequest 自动监听 Core Data 变化（包括 CloudKit 同步）
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
    @State private var newItemSource = ""
    
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
                
                // ✅ 新增：同步状态横幅（仅在同步中或失败时显示）
                if case .inProgress = syncManager.syncStatus {
                    syncStatusBanner
                        .padding(.horizontal)
                        .padding(.top, 8)
                } else if case .failed = syncManager.syncStatus {
                    syncStatusBanner
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
            .navigationTitle(L10n.appTitle)
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
                        // ✅ 根据同步状态显示不同图标
                        ZStack {
                            Image(systemName: "gearshape")
                                .foregroundColor(.primary)
                            
                            // 同步中显示小徽章
                            if case .inProgress = syncManager.syncStatus {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 8, y: -8)
                            }
                        }
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
        // ❌ 删除：不再需要手动监听 Darwin 通知
        // ✅ @FetchRequest 会自动接收 CloudKit 的变更
    }

    // ✅ 新增：同步状态横幅
    private var syncStatusBanner: some View {
        HStack(spacing: 12) {
            if case .inProgress = syncManager.syncStatus {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Image(systemName: syncManager.syncStatus.iconName)
                    .foregroundColor(syncStatusColor)
            }
            
            Text(syncManager.syncStatus.displayText)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(syncStatusBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(syncStatusColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var syncStatusColor: Color {
        switch syncManager.syncStatus {
        case .notStarted:
            return .secondary
        case .inProgress:
            return .blue
        case .succeeded:
            return .green
        case .failed:
            return .red
        }
    }
    
    private var syncStatusBackgroundColor: Color {
        switch syncManager.syncStatus {
        case .notStarted:
            return Color(.systemGray6)
        case .inProgress:
            return Color.blue.opacity(0.1)
        case .succeeded:
            return Color.green.opacity(0.1)
        case .failed:
            return Color.red.opacity(0.1)
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
                    Text(L10n.format("search.noResults", searchText))
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text(L10n.searchTryOtherKeywords)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
               } else if selectedFilter != .all {
    Text(L10n.filterEmptyMessage(for: selectedFilter.localizedName))
        .font(.title2)
        .fontWeight(.medium)
    
    Text(L10n.filterSwitchToAll)
        .font(.body)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
} else {
                    Text(L10n.emptyHistoryTitle)
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text(L10n.emptyHistoryMessage)
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
            
            TextField(L10n.searchPlaceholder, text: $searchText)
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
    }
    
    private var filterSegmentedControl: some View {
        Picker(L10n.filterTitle, selection: $selectedFilter) {
            ForEach(FilterType.allCases, id: \.self) { filterType in
                Text(filterType.localizedName)
                    .tag(filterType)
            }
        }
        .pickerStyle(.segmented)
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
            
            .contextMenu {
                Button {
                    copyItem(clipItem)
                } label: {
                    Label(L10n.copy, systemImage: "doc.on.doc")
                }
                
                Button {
                    toggleStarred(clipItem)
                } label: {
                    Label(
                        clipItem.isStarred ? L10n.unstar : L10n.star,
                        systemImage: clipItem.isStarred ? "star.slash" : "star.fill"
                    )
                }
                
                Button {
                    shareItem(clipItem)
                } label: {
                    Label(L10n.share, systemImage: "square.and.arrow.up")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    deleteItem(clipItem)
                } label: {
                    Label(L10n.delete, systemImage: "trash")
                }
            }
            
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    deleteItem(clipItem)
                } label: {
                    Label(L10n.delete, systemImage: "trash")
                }
            }
            
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    toggleStarred(clipItem)
                } label: {
                    Label(
                        clipItem.isStarred ? L10n.unstar : L10n.star,
                        systemImage: clipItem.isStarred ? "star.slash.fill" : "star.fill"
                    )
                }
                .tint(.yellow)
            }
        }
    }
    .listStyle(.plain)
    .refreshable {
        // ✅ 下拉刷新：手动触发同步
        print("♻️ 用户下拉刷新")
        syncManager.manualSync()
    }
}
    
    // MARK: - 数据操作方法
    
    private func copyItem(_ item: ClipItem) {
    if item.hasImage {
        if let image = item.thumbnailImage {
            UIPasteboard.general.image = image
            showToast(message: L10n.toastImageCopied)
        }
    } else {
        if let content = item.content {
            UIPasteboard.general.string = content
            showToast(message: L10n.toastCopied)
        }
    }
    
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)
}

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

    dismissAddSheet()

    // ✅ 使用后台 context 保存
    let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
    backgroundContext.perform {
        let newItem = ClipItem(
            content: trimmedContent,
            contentType: self.determineContentType(content: trimmedContent),
            sourceApp: source.isEmpty ? ClipItemSource.manual.rawValue : source,
            context: backgroundContext
        )

        do {
            try backgroundContext.save()
            print("✅ 新条目已保存")
            
            // ✅ 保存后会自动触发 CloudKit 同步
            // ✅ @FetchRequest 会自动更新 UI
            
            DispatchQueue.main.async {
                WidgetCenter.shared.reloadAllTimelines()
                print("🔄 已通知 Widget 刷新")
            }
            
            // 检查免费版限制
            DispatchQueue.global(qos: .utility).async {
                let cleanupContext = PersistenceController.shared.container.newBackgroundContext()
                cleanupContext.perform {
                    _ = PersistenceController.enforceHistoryLimit(context: cleanupContext)
                }
            }
        } catch {
            print("❌ 保存失败: \(error)")
        }
    }
}

    
    private func deleteItem(_ item: ClipItem) {
    let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
    let objectID = item.objectID
    
    backgroundContext.perform {
        guard let bgItem = try? backgroundContext.existingObject(with: objectID) as? ClipItem else {
            return
        }
        
        backgroundContext.delete(bgItem)
        
        do {
            try backgroundContext.save()
            print("🗑️ 已删除条目")
            
            DispatchQueue.main.async {
                WidgetCenter.shared.reloadAllTimelines()
                print("🔄 已通知 Widget 刷新")
            }
        } catch {
            print("❌ 删除失败: \(error)")
        }
    }
}
    
    private func toggleStarred(_ item: ClipItem) {
    if !item.isStarred {
        let request: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
        request.predicate = NSPredicate(format: "isStarred == %@", NSNumber(value: true))
        
        do {
            let count = try viewContext.count(for: request)
            if !ProManager.shared.isPro && count >= ProManager.freeStarredLimit {
                showToast(message: String(format: NSLocalizedString("toast.starredFull", comment: ""), count, ProManager.freeStarredLimit))
                return
            }
        } catch {
            return
        }
    }
    
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.impactOccurred()
    
    let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
    let objectID = item.objectID
    
    backgroundContext.perform {
        guard let bgItem = try? backgroundContext.existingObject(with: objectID) as? ClipItem else {
            return
        }
        
        let willBeStarred = !bgItem.isStarred
        bgItem.isStarred = willBeStarred
        
        do {
            try backgroundContext.save()
            
            DispatchQueue.main.async {
                let message = willBeStarred ? L10n.toastStarred : L10n.toastUnstarred
                self.showToast(message: message)
                print(message)
                
                WidgetCenter.shared.reloadAllTimelines()
                print("🔄 已通知 Widget 刷新")
            }
            
            if !willBeStarred {
                DispatchQueue.global(qos: .utility).async {
                    let cleanupContext = PersistenceController.shared.container.newBackgroundContext()
                    cleanupContext.perform {
                        _ = PersistenceController.enforceHistoryLimit(context: cleanupContext)
                    }
                }
            }
        } catch {
            print("❌ 保存失败: \(error)")
            DispatchQueue.main.async {
                let errorGenerator = UINotificationFeedbackGenerator()
                errorGenerator.notificationOccurred(.error)
                self.showToast(message: L10n.toastError)
            }
        }
    }
}
    
    private func showToast(message: String) {
    DispatchQueue.main.async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }
        
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
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            hud.alpha = 1
            hud.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        }) { _ in
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn, animations: {
                hud.transform = .identity
            })
        }
        
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
        newItemSource = ""
    }
    
    private func determineContentType(content: String) -> String {
        if content.lowercased().hasPrefix("http://") || content.lowercased().hasPrefix("https://") {
            return "link"
        }
        return "text"
    }
    
    // MARK: - 限制提示横幅
private var limitBannerView: some View {
    let historyCount = allItems.filter { !$0.isStarred }.count
    let starredCount = allItems.filter { $0.isStarred }.count
    
    return HStack(spacing: 12) {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 36, height: 36)
            
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
                .font(.system(size: 18))
        }
        
        VStack(alignment: .leading, spacing: 3) {
            Text(L10n.freeLimitTitle)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(String(format: NSLocalizedString("freeLimit.count", comment: ""), historyCount, starredCount))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        Spacer()
        
        NavigationLink(destination: SettingsView()) {
            Text(L10n.upgrade)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(10)
                .shadow(color: .blue.opacity(0.25), radius: 3, x: 0, y: 2)
        }
    }
    .padding(14)
    .background(
        RoundedRectangle(cornerRadius: 14)
            .fill(Color(.systemBackground))
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    )
    .overlay(
        RoundedRectangle(cornerRadius: 14)
            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
    )
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
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.addItemContentLabel)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextEditor(text: $content)
                        .frame(minHeight: 140)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(.systemGray4), lineWidth: 0.5)
                        )
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.addItemSourceLabel)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField(L10n.addItemSourcePlaceholder, text: $source)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Spacer()
            }
            .padding(20)
            .navigationTitle(L10n.addItemTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.cancel) {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.save) {
                        onSave(content, source)
                    }
                    .font(.body.weight(.semibold))
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - 剪贴板条目行视图

struct ClipItemRowView: View {
    @ObservedObject var clipItem: ClipItem
    
    let onImageTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
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
                
                if clipItem.isStarred {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 0.5)
                        .offset(x: -4, y: -4)
                }
            }
            
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
                    Label(clipItem.displaySourceApp, systemImage: "app.fill")
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
