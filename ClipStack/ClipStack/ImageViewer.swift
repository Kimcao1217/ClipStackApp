//
//  ImageViewer.swift
//  ClipStack
//
//  图片查看器 - 使用 UIKit 实现全屏图片浏览

import UIKit
import SwiftUI

/// UIKit 图片查看控制器（全屏显示，支持缩放和拖动）
class ImageViewerViewController: UIViewController {
    
    // 图片数据
    private let clipItem: ClipItem
    
    // UI 组件
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let closeButton = UIButton(type: .system)
    private let shareButton = UIButton(type: .system)
    private let infoLabel = UILabel()
    
    // MARK: - 初始化
    
    init(clipItem: ClipItem) {
        self.clipItem = clipItem
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - 生命周期
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        loadImage()
        
        print("🖼️ 图片查看器已加载")
    }
    
    // MARK: - UI 设置
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // 配置 ScrollView（支持缩放）
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // 配置 ImageView
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)
        
        // 配置关闭按钮
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        closeButton.layer.cornerRadius = 20
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        view.addSubview(closeButton)
        
        // 配置分享按钮
        shareButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        shareButton.tintColor = .white
        shareButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        shareButton.layer.cornerRadius = 20
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        view.addSubview(shareButton)
        
        // 配置信息标签
        infoLabel.textColor = .white
        infoLabel.font = .systemFont(ofSize: 12)
        infoLabel.numberOfLines = 0
        infoLabel.textAlignment = .center
        infoLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        infoLabel.layer.cornerRadius = 8
        infoLabel.layer.masksToBounds = true
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(infoLabel)
        
        // 设置信息文本
        var infoText = clipItem.imageFullDescription
        if let sourceApp = clipItem.sourceApp {
            infoText += "\n来源：\(sourceApp) • \(clipItem.relativeTimeString)"
        }
        infoLabel.text = infoText
        
        // 布局约束
        NSLayoutConstraint.activate([
            // ScrollView 填满整个屏幕
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // ImageView 填满 ScrollView
            imageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            
            // 关闭按钮（左上角）
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),
            
            // 分享按钮（右上角）
            shareButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            shareButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            shareButton.widthAnchor.constraint(equalToConstant: 40),
            shareButton.heightAnchor.constraint(equalToConstant: 40),
            
            // 信息标签（底部中央）
            infoLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            infoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            infoLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            infoLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
        
        infoLabel.setContentHuggingPriority(.required, for: .vertical)
        infoLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        
        // 添加双击手势（放大/还原）
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        imageView.addGestureRecognizer(doubleTapGesture)
    }
    
    private func loadImage() {
        guard let image = clipItem.thumbnailImage else {
            print("❌ 无法加载图片")
            return
        }
        
        imageView.image = image
        print("✅ 图片已加载到查看器")
    }
    
    // MARK: - 用户交互
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true) {
            print("🚪 图片查看器已关闭")
        }
    }
    
    @objc private func shareButtonTapped() {
        guard let image = clipItem.thumbnailImage else {
            print("⚠️ 没有图片可分享")
            return
        }
        
        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        
        // iPad 支持（在分享按钮位置显示）
        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = shareButton
            popoverController.sourceRect = shareButton.bounds
        }
        
        present(activityVC, animated: true)
        print("📤 打开分享面板")
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if scrollView.zoomScale > 1.0 {
            // 当前已放大，还原到 1.0
            scrollView.setZoomScale(1.0, animated: true)
        } else {
            // 放大到 2.0，并以点击位置为中心
            let location = gesture.location(in: imageView)
            let zoomRect = zoomRectForScale(2.0, center: location)
            scrollView.zoom(to: zoomRect, animated: true)
        }
    }
    
    /// 计算缩放区域
    private func zoomRectForScale(_ scale: CGFloat, center: CGPoint) -> CGRect {
        var zoomRect = CGRect.zero
        
        zoomRect.size.height = imageView.frame.size.height / scale
        zoomRect.size.width = imageView.frame.size.width / scale
        
        let newCenter = imageView.convert(center, from: scrollView)
        
        zoomRect.origin.x = newCenter.x - (zoomRect.size.width / 2.0)
        zoomRect.origin.y = newCenter.y - (zoomRect.size.height / 2.0)
        
        return zoomRect
    }
}

// MARK: - UIScrollViewDelegate（缩放支持）

extension ImageViewerViewController: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // 缩放时保持图片居中
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
        
        imageView.center = CGPoint(
            x: scrollView.contentSize.width * 0.5 + offsetX,
            y: scrollView.contentSize.height * 0.5 + offsetY
        )
    }
}

// MARK: - SwiftUI 桥接（⭐ 新增）

/// SwiftUI 包装器，用于在 SwiftUI 中显示 UIKit 的图片查看器
struct ImageViewerRepresentable: UIViewControllerRepresentable {
    let clipItem: ClipItem
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> ImageViewerViewController {
        return ImageViewerViewController(clipItem: clipItem)
    }
    
    func updateUIViewController(_ uiViewController: ImageViewerViewController, context: Context) {
        // 不需要更新
    }
}
