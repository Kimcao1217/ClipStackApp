//
//  ShareViewController.swift
//  ClipStackShare
//
//  Share Extension主控制器
//  处理从其他App分享来的内容并保存到Core Data

import UIKit
import CoreData
import UniformTypeIdentifiers
import WidgetKit

class ShareViewController: UIViewController {
    
    // Core Data持久化控制器
    private let persistenceController = PersistenceController.shared
    
    // 用于显示状态的UI组件
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    // MARK: - 生命周期方法
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("🚀 Share Extension viewDidLoad 开始")
        
        // 设置UI
        setupUI()
        
        // 开始处理分享内容
        handleSharedContent()
    }
    
    // MARK: - UI设置
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // 添加状态标签
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
        
        // 添加加载指示器
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -20)
        ])
        
        // 初始状态
        statusLabel.text = "正在保存..."
        activityIndicator.startAnimating()
    }
    
    // MARK: - 处理分享内容
    
    private func handleSharedContent() {
        // 获取扩展上下文和输入项
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            showError("无法获取分享内容")
            return
        }
        
        print("📦 收到分享请求，开始处理...")
        
        // 尝试按优先级处理不同类型的内容
        handleItemProvider(itemProvider)
    }
    
    /// 处理ItemProvider，按优先级尝试不同类型
    private func handleItemProvider(_ itemProvider: NSItemProvider) {
        // 优先级1：URL（网页链接）
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            handleURLContent(itemProvider)
        }
        // 优先级2：纯文本
        else if itemProvider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
            handleTextContent(itemProvider)
        }
        // 优先级3：图片
        else if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            handleImageContent(itemProvider)
        }
        // 不支持的类型
        else {
            showError("不支持的内容类型")
        }
    }
    
    // MARK: - 处理文本内容
    
    private func handleTextContent(_ itemProvider: NSItemProvider) {
        itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { [weak self] (item, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ 加载文本失败: \(error.localizedDescription)")
                self.showError("读取文本失败")
                return
            }
            
            // 提取文本内容
            var textContent: String?
            
            if let text = item as? String {
                textContent = text
            } else if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
                textContent = text
            }
            
            guard let content = textContent, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                self.showError("文本内容为空")
                return
            }
            
            print("📝 成功提取文本内容: \(content.prefix(50))...")
            
            // 保存到Core Data
            self.saveClipItem(
                content: content,
                contentType: self.determineContentType(content: content),
                sourceApp: self.getSourceAppName()
            )
        }
    }
    
    // MARK: - 处理URL内容
    
    private func handleURLContent(_ itemProvider: NSItemProvider) {
        itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ 加载URL失败: \(error.localizedDescription)")
                self.showError("读取链接失败")
                return
            }
            
            var urlString: String?
            
            if let url = item as? URL {
                urlString = url.absoluteString
            } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                urlString = url.absoluteString
            }
            
            guard let content = urlString, !content.isEmpty else {
                self.showError("链接为空")
                return
            }
            
            print("🔗 成功提取URL: \(content)")
            
            // 保存到Core Data
            self.saveClipItem(
                content: content,
                contentType: "link",
                sourceApp: self.getSourceAppName()
            )
        }
    }
    
    // MARK: - 处理图片内容
    
    private func handleImageContent(_ itemProvider: NSItemProvider) {
        // 图片处理比较复杂，暂时先提示用户
        // 在后续版本中实现图片存储
        DispatchQueue.main.async {
            self.showError("图片分享功能即将推出")
        }
    }
    
    // MARK: - 保存到Core Data
    
    private func saveClipItem(content: String, contentType: String, sourceApp: String) {
        // 在后台上下文中保存数据
        let context = persistenceController.container.newBackgroundContext()
        
        context.perform {
            // ⚠️ 修复：正确创建 ClipItem 对象
            let newItem = ClipItem(context: context)
            newItem.id = UUID()
            newItem.content = content
            newItem.contentType = contentType
            newItem.sourceApp = sourceApp
            newItem.createdAt = Date()
            newItem.isStarred = false
            newItem.usageCount = 0
            
            print("💾 正在保存:")
            print("  - ID: \(newItem.id?.uuidString ?? "nil")")
            print("  - 内容: \(content.prefix(50))...")
            print("  - 类型: \(contentType)")
            print("  - 来源: \(sourceApp)")
            print("  - 创建时间: \(newItem.createdAt?.description ?? "nil")")
            
            // 保存到持久化存储
            do {
                try context.save()
                print("✅ Share Extension 保存成功！")

                WidgetCenter.shared.reloadAllTimelines()
                print("🔄 已触发 Widget 刷新")
                
                // ⚠️ 确保在主线程更新 UI
                DispatchQueue.main.async {
                    self.showSuccess()
                }
            } catch {
                print("❌ Share Extension 保存失败: \(error.localizedDescription)")
                print("❌ 详细错误: \(error)")
                
                DispatchQueue.main.async {
                    self.showError("保存失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - UI反馈方法
    
    private func showSuccess() {
        print("🎉 显示成功提示")
        
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        
        statusLabel.text = "✅ 已保存到 ClipStack"
        statusLabel.textColor = .systemGreen
        
        // 添加触觉反馈
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // ⚠️ 延长显示时间到 1.5 秒，让用户看到提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            print("🚪 关闭 Share Extension")
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
    
    private func showError(_ message: String) {
        print("❌ 显示错误提示: \(message)")
        
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
            self.activityIndicator.isHidden = true
            
            self.statusLabel.text = "❌ \(message)"
            self.statusLabel.textColor = .systemRed
            
            // 添加触觉反馈
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            
            // 2秒后关闭
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                print("🚪 关闭 Share Extension（错误）")
                self?.extensionContext?.cancelRequest(withError: NSError(domain: "ClipStack", code: -1))
            }
        }
    }
    
    // MARK: - 工具方法
    
    /// 判断内容类型
    private func determineContentType(content: String) -> String {
        // 简单的链接检测
        if content.lowercased().hasPrefix("http://") || content.lowercased().hasPrefix("https://") {
            return "link"
        }
        
        return "text"
    }
    
    /// 获取来源应用名称
    private func getSourceAppName() -> String {
        // 尝试从扩展上下文获取来源应用名称
        if let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem {
            // 检查是否有来源应用信息
            if let sourceApplication = extensionItem.userInfo?["NSExtensionItemSourceApplicationKey"] as? String {
                return sourceApplication
            }
        }
        
        // 默认返回"分享"
        return "分享"
    }
}
