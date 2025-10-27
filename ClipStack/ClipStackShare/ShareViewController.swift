//
//  ShareViewController.swift
//  ClipStackShare
//
//  Share Extension主控制器
//  处理从其他App分享来的内容（文本/链接/图片）并保存到Core Data

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
        
        setupUI()
        handleSharedContent()
    }
    
    // MARK: - UI设置
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
        
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -20)
        ])
        
        statusLabel.text = "正在保存..."
        activityIndicator.startAnimating()
    }
    
    // MARK: - 处理分享内容
    
    private func handleSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            showError("无法获取分享内容")
            return
        }
        
        print("📦 收到分享请求，开始处理...")
        handleItemProvider(itemProvider)
    }
    
    /// 处理ItemProvider，按优先级尝试不同类型
    private func handleItemProvider(_ itemProvider: NSItemProvider) {
        // 优先级1：图片
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            handleImageContent(itemProvider)
        }
        // 优先级2：URL（网页链接）
        else if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            handleURLContent(itemProvider)
        }
        // 优先级3：纯文本
        else if itemProvider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
            handleTextContent(itemProvider)
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
            
            self.saveClipItem(
                content: content,
                contentType: self.determineContentType(content: content),
                sourceApp: self.getSourceAppName(),
                imageData: nil,
                imageWidth: 0,
                imageHeight: 0,
                imageFormat: nil,
                originalSize: 0,
                thumbnailSize: 0
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
            
            self.saveClipItem(
                content: content,
                contentType: "link",
                sourceApp: self.getSourceAppName(),
                imageData: nil,
                imageWidth: 0,
                imageHeight: 0,
                imageFormat: nil,
                originalSize: 0,
                thumbnailSize: 0
            )
        }
    }
    
    // MARK: - 处理图片内容（⭐ 新增）
    
    private func handleImageContent(_ itemProvider: NSItemProvider) {
        print("🖼️ 开始处理图片...")
        
        itemProvider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (item, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ 加载图片失败: \(error.localizedDescription)")
                self.showError("读取图片失败")
                return
            }
            
            // 从不同来源提取 UIImage
            var image: UIImage?
            var originalSize: Int64 = 0
            var imageFormat: String = "JPEG"
            
            if let img = item as? UIImage {
                // 直接是 UIImage
                image = img
                print("✅ 直接获取到 UIImage")
            } else if let data = item as? Data {
                // 是 Data，转为 UIImage
                image = UIImage(data: data)
                originalSize = Int64(data.count)
                
                // 检测图片格式
                if data.count > 0 {
                    let byte = data[0]
                    if byte == 0xFF {
                        imageFormat = "JPEG"
                    } else if byte == 0x89 {
                        imageFormat = "PNG"
                    } else if byte == 0x00 {
                        imageFormat = "HEIC"
                    }
                }
                
                print("✅ 从 Data 转换为 UIImage（\(data.count) 字节）")
            } else if let url = item as? URL {
                // 是文件 URL
                if let data = try? Data(contentsOf: url) {
                    image = UIImage(data: data)
                    originalSize = Int64(data.count)
                    imageFormat = url.pathExtension.uppercased()
                    print("✅ 从文件 URL 加载图片（\(data.count) 字节）")
                }
            }
            
            guard let originalImage = image else {
                self.showError("无法读取图片")
                return
            }
            
            print("📐 原图尺寸: \(originalImage.size.width) × \(originalImage.size.height)")
            
            // 压缩图片
            guard let compressedData = self.compressImage(originalImage, targetWidth: 400) else {
                self.showError("图片压缩失败")
                return
            }
            
            print("✅ 图片压缩完成: \(originalSize) 字节 → \(compressedData.count) 字节")
            
            // 保存到 Core Data
            self.saveClipItem(
                content: "图片", // 占位文本
                contentType: "image",
                sourceApp: self.getSourceAppName(),
                imageData: compressedData,
                imageWidth: Int32(originalImage.size.width),
                imageHeight: Int32(originalImage.size.height),
                imageFormat: imageFormat,
                originalSize: originalSize,
                thumbnailSize: Int64(compressedData.count)
            )
        }
    }
    
    /// 压缩图片到指定宽度（保持宽高比）
    private func compressImage(_ image: UIImage, targetWidth: CGFloat = 400) -> Data? {
        let originalSize = image.size
        
        // 如果原图已经很小，不需要压缩
        if originalSize.width <= targetWidth {
            return image.jpegData(compressionQuality: 0.7)
        }
        
        // 计算压缩比例
        let scale = targetWidth / originalSize.width
        let newHeight = originalSize.height * scale
        let newSize = CGSize(width: targetWidth, height: newHeight)
        
        // 使用 UIGraphicsImageRenderer 高质量缩放
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        // 转为 JPEG（质量 70%）
        return resizedImage.jpegData(compressionQuality: 0.7)
    }
    
    // MARK: - 保存到Core Data（⭐ 更新参数）
    
    private func saveClipItem(
        content: String,
        contentType: String,
        sourceApp: String,
        imageData: Data?,
        imageWidth: Int32,
        imageHeight: Int32,
        imageFormat: String?,
        originalSize: Int64,
        thumbnailSize: Int64
    ) {
        let context = persistenceController.container.newBackgroundContext()
        
        context.perform {
            // ⭐ 免费版限制检查：在保存前清理旧数据
            //PersistenceController.enforceHistoryLimit(context: context)
            
            let newItem = ClipItem(context: context)
            newItem.id = UUID()
            newItem.content = content
            newItem.contentType = contentType
            newItem.sourceApp = sourceApp
            newItem.createdAt = Date()
            newItem.isStarred = false
            newItem.usageCount = 0
            
            // ⭐ 保存图片数据
            if let imageData = imageData {
                newItem.imageData = imageData
                newItem.imageWidth = imageWidth
                newItem.imageHeight = imageHeight
                newItem.imageFormat = imageFormat
                newItem.originalSize = originalSize
                newItem.thumbnailSize = thumbnailSize
            }
            
            print("💾 正在保存:")
            print("  - 类型: \(contentType)")
            print("  - 来源: \(sourceApp)")
            if contentType == "image" {
                print("  - 原图: \(imageWidth) × \(imageHeight)")
                print("  - 缩略图: \(thumbnailSize) 字节")
            }
            
            do {
                try context.save()
                print("✅ Share Extension 保存成功！")

                DarwinNotificationCenter.shared.postNotification()
                
                WidgetCenter.shared.reloadAllTimelines()
                print("🔄 已触发 Widget 刷新")
                
                DispatchQueue.main.async {
                    self.showSuccess()
                }
            } catch {
                print("❌ Share Extension 保存失败: \(error.localizedDescription)")
                
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
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
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
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                print("🚪 关闭 Share Extension（错误）")
                self?.extensionContext?.cancelRequest(withError: NSError(domain: "ClipStack", code: -1))
            }
        }
    }
    
    // MARK: - 工具方法
    
    private func determineContentType(content: String) -> String {
        if content.lowercased().hasPrefix("http://") || content.lowercased().hasPrefix("https://") {
            return "link"
        }
        return "text"
    }
    
    private func getSourceAppName() -> String {
        if let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
           let sourceApplication = extensionItem.userInfo?["NSExtensionItemSourceApplicationKey"] as? String {
            return sourceApplication
        }
        return "分享"
    }
}
