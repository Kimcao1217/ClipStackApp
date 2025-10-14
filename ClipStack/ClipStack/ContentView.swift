//
//  ContentView.swift
//  ClipStack
//
//  Created by Kim Cao on 13/10/2025.
//
//
//  主界面视图 - 显示剪贴板历史记录列表
//

import SwiftUI
import CoreData

struct ContentView: View {
    // 获取Core Data管理上下文，用于数据操作
    @Environment(\.managedObjectContext) private var viewContext
    
    // 从Core Data获取所有剪贴板条目，按创建时间倒序排列
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ClipItem.createdAt, ascending: false)],
        animation: .default
    )
    private var clipItems: FetchedResults<ClipItem>
    
    // 控制是否显示添加新条目的弹窗
    @State private var showingAddSheet = false
    // 新条目的内容文本
    @State private var newItemContent = ""
    // 新条目的来源应用
    @State private var newItemSource = "手动添加"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 主要内容区域
                if clipItems.isEmpty {
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
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                // 添加新条目的弹窗
                addNewItemSheet
            }
        }
    }
    
    // MARK: - 子视图
    
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
                ClipItemRowView(clipItem: clipItem)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .onDelete(perform: deleteItems)
        }
        .listStyle(.plain) // iOS 15兼容的写法
    }
    
    /// 添加新条目的弹窗界面
    private var addNewItemSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 内容输入区域
                VStack(alignment: .leading, spacing: 8) {
                    Text("内容")
                        .font(.headline)
                    
                    TextEditor(text: $newItemContent)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                // 来源应用选择
                VStack(alignment: .leading, spacing: 8) {
                    Text("来源应用")
                        .font(.headline)
                    
                    TextField("输入来源应用名称", text: $newItemSource)
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
                        dismissAddSheet()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        addNewItem()
                    }
                    .disabled(newItemContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    // MARK: - 数据操作方法
    
    /// 添加新的剪贴板条目
    private func addNewItem() {
        // 去除前后空格
        let content = newItemContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 检查内容是否为空
        guard !content.isEmpty else { return }
        
        // 使用动画包装数据变更
        withAnimation {
            // 创建新的剪贴板条目
            let newItem = ClipItem(
                content: content,
                contentType: determineContentType(content: content),
                sourceApp: newItemSource,
                context: viewContext
            )
            
            // 保存到Core Data
            do {
                try viewContext.save()
                print("✅ 成功添加新条目: \(content.prefix(50))...")
                
                // 关闭弹窗并重置输入
                dismissAddSheet()
            } catch {
                // 错误处理
                let nsError = error as NSError
                print("❌ 保存失败: \(nsError.localizedDescription)")
                // 在实际应用中，这里应该显示用户友好的错误信息
            }
        }
    }
    
    /// 删除选中的剪贴板条目
    /// - Parameter offsets: 要删除的条目在列表中的位置
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            // 遍历要删除的条目
            offsets.map { clipItems[$0] }.forEach { item in
                print("🗑️ 删除条目: \(item.previewContent)")
                viewContext.delete(item)
            }
            
            // 保存更改
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("❌ 删除操作保存失败: \(nsError.localizedDescription)")
            }
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

// MARK: - 剪贴板条目行视图

/// 单个剪贴板条目的行视图
struct ClipItemRowView: View {
    // 使用@ObservedObject来观察对象变化
    @ObservedObject var clipItem: ClipItem
    @Environment(\.managedObjectContext) private var viewContext
    
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
        print("🔘 收藏按钮被点击了！当前状态: \(clipItem.isStarred)")
        
        // 添加触觉反馈
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // 先修改数据，再保存，使用正确的动画方式
        clipItem.isStarred.toggle()
        print("📝 状态已切换为: \(clipItem.isStarred)")
        
        // 保存到Core Data（不需要withAnimation包装）
        do {
            try viewContext.save()
            print(clipItem.isStarred ? "⭐ 已收藏并保存" : "☆ 取消收藏并保存")
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
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
