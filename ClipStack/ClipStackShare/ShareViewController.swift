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
        print("🚀 Share Extension viewDidLoad started")
        
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
        
        statusLabel.text = L10n.shareSaving
        activityIndicator.startAnimating()
    }
    
    // MARK: - 处理分享内容
    
    private func handleSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            showError(L10n.shareErrorNoContent)
            return
        }
        
        print("📦 Received share request, processing...")
        handleItemProvider(itemProvider)
    }
    
    /// 处理ItemProvider，按优先级尝试不同类型
    private func handleItemProvider(_ itemProvider: NSItemProvider) {
        // 打印所有支持的类型标识符
        print("📦 ItemProvider supported types:")
        for identifier in itemProvider.registeredTypeIdentifiers {
            print("   - \(identifier)")
        }

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
            showError(L10n.shareErrorUnsupportedType)
        }
    }
    
    // MARK: - 处理文本内容
    
    private func handleTextContent(_ itemProvider: NSItemProvider) {
        itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { [weak self] (item, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Failed to load text: \(error.localizedDescription)")
                self.showError(L10n.shareErrorReadTextFailed)
                return
            }
            
            var textContent: String?
            
            if let text = item as? String {
                textContent = text
            } else if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
                textContent = text
            }
            
            guard let content = textContent, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                self.showError(L10n.shareErrorEmptyText)
                return
            }
            
            print("📝 Successfully extracted text: \(content.prefix(50))...")
            
            self.saveClipItem(
                content: content,
                contentType: self.determineContentType(content: content),
                sourceApp: self.getSourceAppName(),
                imageData: nil,
                imageWidth: 0,
                imageHeight: 0,
                imageFormat: nil,
                originalSize: 0,
                thumbnailSize: 0,
                keyboardThumbnail: nil
            )
        }
    }
    
    // MARK: - 处理URL内容
    
    private func handleURLContent(_ itemProvider: NSItemProvider) {
        itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Failed to load URL: \(error.localizedDescription)")
                self.showError(L10n.shareErrorReadLinkFailed)
                return
            }
            
            var urlString: String?
            
            if let url = item as? URL {
                urlString = url.absoluteString
            } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                urlString = url.absoluteString
            }
            
            guard let content = urlString, !content.isEmpty else {
                self.showError(L10n.shareErrorEmptyLink)
                return
            }
            
            print("🔗 Successfully extracted URL: \(content)")
            
            self.saveClipItem(
                content: content,
                contentType: "link",
                sourceApp: self.getSourceAppName(),
                imageData: nil,
                imageWidth: 0,
                imageHeight: 0,
                imageFormat: nil,
                originalSize: 0,
                thumbnailSize: 0,
                keyboardThumbnail: nil
            )
        }
    }
    
    // MARK: - 处理图片内容
    
    private func handleImageContent(_ itemProvider: NSItemProvider) {
        print("🖼️ Processing image...")
        
        itemProvider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (item, error) in
            guard let self = self else { return }

            print("📥 loadItem callback type: \(type(of: item))")
            
            if let error = error {
                print("❌ Failed to load image: \(error.localizedDescription)")
                self.showError(L10n.shareErrorReadImageFailed)
                return
            }
            
            // 从不同来源提取 UIImage
            var image: UIImage?
            var originalSize: Int64 = 0
            var imageFormat: String = "JPEG"
            
            if let img = item as? UIImage {
                image = img
                print("✅ Got UIImage directly")
            } else if let data = item as? Data {
                image = UIImage(data: data)
                originalSize = Int64(data.count)
                
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
                
                print("✅ Converted Data to UIImage (\(data.count) bytes)")
            } else if let url = item as? URL {
                if let data = try? Data(contentsOf: url) {
                    image = UIImage(data: data)
                    originalSize = Int64(data.count)
                    imageFormat = url.pathExtension.uppercased()
                    print("✅ Loaded image from URL (\(data.count) bytes)")
                }
            }
            
            guard let originalImage = image else {
                self.showError(L10n.shareErrorReadImageFailed)
                return
            }
            
            print("📐 Original size: \(originalImage.size.width) × \(originalImage.size.height)")
            
            // 生成中等缩略图（主 App 使用）
            guard let mediumThumbnail = self.compressImage(originalImage, targetWidth: 400) else {
                self.showError(L10n.shareErrorCompressFailed)
                return
            }

            // 生成超小缩略图（键盘扩展使用）
            guard let keyboardThumbnail = self.compressImage(originalImage, targetWidth: 60, quality: 0.3) else {
                self.showError(L10n.shareErrorThumbnailFailed)
                return
            }

            print("✅ Image compression completed:")
            print("  - Original: \(originalSize) bytes")
            print("  - Medium thumbnail: \(mediumThumbnail.count) bytes")
            print("  - Keyboard thumbnail: \(keyboardThumbnail.count) bytes")
            
            self.saveClipItem(
                content: L10n.shareImageLabel,
                contentType: "image",
                sourceApp: self.getSourceAppName(),
                imageData: mediumThumbnail,
                imageWidth: Int32(originalImage.size.width),
                imageHeight: Int32(originalImage.size.height),
                imageFormat: imageFormat,
                originalSize: originalSize,
                thumbnailSize: Int64(mediumThumbnail.count),
                keyboardThumbnail: keyboardThumbnail
            )
        }
    }
    
    /// 压缩图片到指定宽度（保持宽高比）
    private func compressImage(_ image: UIImage, targetWidth: CGFloat = 400, quality: CGFloat = 0.7) -> Data? {
        let originalSize = image.size
        
        let scale = min(targetWidth / originalSize.width, 1.0)
        let newHeight = originalSize.height * scale
        let newSize = CGSize(width: originalSize.width * scale, height: newHeight)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        guard let jpegData = resizedImage.jpegData(compressionQuality: quality) else {
            return nil
        }
        
        if jpegData.count > Int(targetWidth * targetWidth * 0.5) && quality > 0.1 {
            print("⚠️ Thumbnail still too large (\(jpegData.count) bytes), retrying...")
            return compressImage(image, targetWidth: targetWidth, quality: quality - 0.1)
        }
        
        return jpegData
    }
    
    // MARK: - 保存到Core Data
    
    private func saveClipItem(
        content: String,
        contentType: String,
        sourceApp: String,
        imageData: Data?,
        imageWidth: Int32,
        imageHeight: Int32,
        imageFormat: String?,
        originalSize: Int64,
        thumbnailSize: Int64,
        keyboardThumbnail: Data?
    ) {
        let context = persistenceController.container.newBackgroundContext()
        
        context.perform {
            let newItem = ClipItem(context: context)
            newItem.id = UUID()
            newItem.content = content
            newItem.contentType = contentType
            newItem.sourceApp = sourceApp
            newItem.createdAt = Date()
            newItem.isStarred = false

            if let imageData = imageData {
                newItem.imageData = imageData
                newItem.imageWidth = imageWidth
                newItem.imageHeight = imageHeight
                newItem.imageFormat = imageFormat
                newItem.originalSize = originalSize
                newItem.thumbnailSize = thumbnailSize
                newItem.keyboardThumbnail = keyboardThumbnail
            }
            
            print("💾 Saving:")
            print("  - Type: \(contentType)")
            print("  - Source: \(sourceApp)")
            if contentType == "image" {
                print("  - Original: \(imageWidth) × \(imageHeight)")
                print("  - Medium thumbnail: \(thumbnailSize) bytes")
                if let kbThumb = keyboardThumbnail {
                    print("  - Keyboard thumbnail: \(kbThumb.count) bytes")
                }
            }
            
            do {
                try context.save()
                print("✅ Share Extension saved successfully")

                DarwinNotificationCenter.shared.postNotification()
                WidgetCenter.shared.reloadAllTimelines()
                print("🔄 Widget refresh triggered")
                
                DispatchQueue.main.async {
                    self.showSuccess()
                }
            } catch {
                print("❌ Share Extension save failed: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    self.showError(String(format: L10n.shareErrorSaveFailed, error.localizedDescription))
                }
            }
        }
    }
    
    // MARK: - UI反馈方法
    
    private func showSuccess() {
        print("🎉 Showing success message")
        
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        
        statusLabel.text = L10n.shareSuccess
        statusLabel.textColor = .systemGreen
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            print("🚪 Closing Share Extension")
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
    
    private func showError(_ message: String) {
        print("❌ Showing error: \(message)")
        
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
            self.activityIndicator.isHidden = true
            
            self.statusLabel.text = "❌ \(message)"
            self.statusLabel.textColor = .systemRed
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                print("🚪 Closing Share Extension (error)")
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
        return L10n.shareDefaultSource
    }
}
