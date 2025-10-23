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
    @EnvironmentObject private var dataRefreshManager: DataRefreshManager
    
    @State private var clipItems: [ClipItem] = []
    @State private var showingAddSheet = false
    @State private var newItemContent = ""
    @State private var newItemSource = "手动添加"
    @State private var isInitialLoadComplete = false
    
    // ⭐ 新增：图片预览相关状态
    @State private var selectedImageItem: ClipItem?
    @State private var showingImageViewer = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if clipItems.isEmpty && !isInitialLoadComplete {
                    loadingView
                } else if clipItems.isEmpty {
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
                        let startTime = CFAbsoluteTimeGetCurrent()
                        showingAddSheet = true
                        let timeElapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                        print("⏱️ 点击 + 按钮耗时: \(String(format: "%.2f", timeElapsed))ms")
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
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
            prewarmCoreDataInBackground()
            loadDataAsync()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                KeyboardPrewarmer.shared.prewarmInBackground()
                SheetPrewarmer.shared.prewarmAddItemSheet()
            }
        }
        .onChange(of: dataRefreshManager.lastRefreshDate) { _ in
            print("🎨 检测到远程变更，重新加载数据...")
            loadDataAsync()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            print("🔄 App返回前台，重新加载数据...")
            loadDataAsync()
        }
    }
    
    // MARK: - 性能优化：Core Data 预热和异步加载
    
    private func prewarmCoreDataInBackground() {
        DispatchQueue.global(qos: .userInitiated).async {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
            
            let fetchRequest: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
            fetchRequest.fetchLimit = 1
            
            do {
                _ = try backgroundContext.fetch(fetchRequest)
                let timeElapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                print("🔥 Core Data 预热完成，耗时: \(String(format: "%.2f", timeElapsed))ms")
            } catch {
                print("⚠️ Core Data 预热失败: \(error)")
            }
        }
    }
    
    private func loadDataAsync() {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        DispatchQueue.global(qos: .userInitiated).async {
            let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
            
            let fetchRequest: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipItem.createdAt, ascending: false)]
            
            do {
                let items = try backgroundContext.fetch(fetchRequest)
                let objectIDs = items.map { $0.objectID }
                
                DispatchQueue.main.async {
                    let mainContextItems = objectIDs.compactMap { objectID in
                        try? viewContext.existingObject(with: objectID) as? ClipItem
                    }
                    
                    withAnimation {
                        clipItems = mainContextItems
                        isInitialLoadComplete = true
                    }
                    
                    let timeElapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                    print("✅ 异步加载 \(mainContextItems.count) 条数据，耗时: \(String(format: "%.2f", timeElapsed))ms")
                }
            } catch {
                DispatchQueue.main.async {
                    print("❌ 数据加载失败: \(error.localizedDescription)")
                    clipItems = []
                    isInitialLoadComplete = true
                }
            }
        }
    }
    
    private func loadDataSync() {
        let fetchRequest: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipItem.createdAt, ascending: false)]
        
        do {
            let items = try viewContext.fetch(fetchRequest)
            
            withAnimation {
                clipItems = items
            }
            
            print("✅ 同步加载 \(items.count) 条数据")
        } catch {
            print("❌ 数据加载失败: \(error.localizedDescription)")
            clipItems = []
        }
    }
    
    // MARK: - 子视图
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("加载中...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "clipboard")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("还没有剪贴板历史")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("点击右上角的 + 按钮添加第一个条目")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    private var clipItemsList: some View {
    List {
        ForEach(clipItems) { clipItem in
            // ⭐ 新增：点击整行复制
            Button(action: {
                copyItemToClipboard(clipItem)
            }) {
                ClipItemRowView(
                    clipItem: clipItem,
                    onUpdate: {
                        loadDataSync()
                    },
                    onImageTap: {
                        // ⭐ 新增：点击图片查看大图
                        selectedImageItem = clipItem
                        showingImageViewer = true
                    }
                )
            }
            .buttonStyle(.plain)  // 保持原有样式
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .onDelete(perform: deleteItems)
    }
    .listStyle(.plain)
    .refreshable {
        loadDataAsync()
    }
}
    
    // MARK: - 数据操作方法
    
    private func addNewItem(content: String, source: String) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedContent.isEmpty else { return }
        
        let newItem = ClipItem(
            content: trimmedContent,
            contentType: determineContentType(content: trimmedContent),
            sourceApp: source,
            context: viewContext
        )
        
        do {
            try viewContext.save()
            
            let timeElapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            print("✅ 成功添加新条目，耗时: \(String(format: "%.2f", timeElapsed))ms - \(trimmedContent.prefix(50))...")
            
            WidgetCenter.shared.reloadAllTimelines()
            
            dismissAddSheet()
            loadDataSync()
        } catch {
            let nsError = error as NSError
            print("❌ 保存失败: \(nsError.localizedDescription)")
        }
    }

    private func deleteItems(offsets: IndexSet) {
        offsets.map { clipItems[$0] }.forEach { item in
            print("🗑️ 删除条目: \(item.previewContent)")
            viewContext.delete(item)
        }
        
        do {
            try viewContext.save()
            WidgetCenter.shared.reloadAllTimelines()
            loadDataSync()
        } catch {
            let nsError = error as NSError
            print("❌ 删除操作保存失败: \(nsError.localizedDescription)")
        }
    }

    // MARK: - 复制功能（⭐ 新增）

