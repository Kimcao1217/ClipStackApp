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
        .navigationTitle(L10n.detailTitle)  // ✅ 本地化
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
        .alert(L10n.alertDeleteTitle, isPresented: $showingDeleteAlert) {  // ✅ 本地化
            Button(L10n.cancel, role: .cancel) {}
            Button(L10n.delete, role: .destructive) {
                deleteItem()
            }
        } message: {
            Text(L10n.alertDeleteMessage)  // ✅ 本地化
        }
    }
    
    // MARK: - 子视图
    
    /// 类型标签
    private var typeTagView: some View {
        HStack {
            Text(clipItem.typeIcon)
                .font(.title2)
            
            Text(clipItem.contentType == "text" ? L10n.filterText :
                 clipItem.contentType == "link" ? L10n.filterLink : L10n.filterImage)  // ✅ 本地化
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
                // 图片预览（点击进入全屏）
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
                
                // ⭐ 新增：压缩信息（原图 → 压缩后）
                if clipItem.originalSize > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.green)
                        Text(clipItem.compressionDescription)  // ✅ 已在 ClipItem+Extensions.swift 中本地化
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 图片格式和尺寸信息
                Text(clipItem.imageFullDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        } else {
            // 文本/链接内容（保持不变）
            VStack(alignment: .leading, spacing: 8) {
                Text(clipItem.content ?? "")
                    .font(.body)
                    .textSelection(.enabled)
                
                if clipItem.isLink, let urlString = clipItem.content, let url = URL(string: urlString) {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "safari")
                            Text(L10n.detailOpenInSafari)  // ✅ 本地化
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
            MetadataRow(
                icon: "app.fill",
                label: L10n.detailSource,  // ✅ 本地化
                value: clipItem.displaySourceApp
            )
            
            MetadataRow(
                icon: "calendar",
                label: L10n.detailCreatedAt,  // ✅ 本地化
                value: formatFullDate(clipItem.createdAt)
            )
        }
    }
    
    /// 操作按钮
    /// 操作按钮（iOS 原生风格：无边框 + 蓝色/红色文字）
private var actionButtonsView: some View {
    HStack(spacing: 0) {
        // 1️⃣ 复制按钮
        Button(action: {
            copyToClipboard()
        }) {
            VStack(spacing: 4) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 22))
                Text(L10n.detailCopyContent)
                    .font(.system(size: 13))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
        }
        .foregroundColor(.blue)
        
        // 2️⃣ 收藏按钮
Button(action: {
    toggleStarred()
}) {
    VStack(spacing: 4) {
        Image(systemName: clipItem.isStarred ? "star.fill" : "star")
            .font(.system(size: 22))
        Text(clipItem.isStarred ? L10n.detailUnstar : L10n.detailStar)  
            .font(.system(size: 13))
    }
    .frame(maxWidth: .infinity)
    .frame(height: 60)
}
        .foregroundColor(clipItem.isStarred ? .yellow : .blue)
        .id(clipItem.isStarred)  // ⭐ 关键：强制刷新
        
        // 3️⃣ 删除按钮
        Button(action: {
            showingDeleteAlert = true
        }) {
            VStack(spacing: 4) {
                Image(systemName: "trash")
                    .font(.system(size: 22))
                Text(L10n.delete)
                    .font(.system(size: 13))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
        }
        .foregroundColor(.red)
    }
    .background(Color(UIColor.systemBackground))
    // .overlay(
    //     Rectangle()
    //         .frame(height: 0.5)
    //         .foregroundColor(Color(UIColor.separator)),
    //     alignment: .top
    // )
}
    
    // MARK: - 辅助方法
    
    private func formatFullDate(_ date: Date?) -> String {
        guard let date = date else { return L10n.timeUnknown }  // ✅ 本地化
        
        let formatter = DateFormatter()
        formatter.locale = Locale.current  // ✅ 自动适配当前语言
        formatter.setLocalizedDateFormatFromTemplate("yyyyMMMMdHHmm")  // ✅ 本地化日期格式
        return formatter.string(from: date)
    }
    
    private func copyToClipboard() {
        if clipItem.hasImage {
            if let image = clipItem.thumbnailImage {
                UIPasteboard.general.image = image
                showToast(message: L10n.toastImageCopied)  // ✅ 本地化
            }
        } else {
            if let content = clipItem.content {
                UIPasteboard.general.string = content
                showToast(message: L10n.toastCopied)  // ✅ 本地化
            }
        }
        
        print("✅ \(L10n.logContentCopied)")  // ✅ 本地化
    }
    
    private func toggleStarred() {
        // ✅ 收藏前检查限制
        if !clipItem.isStarred {
            let (currentCount, canStar) = PersistenceController.checkStarredLimit(context: viewContext)
            if !canStar {
                showToast(message: String(format: L10n.toastStarredFull, currentCount, ProManager.freeStarredLimit))  // ✅ 本地化
                return
            }
        }
        
        // ✅ 添加触觉反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // ✅ 直接修改对象（SwiftUI 自动更新 UI）
        clipItem.isStarred.toggle()
        
        do {
            try viewContext.save()
            
            // ✅ 显示 Toast
            let message = clipItem.isStarred ? L10n.toastStarred : L10n.toastUnstarred  // ✅ 本地化
            showToast(message: message)
            print(message)
            
            // ✅ 取消收藏后检查历史记录限制
            if !clipItem.isStarred {
                PersistenceController.enforceHistoryLimit(context: viewContext)
            }
        } catch {
            print("❌ \(L10n.errorSaveFailed): \(error)")  // ✅ 本地化
            clipItem.isStarred.toggle()  // 回滚
            
            // ❌ 错误震动
            let errorGenerator = UINotificationFeedbackGenerator()
            errorGenerator.notificationOccurred(.error)
        }
    }
    
    private func deleteItem() {
        viewContext.delete(clipItem)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("❌ \(L10n.errorDeleteFailed): \(error)")  // ✅ 本地化
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
