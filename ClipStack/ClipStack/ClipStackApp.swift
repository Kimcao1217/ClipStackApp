//
//  ClipStackApp.swift
//  ClipStack
//
//  Created by Kim Cao on 13/10/2025.
//

import SwiftUI
import CoreData
import WidgetKit

@main
struct ClipStackApp: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onOpenURL { url in
                    handleURLScheme(url)
                }
        }
    }
    
    // MARK: - 处理 Widget 点击跳转
    
    /// 处理 clipstack://copy/{itemID}
    private func handleURLScheme(_ url: URL) {
        print("🔗 收到 URL Scheme: \(url)")
        print("   - scheme: \(url.scheme ?? "nil")")
        print("   - host: \(url.host ?? "nil")")
        print("   - path: \(url.path)")
        
        guard url.scheme == "clipstack" else {
            print("❌ 无效的 URL Scheme")
            return
        }
        
        guard url.host == "copy" else {
            print("❌ 无效的 host（期望 'copy'，实际 '\(url.host ?? "nil")'）")
            return
        }
        
        let itemIDString = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        guard !itemIDString.isEmpty else {
            print("❌ UUID 为空")
            return
        }
        
        guard let itemID = UUID(uuidString: itemIDString) else {
            print("❌ 无效的 UUID: \(itemIDString)")
            return
        }
        
        print("🎯 正在复制条目: \(itemID)")
        copyItemFromWidget(itemID: itemID)
    }
    
    /// 从 Widget 点击后复制条目（✅ 性能优化版本）
    private func copyItemFromWidget(itemID: UUID) {
        // ✅ 使用后台 context（完全在后台线程执行）
        let backgroundContext = persistenceController.container.newBackgroundContext()
        
        backgroundContext.perform {
            let fetchRequest = NSFetchRequest<ClipItem>(entityName: "ClipItem")
            fetchRequest.predicate = NSPredicate(format: "id == %@", itemID as CVarArg)
            fetchRequest.fetchLimit = 1
            
            do {
                let results = try backgroundContext.fetch(fetchRequest)
                
                guard let clipItem = results.first else {
                    print("❌ 未找到 ID 为 \(itemID) 的条目")
                    DispatchQueue.main.async {
                        showErrorHUD(message: "❌ 条目不存在")
                    }
                    return
                }
                
                // ✅ 提前在后台线程读取数据（避免跨线程访问）
                let hasImage = clipItem.hasImage
                let content = clipItem.content
                let imageData = clipItem.imageData
                
                // ✅ 切回主线程执行复制和显示 HUD
                DispatchQueue.main.async {
                    if hasImage {
                        // 复制图片
                        if let imageData = imageData, let image = UIImage(data: imageData) {
                            UIPasteboard.general.image = image
                            showSuccessHUD(message: "✅ 图片已复制")
                            print("✅ 图片已复制到剪贴板")
                        } else {
                            showErrorHUD(message: "❌ 图片加载失败")
                            print("❌ 图片数据损坏")
                        }
                    } else {
                        // 复制文本/链接
                        if let content = content, !content.isEmpty {
                            UIPasteboard.general.string = content
                            showSuccessHUD(message: "✅ 已复制")
                            print("✅ 文本已复制到剪贴板: \(content.prefix(50))")
                        } else {
                            showErrorHUD(message: "❌ 内容为空")
                            print("❌ 条目内容为空")
                        }
                    }
                    
                    // ✅ 触发震动反馈
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } catch {
                print("❌ 查询失败: \(error)")
                DispatchQueue.main.async {
                    showErrorHUD(message: "❌ 加载失败")
                }
            }
        }
    }
}

// MARK: - 全局 HUD 显示函数（✅ 修复居中问题）

/// 显示成功提示（绿色勾）
func showSuccessHUD(message: String) {
    showHUD(message: message, backgroundColor: UIColor.systemGreen)
}

/// 显示错误提示（红色叉）
func showErrorHUD(message: String) {
    showHUD(message: message, backgroundColor: UIColor.systemRed)
}

/// 通用 HUD 显示函数（✅ 使用 Auto Layout 精确居中）
private func showHUD(message: String, backgroundColor: UIColor) {
    DispatchQueue.main.async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            print("❌ 无法获取 Key Window")
            return
        }
        
        // ✅ 检查是否已有 HUD（避免重复显示）
        window.subviews.forEach { view in
            if view.tag == 999_888 {
                view.removeFromSuperview()
            }
        }
        
        // ✅ 创建 HUD 容器
        let hud = UIView()
        hud.tag = 999_888
        hud.backgroundColor = backgroundColor
        hud.layer.cornerRadius = 20
        hud.layer.shadowColor = UIColor.black.cgColor
        hud.layer.shadowOpacity = 0.2
        hud.layer.shadowOffset = CGSize(width: 0, height: 4)
        hud.layer.shadowRadius = 10
        hud.translatesAutoresizingMaskIntoConstraints = false
        hud.alpha = 0
        
        // ✅ 创建文字标签
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        hud.addSubview(label)
        window.addSubview(hud)
        
        // ✅ 使用 Auto Layout 约束精确居中
        NSLayoutConstraint.activate([
            hud.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            hud.centerYAnchor.constraint(equalTo: window.centerYAnchor),
            hud.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            hud.heightAnchor.constraint(equalToConstant: 60),
            
            label.leadingAnchor.constraint(equalTo: hud.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: hud.trailingAnchor, constant: -24),
            label.centerYAnchor.constraint(equalTo: hud.centerYAnchor)
        ])
        
        window.layoutIfNeeded()
        
        // ✅ 优雅的淡入动画
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: {
            hud.alpha = 1
            hud.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        }) { _ in
            UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseIn, animations: {
                hud.transform = .identity
            })
        }
        
        // ✅ 1.5 秒后自动消失
        UIView.animate(withDuration: 0.25, delay: 1.5, options: .curveEaseIn, animations: {
            hud.alpha = 0
            hud.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            hud.removeFromSuperview()
        }
    }
}