/// 复制条目到剪贴板（支持图片）
private func copyItemToClipboard(_ item: ClipItem) {
    if item.contentType == "image" {
        // 复制图片
        if let imageData = item.imageData, let image = UIImage(data: imageData) {
            UIPasteboard.general.image = image
            print("✅ 已复制图片到剪贴板（尺寸：\(item.imageWidth)×\(item.imageHeight)）")
            
            // 触觉反馈
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            // 显示提示
            showToast(message: "✅ 图片已复制")
        } else {
            print("❌ 图片数据无效")
            showToast(message: "❌ 图片加载失败")
        }
    } else {
        // 复制文本/链接
        if let content = item.content {
            UIPasteboard.general.string = content
            print("✅ 已复制到剪贴板: \(content.prefix(50))...")
            
            // 触觉反馈
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            // 显示提示
            showToast(message: "✅ 已复制")
        }
    }
    
    // 增加使用次数
    item.usageCount += 1
    item.lastUsedAt = Date()
    
    do {
        try viewContext.save()
    } catch {
        print("❌ 保存使用记录失败: \(error)")
    }
}

/// 显示 Toast 提示
private func showToast(message: String) {
    // 简单实现：使用 Alert（你可以后续优化为自定义 Toast）
    DispatchQueue.main.async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else {
            return
        }
        
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        rootVC.present(alert, animated: true)
        
        // 1秒后自动消失
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            alert.dismiss(animated: true)
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

// MARK: - 弹窗预热管理器

class SheetPrewarmer {
    static let shared = SheetPrewarmer()
    
    private var prewarmedController: UIHostingController<AddItemSheetView>?
    private var isPrewarmed = false
    
    private init() {}
    
    func prewarmAddItemSheet() {
        guard !isPrewarmed else {
            print("📋 弹窗已预热，跳过")
            return
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        print("📋 开始预热弹窗视图...")
        
        DispatchQueue.main.async { [weak self] in
            let dummyContent = Binding<String>(get: { "" }, set: { _ in })
            let dummySource = Binding<String>(get: { "手动添加" }, set: { _ in })
            
            let sheetView = AddItemSheetView(
                content: dummyContent,
                source: dummySource,
                onSave: { _, _ in },
                onCancel: { }
            )
            
            let controller = UIHostingController(rootView: sheetView)
            
            controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            controller.view.layoutIfNeeded()
            
            self?.prewarmedController = controller
            self?.isPrewarmed = true
            
            let timeElapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            print("✅ 弹窗视图预热完成，耗时: \(String(format: "%.2f", timeElapsed))ms")
        }
    }
    
    func cleanup() {
        prewarmedController = nil
        isPrewarmed = false
        print("🧹 弹窗预热资源已清理")
    }
}

// MARK: - 键盘预热管理器

class KeyboardPrewarmer {
    static let shared = KeyboardPrewarmer()
    
    private var isPrewarming = false
    private var isPrewarmed = false
    private var hiddenTextField: UITextField?
    
    private init() {}
    
    func prewarmInBackground() {
        guard !isPrewarming && !isPrewarmed else {
            print("⌨️ 键盘已预热或正在预热，跳过")
            return
        }
        
        isPrewarming = true
        let startTime = CFAbsoluteTimeGetCurrent()
        
        print("⌨️ 开始后台预热键盘...")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let textField = UITextField()
            textField.isHidden = true
            textField.frame = CGRect(x: -100, y: -100, width: 1, height: 1)
            textField.alpha = 0
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.addSubview(textField)
                self.hiddenTextField = textField
                
                textField.becomeFirstResponder()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    textField.resignFirstResponder()
                    
                    let timeElapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                    print("✅ 键盘预热完成，耗时: \(String(format: "%.2f", timeElapsed))ms")
                    
                    self.isPrewarming = false
                    self.isPrewarmed = true
                }
            } else {
                self.isPrewarming = false
            }
        }
    }
    
    func cleanup() {
        hiddenTextField?.removeFromSuperview()
        hiddenTextField = nil
        isPrewarmed = false
        isPrewarming = false
        print("🧹 键盘预热资源已清理")
    }
}

// MARK: - 剪贴板条目行视图（⭐ 更新支持图片）

struct ClipItemRowView: View {
    @ObservedObject var clipItem: ClipItem
    @Environment(\.managedObjectContext) private var viewContext
    
    let onUpdate: () -> Void
    let onImageTap: () -> Void  // ⭐ 新增：图片点击回调
    
    var body: some View {
        HStack(spacing: 12) {
            // ⭐ 左侧：图片缩略图或类型图标
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
                // 显示类型图标
                VStack {
                    Text(clipItem.typeIcon)
                        .font(.title2)
                    Spacer()
                }
            }
            
            // 主要内容区域
            VStack(alignment: .leading, spacing: 4) {
                // ⭐ 内容预览（图片显示详细信息）
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
                
                // 底部信息行
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
            
            Spacer()
            
            // 右侧收藏按钮
            Button(action: {
                toggleStarred()
            }) {
                Image(systemName: clipItem.isStarred ? "star.fill" : "star")
                    .foregroundColor(clipItem.isStarred ? .yellow : .gray)
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
    
    private func toggleStarred() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        clipItem.isStarred.toggle()
        
        do {
            try viewContext.save()
            print(clipItem.isStarred ? "⭐ 已收藏" : "☆ 取消收藏")
        } catch {
            print("❌ 收藏状态保存失败: \(error.localizedDescription)")
            clipItem.isStarred.toggle()
        }
    }
    
    /// 直接通过根VC打开 UIKit 图片查看器（iOS15–18 均稳定）
    private func presentImageViewer(for item: ClipItem) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            print("❌ 无法找到根视图控制器")
            return
        }

        let viewerVC = ImageViewerViewController(clipItem: item)
        rootVC.present(viewerVC, animated: true)
        print("🖼️ 已打开图片查看器（UIKit 弹出）")
    }
}

// MARK: - 预览

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let dataRefreshManager = DataRefreshManager()
        
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(dataRefreshManager)
    }
}
