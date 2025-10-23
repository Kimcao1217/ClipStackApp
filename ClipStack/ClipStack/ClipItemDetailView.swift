//
//  ClipItemDetailView.swift
//  ClipStack
//
//  剪贴板条目详情页 - 实时监听版本（iOS 15+ 兼容）

import SwiftUI
import CoreData
import UIKit

struct ClipItemDetailView: View {
    // ⭐ 直接使用 @ObservedObject 监听 Core Data 对象
    @ObservedObject var clipItem: ClipItem
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // 状态变量
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    @State private var showingImageViewer = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 1️⃣ 类型标签
                typeTagView
                
                // 2️⃣ 内容区域
                contentView
                
                Divider()
                
                // 3️⃣ 元信息
                metadataView
                
                Divider()
                
                // 4️⃣ 操作按钮
                actionButtonsView
            }
            .padding()
        }
        .navigationTitle("详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingShareSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: shareItems)
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                deleteItem()
            }
        } message: {
            Text("删除后无法恢复")
        }
    }
    
    // MARK: - 子视图
    
    /// 类型标签
    private var typeTagView: some View {
        HStack {
            Text(clipItem.typeIcon)
                .font(.title2)
            
            Text(clipItem.contentType == "text" ? "文本" :
                 clipItem.contentType == "link" ? "链接" : "图片")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // ⭐ 实时显示收藏状态
            if clipItem.isStarred {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
            }
        }
        .id(clipItem.isStarred)  // ⭐ 关键：强制刷新
    }
    
    /// 内容区域
    @ViewBuilder
    private var contentView: some View {
        if clipItem.hasImage {
            VStack(alignment: .leading, spacing: 12) {
                if let image = clipItem.thumbnailImage {
                    Button(action: {
                        presentImageViewer()
                    }) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                
                Text(clipItem.imageFullDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(clipItem.content ?? "")
                    .font(.body)
                    .textSelection(.enabled)
                
                if clipItem.isLink, let urlString = clipItem.content, let url = URL(string: urlString) {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "safari")
                            Text("在 Safari 中打开")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
    
    /// 元信息
    private var metadataView: some View {
        VStack(alignment: .leading, spacing: 12) {
            MetadataRow(icon: "app.fill", label: "来源", value: clipItem.sourceApp ?? "未知")
            
            MetadataRow(icon: "calendar", label: "创建时间", value: formatFullDate(clipItem.createdAt))
            
            // ⭐ 实时显示使用次数
            MetadataRow(icon: "hand.tap", label: "使用次数", value: "\(clipItem.usageCount) 次")
                .id(clipItem.usageCount)  // ⭐ 关键：强制刷新
            
            if let lastUsed = clipItem.lastUsedAt {
                MetadataRow(icon: "clock", label: "最后使用", value: formatFullDate(lastUsed))
                    .id(lastUsed)  // ⭐ 关键：强制刷新
            }
        }
    }
    
    /// 操作按钮
    private var actionButtonsView: some View {
        HStack(spacing: 16) {
            Button(action: {
                copyToClipboard()
            }) {
                Label("复制内容", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.blue)
            
            // ⭐ 实时显示收藏按钮状态
            Button(action: {
                toggleStarred()
            }) {
                Label(
                    clipItem.isStarred ? "取消收藏" : "收藏",
                    systemImage: clipItem.isStarred ? "star.slash" : "star.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.yellow)
            .id(clipItem.isStarred)  // ⭐ 关键：强制刷新按钮
            
            Button(action: {
                showingDeleteAlert = true
            }) {
                Label("删除", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }
    
    // MARK: - 辅助方法
    
    private func formatFullDate(_ date: Date?) -> String {
        guard let date = date else { return "未知" }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: date)
    }
    
    private func copyToClipboard() {
        if clipItem.hasImage {
            if let image = clipItem.thumbnailImage {
                UIPasteboard.general.image = image
                showToast(message: "✅ 图片已复制")
            }
        } else {
            if let content = clipItem.content {
                UIPasteboard.general.string = content
                showToast(message: "✅ 已复制")
            }
        }
        
        // ⚠️ 在主线程同步修改数据
        clipItem.usageCount += 1
        clipItem.lastUsedAt = Date()
        
        // ⚠️ 使用 perform 确保线程安全
        viewContext.perform {
            do {
                try viewContext.save()
                print("✅ 复制记录已保存（使用次数：\(clipItem.usageCount)）")
            } catch {
                print("❌ 复制记录保存失败: \(error)")
            }
        }
    }
    
    private func toggleStarred() {
        // ⚠️ 立即切换状态（不等待保存完成）
        let newState = !clipItem.isStarred
        clipItem.isStarred = newState
        
        // ⚠️ 使用 perform 确保线程安全
        viewContext.perform {
            do {
                try viewContext.save()
                
                // 触觉反馈
                DispatchQueue.main.async {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
                
                print(newState ? "⭐ 已收藏" : "☆ 取消收藏")
            } catch {
                print("❌ 收藏失败: \(error)")
                
                // 保存失败时恢复原状态
                DispatchQueue.main.async {
                    clipItem.isStarred = !newState
                }
            }
        }
    }
    
    private func deleteItem() {
        viewContext.delete(clipItem)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("❌ 删除失败: \(error)")
        }
    }
    
    private func presentImageViewer() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }
        
        let viewerVC = ImageViewerViewController(clipItem: clipItem)
        rootVC.present(viewerVC, animated: true)
    }
    
    private func showToast(message: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }
        
        let hud = UIView()
        hud.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        hud.layer.cornerRadius = 12
        hud.translatesAutoresizingMaskIntoConstraints = false
        hud.alpha = 0
        
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        hud.addSubview(label)
        window.addSubview(hud)
        
        NSLayoutConstraint.activate([
            hud.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            hud.centerYAnchor.constraint(equalTo: window.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: hud.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: hud.trailingAnchor, constant: -20),
            label.topAnchor.constraint(equalTo: hud.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: hud.bottomAnchor, constant: -12)
        ])
        
        UIView.animate(withDuration: 0.3, animations: {
            hud.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 1.5, animations: {
                hud.alpha = 0
            }) { _ in
                hud.removeFromSuperview()
            }
        }
    }
    
    private var shareItems: [Any] {
        if clipItem.hasImage, let image = clipItem.thumbnailImage {
            return [image]
        } else if let content = clipItem.content {
            return [content]
        } else {
            return []
        }
    }
}

// MARK: - 辅助视图

struct MetadataRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // 不需要更新
    }
}
