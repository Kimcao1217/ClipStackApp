//
//  ContentView.swift
//  ClipStack
//
//  主界面视图 - 显示剪贴板历史记录列表
//

import SwiftUI
import CoreData
import WidgetKit
import UIKit

struct ContentView: View {
    // 获取Core Data管理上下文，用于数据操作
    @Environment(\.managedObjectContext) private var viewContext
    
    // ⚠️ 接收刷新管理器
    @EnvironmentObject private var dataRefreshManager: DataRefreshManager
    
    // ⚠️ 改用 @State 存储数据，而不是 @FetchRequest
    @State private var clipItems: [ClipItem] = []
    
    // 控制是否显示添加新条目的弹窗
    @State private var showingAddSheet = false
    // 新条目的内容文本
    @State private var newItemContent = ""
    // 新条目的来源应用
    @State private var newItemSource = "手动添加"
    
    // ⚠️ 新增：加载状态标记
    @State private var isInitialLoadComplete = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 主要内容区域
                if clipItems.isEmpty && !isInitialLoadComplete {
                    // 首次加载中的占位视图
                    loadingView
                } else if clipItems.isEmpty {
                    // 空状态显示
                    emptyStateView
                } else {
                    // 剪贴板条目列表
                    clipItemsList
                }
            }
            .navigationTitle("📋 ClipStack")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // 顶部工具栏 - iOS 15兼容版本
                ToolbarItem(placement: .navigationBarTrailing) {
                    // 添加按钮
                    Button {
                        let startTime = CFAbsoluteTimeGetCurrent()
                        
                        // ⚠️ 直接显示弹窗
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
                // ⚠️ 使用独立的视图
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
            // ⚠️ 优化：后台预热 + 异步加载数据
            prewarmCoreDataInBackground()
            loadDataAsync()
            
            // ⚠️ 启动后 0.3 秒开始预热（更早开始）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // 预热键盘
                KeyboardPrewarmer.shared.prewarmInBackground()
                
                // ⚠️ 预热弹窗视图（真实渲染）
                SheetPrewarmer.shared.prewarmAddItemSheet()
            }
        }
        .onChange(of: dataRefreshManager.lastRefreshDate) { _ in
            // 监听远程变更，重新加载数据
            print("🎨 检测到远程变更，重新加载数据...")
            loadDataAsync()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            print("🔄 App返回前台，重新加载数据...")
            loadDataAsync()
        }
    }
    
    // MARK: - 性能优化：Core Data 预热和异步加载
    
    /// 在后台线程预热 Core Data（不阻塞主线程）
    private func prewarmCoreDataInBackground() {
        DispatchQueue.global(qos: .userInitiated).async {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // 创建后台上下文
            let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
            
            // 执行一次简单查询（预热索引和缓存）
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
    
    /// 异步加载数据（不阻塞主线程）
    private func loadDataAsync() {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 在后台线程执行查询
        DispatchQueue.global(qos: .userInitiated).async {
            // 创建后台上下文
            let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
            
            let fetchRequest: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipItem.createdAt, ascending: false)]
            
            do {
                // 后台查询
                let items = try backgroundContext.fetch(fetchRequest)
                
                // 将对象转换到主上下文（避免跨线程访问）
                let objectIDs = items.map { $0.objectID }
                
                // 回到主线程更新 UI
                DispatchQueue.main.async {
                    let mainContextItems = objectIDs.compactMap { objectID in
                        try? viewContext.existingObject(with: objectID) as? ClipItem
                    }
                    
                    // 使用动画更新UI
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
    
    /// 同步加载数据（用于保存/删除后的立即刷新）
    private func loadDataSync() {
        let fetchRequest: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipItem.createdAt, ascending: false)]
        
        do {
            let items = try viewContext.fetch(fetchRequest)
            
            // 使用动画更新UI
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
    
    /// 加载中视图
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
    
    /// 空状态视图 - 当没有剪贴板条目时显示
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // 图标
            Image(systemName: "clipboard")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            // 提示文字
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
    
    /// 剪贴板条目列表
    private var clipItemsList: some View {
        List {
            ForEach(clipItems) { clipItem in
                ClipItemRowView(clipItem: clipItem, onUpdate: {
                    // 当条目更新时，重新加载数据（同步）
                    loadDataSync()
                })
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .onDelete(perform: deleteItems)
        }
        .listStyle(.plain)
        // 支持下拉刷新
        .refreshable {
            loadDataAsync()
        }
    }
    
    // MARK: - 数据操作方法
    
    /// 添加新的剪贴板条目
    private func addNewItem(content: String, source: String) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 去除前后空格
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 检查内容是否为空
        guard !trimmedContent.isEmpty else { return }
        
        // 创建新的剪贴板条目
        let newItem = ClipItem(
            content: trimmedContent,
            contentType: determineContentType(content: trimmedContent),
            sourceApp: source,
            context: viewContext
        )
        
        // 保存到Core Data
        do {
            try viewContext.save()
            
            let timeElapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            print("✅ 成功添加新条目，耗时: \(String(format: "%.2f", timeElapsed))ms - \(trimmedContent.prefix(50))...")
            
            // 通知 Widget 刷新
            WidgetCenter.shared.reloadAllTimelines()
            
            // 关闭弹窗并重置输入
            dismissAddSheet()
            
            // 同步刷新（因为用户期待立即看到）
            loadDataSync()
        } catch {
            // 错误处理
            let nsError = error as NSError
            print("❌ 保存失败: \(nsError.localizedDescription)")
        }
    }

    /// 删除选中的剪贴板条目
    private func deleteItems(offsets: IndexSet) {
        // 遍历要删除的条目
        offsets.map { clipItems[$0] }.forEach { item in
            print("🗑️ 删除条目: \(item.previewContent)")
            
            // 从 Core Data 删除
            viewContext.delete(item)
        }
        
        // 保存更改
        do {
            try viewContext.save()
            
            // 通知 Widget 刷新
            WidgetCenter.shared.reloadAllTimelines()
            
            // 同步刷新
            loadDataSync()
        } catch {
            let nsError = error as NSError
            print("❌ 删除操作保存失败: \(nsError.localizedDescription)")
        }
    }
    
    /// 关闭添加条目弹窗并重置输入内容
    private func dismissAddSheet() {
        showingAddSheet = false
        newItemContent = ""
        newItemSource = "手动添加"
    }
    
    /// 根据内容判断类型
    /// - Parameter content: 内容文本
    /// - Returns: 内容类型字符串
    private func determineContentType(content: String) -> String {
        // 简单的链接检测
        if content.lowercased().hasPrefix("http://") || content.lowercased().hasPrefix("https://") {
            return "link"
        }
        
        // 默认为文本类型
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
                // 内容输入区域
                VStack(alignment: .leading, spacing: 8) {
                    Text("内容")
                        .font(.headline)
                    
                    TextEditor(text: $content)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                // 来源应用选择
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

// MARK: - 弹窗预热管理器（单例）

class SheetPrewarmer {
    static let shared = SheetPrewarmer()
    
    private var prewarmedController: UIHostingController<AddItemSheetView>?
    private var isPrewarmed = false
    
    private init() {}
    
    /// 预热添加条目弹窗
    func prewarmAddItemSheet() {
        guard !isPrewarmed else {
            print("📋 弹窗已预热，跳过")
            return
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        print("📋 开始预热弹窗视图...")
        
        DispatchQueue.main.async { [weak self] in
            // 创建绑定
            let dummyContent = Binding<String>(get: { "" }, set: { _ in })
            let dummySource = Binding<String>(get: { "手动添加" }, set: { _ in })
            
            // 创建视图
            let sheetView = AddItemSheetView(
                content: dummyContent,
                source: dummySource,
                onSave: { _, _ in },
                onCancel: { }
            )
            
            // ⚠️ 创建 UIHostingController（真实渲染）
            let controller = UIHostingController(rootView: sheetView)
            
            // 设置视图大小（触发布局）
            controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            controller.view.layoutIfNeeded()
            
            // 保留引用
            self?.prewarmedController = controller
            self?.isPrewarmed = true
            
            let timeElapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            print("✅ 弹窗视图预热完成，耗时: \(String(format: "%.2f", timeElapsed))ms")
        }
    }
    
    /// 清理预热资源
    func cleanup() {
        prewarmedController = nil
        isPrewarmed = false
        print("🧹 弹窗预热资源已清理")
    }
}

// MARK: - 键盘预热管理器（单例，全局共享）

/// 键盘预热管理器 - 负责在后台静默预热键盘，完全不阻塞 UI
class KeyboardPrewarmer {
    static let shared = KeyboardPrewarmer()
    
    private var isPrewarming = false
    private var isPrewarmed = false
    private var hiddenTextField: UITextField?
    
    private init() {}
    
    /// 在后台预热键盘（完全异步，不阻塞任何操作）
    func prewarmInBackground() {
        // 避免重复预热
        guard !isPrewarming && !isPrewarmed else {
            print("⌨️ 键盘已预热或正在预热，跳过")
            return
        }
        
        isPrewarming = true
        let startTime = CFAbsoluteTimeGetCurrent()
        
        print("⌨️ 开始后台预热键盘...")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 创建隐藏的输入框
            let textField = UITextField()
            textField.isHidden = true
            textField.frame = CGRect(x: -100, y: -100, width: 1, height: 1)
            textField.alpha = 0
            
            // 添加到窗口
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.addSubview(textField)
                self.hiddenTextField = textField
                
                // 触发键盘加载
                textField.becomeFirstResponder()
                
                // 延迟清理（给键盘足够时间初始化）
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
    
    /// 清理预热资源（在 App 进入后台时调用）
    func cleanup() {
        hiddenTextField?.removeFromSuperview()
        hiddenTextField = nil
        isPrewarmed = false
        isPrewarming = false
        print("🧹 键盘预热资源已清理")
    }
}

// MARK: - 剪贴板条目行视图

/// 单个剪贴板条目的行视图
struct ClipItemRowView: View {
    // 使用@ObservedObject来观察对象变化
    @ObservedObject var clipItem: ClipItem
    @Environment(\.managedObjectContext) private var viewContext
    
    // 回调：当数据更新时通知父视图
    let onUpdate: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 左侧类型图标
            VStack {
                Text(clipItem.typeIcon)
                    .font(.title2)
                Spacer()
            }
            
            // 主要内容区域
            VStack(alignment: .leading, spacing: 4) {
                // 内容预览
                Text(clipItem.previewContent)
                    .font(.body)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                // 底部信息行
                HStack {
                    // 来源应用
                    Label(clipItem.sourceApp ?? "未知", systemImage: "app.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // 时间
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
    
    /// 切换收藏状态
    private func toggleStarred() {
        // 添加触觉反馈
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // 先修改数据，再保存
        clipItem.isStarred.toggle()
        
        // 保存到Core Data
        do {
            try viewContext.save()
            print(clipItem.isStarred ? "⭐ 已收藏" : "☆ 取消收藏")
        } catch {
            print("❌ 收藏状态保存失败: \(error.localizedDescription)")
            // 如果保存失败，回滚状态
            clipItem.isStarred.toggle()
        }
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
