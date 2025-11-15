//
//  ClipItemKeyboardRow.swift
//  ClipStackKeyboard
//
//  键盘上显示的单个剪贴板条目行（支持图片显示）

import UIKit
import CoreData

class ClipItemKeyboardRow: UIView {
    
    // UI组件
    private let typeIconLabel = UILabel()
    private let thumbnailImageView = UIImageView()
    private let contentLabel = UILabel()
    private let timeLabel = UILabel()
    private let starIconView = UIImageView()
    private let actionLabel = UILabel()
    
    // 数据模型
    var clipItem: ClipItem? {
        didSet {
            updateUI()
        }
    }
    
    // 点击回调
    var onTap: (() -> Void)?

    // ⭐ 改用 NSCache（自动管理内存）
    var imageCache: NSCache<NSUUID, UIImage>?
    
    // MARK: - 初始化
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupGesture()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI设置
    
    private func setupUI() {
        backgroundColor = UIColor.systemGray6
        layer.cornerRadius = 8
        layer.masksToBounds = true
        
        typeIconLabel.font = .systemFont(ofSize: 24)
        typeIconLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(typeIconLabel)
        
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.layer.cornerRadius = 6
        thumbnailImageView.layer.masksToBounds = true
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailImageView.isHidden = true
        addSubview(thumbnailImageView)
        
        contentLabel.font = .systemFont(ofSize: 14)
        contentLabel.numberOfLines = 2
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentLabel)
        
        timeLabel.font = .systemFont(ofSize: 11)
        timeLabel.textColor = .secondaryLabel
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(timeLabel)
        
        starIconView.image = UIImage(systemName: "star.fill")
        starIconView.tintColor = .systemYellow
        starIconView.translatesAutoresizingMaskIntoConstraints = false
        starIconView.isHidden = true
        addSubview(starIconView)
        
        actionLabel.font = .systemFont(ofSize: 10, weight: .medium)
        actionLabel.textColor = .systemBlue
        actionLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(actionLabel)
        
        NSLayoutConstraint.activate([
            typeIconLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            typeIconLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            typeIconLabel.widthAnchor.constraint(equalToConstant: 44),
            
            thumbnailImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            thumbnailImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 44),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 44),
            
            contentLabel.leadingAnchor.constraint(equalTo: typeIconLabel.trailingAnchor, constant: 8),
            contentLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            contentLabel.trailingAnchor.constraint(equalTo: starIconView.leadingAnchor, constant: -8),
            
            timeLabel.leadingAnchor.constraint(equalTo: contentLabel.leadingAnchor),
            timeLabel.topAnchor.constraint(equalTo: contentLabel.bottomAnchor, constant: 2),
            timeLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            
            starIconView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            starIconView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            starIconView.widthAnchor.constraint(equalToConstant: 16),
            starIconView.heightAnchor.constraint(equalToConstant: 16),
            
            actionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            actionLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }
    
    private func setupGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        isUserInteractionEnabled = true
    }
    
    @objc private func handleTap() {
        UIView.animate(withDuration: 0.1, animations: {
            self.alpha = 0.5
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.alpha = 1.0
            }
        }
        
        onTap?()
    }
    
    // MARK: - 更新UI
    
    private func updateUI() {
        guard let item = clipItem else { return }
        
        if item.contentType == "image" {
            typeIconLabel.isHidden = true
            thumbnailImageView.isHidden = false
            
            // ⭐ 优先从缓存读取
            if let itemID = item.id, let cachedImage = imageCache?.object(forKey: itemID as NSUUID) {
                thumbnailImageView.image = cachedImage
                print("📦 从缓存读取图片: \(itemID)")
            } else if let thumbnailData = item.keyboardThumbnail {
                // 从 keyboardThumbnail 字段读取
                if let image = UIImage(data: thumbnailData) {
                    thumbnailImageView.image = image
                    
                    // 存入缓存（NSCache 会自动管理内存）
                    if let itemID = item.id {
                        imageCache?.setObject(image, forKey: itemID as NSUUID, cost: thumbnailData.count)
                    }
                    
                    print("✅ 加载键盘缩略图: \(thumbnailData.count) 字节")
                } else {
                    thumbnailImageView.image = UIImage(systemName: "photo")
                    thumbnailImageView.contentMode = .center
                }
            } else if let imageData = item.imageData {
                // 兜底：尝试实时压缩
                if let image = UIImage(data: imageData),
                   let smallThumb = compressToKeyboardSize(image) {
                    thumbnailImageView.image = smallThumb
                    
                    if let itemID = item.id {
                        imageCache?.setObject(smallThumb, forKey: itemID as NSUUID)
                    }
                    
                    print("⚠️ 实时压缩图片（建议重新保存）")
                } else {
                    thumbnailImageView.image = UIImage(systemName: "photo")
                    thumbnailImageView.contentMode = .center
                }
            } else {
                thumbnailImageView.image = UIImage(systemName: "photo")
                thumbnailImageView.contentMode = .center
            }
            
            contentLabel.text = item.imageFullDescription
            actionLabel.text = L10n.keyboardActionCopy
            
        } else {
            typeIconLabel.isHidden = false
            thumbnailImageView.isHidden = true
            
            typeIconLabel.text = item.typeIcon
            
            if let content = item.content {
                let maxLength = 60
                if content.count <= maxLength {
                    contentLabel.text = content
                } else {
                    let index = content.index(content.startIndex, offsetBy: maxLength - 3)
                    contentLabel.text = String(content[..<index]) + "..."
                }
            } else {
                contentLabel.text = ""
            }
            
            actionLabel.text = L10n.keyboardActionInsert
        }
        
        timeLabel.text = item.relativeTimeString
        starIconView.isHidden = !item.isStarred
    }

    /// 实时压缩为键盘尺寸（兜底方案）
    private func compressToKeyboardSize(_ image: UIImage) -> UIImage? {
        let targetSize = CGSize(width: 60, height: 60)
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
