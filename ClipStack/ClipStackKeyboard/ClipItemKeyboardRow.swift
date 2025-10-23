//
//  ClipItemKeyboardRow.swift
//  ClipStackKeyboard
//
//  键盘上显示的单个剪贴板条目行（支持图片显示）

import UIKit

class ClipItemKeyboardRow: UIView {
    
    // UI组件
    private let typeIconLabel = UILabel()
    private let thumbnailImageView = UIImageView()  // ⭐ 新增：图片缩略图
    private let contentLabel = UILabel()
    private let timeLabel = UILabel()
    private let starIconView = UIImageView()
    private let actionLabel = UILabel()  // ⭐ 新增：操作提示（"点击复制"）
    
    // 数据模型
    var clipItem: ClipItem? {
        didSet {
            updateUI()
        }
    }
    
    // 点击回调
    var onTap: (() -> Void)?
    
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
        // 设置背景和圆角
        backgroundColor = UIColor.systemGray6
        layer.cornerRadius = 8
        layer.masksToBounds = true
        
        // 配置类型图标（文本/链接用）
        typeIconLabel.font = .systemFont(ofSize: 24)
        typeIconLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(typeIconLabel)
        
        // ⭐ 配置图片缩略图（图片用）
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.layer.cornerRadius = 6
        thumbnailImageView.layer.masksToBounds = true
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailImageView.isHidden = true  // 默认隐藏
        addSubview(thumbnailImageView)
        
        // 配置内容标签
        contentLabel.font = .systemFont(ofSize: 14)
        contentLabel.numberOfLines = 2
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentLabel)
        
        // 配置时间标签
        timeLabel.font = .systemFont(ofSize: 11)
        timeLabel.textColor = .secondaryLabel
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(timeLabel)
        
        // 配置收藏图标
        starIconView.image = UIImage(systemName: "star.fill")
        starIconView.tintColor = .systemYellow
        starIconView.translatesAutoresizingMaskIntoConstraints = false
        starIconView.isHidden = true
        addSubview(starIconView)
        
        // ⭐ 配置操作提示标签
        actionLabel.font = .systemFont(ofSize: 10, weight: .medium)
        actionLabel.textColor = .systemBlue
        actionLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(actionLabel)
        
        // 布局约束
        NSLayoutConstraint.activate([
            // 类型图标（与缩略图位置相同）
            typeIconLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            typeIconLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            typeIconLabel.widthAnchor.constraint(equalToConstant: 44),
            
            // ⭐ 图片缩略图
            thumbnailImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            thumbnailImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 44),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 44),
            
            // 内容标签
            contentLabel.leadingAnchor.constraint(equalTo: typeIconLabel.trailingAnchor, constant: 8),
            contentLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            contentLabel.trailingAnchor.constraint(equalTo: starIconView.leadingAnchor, constant: -8),
            
            // 时间标签
            timeLabel.leadingAnchor.constraint(equalTo: contentLabel.leadingAnchor),
            timeLabel.topAnchor.constraint(equalTo: contentLabel.bottomAnchor, constant: 2),
            timeLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            
            // 收藏图标
            starIconView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            starIconView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            starIconView.widthAnchor.constraint(equalToConstant: 16),
            starIconView.heightAnchor.constraint(equalToConstant: 16),
            
            // ⭐ 操作提示标签
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
        // 添加点击动画
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
        
        // ⭐ 判断是否为图片
        if item.contentType == "image" {
            // 显示图片缩略图
            typeIconLabel.isHidden = true
            thumbnailImageView.isHidden = false
            
            if let imageData = item.imageData, let image = UIImage(data: imageData) {
                thumbnailImageView.image = image
            } else {
                thumbnailImageView.image = UIImage(systemName: "photo")
                thumbnailImageView.contentMode = .center
            }
            
            // 显示图片信息
            contentLabel.text = item.imageFullDescription
            
            // 操作提示
            actionLabel.text = "点击复制"
            
        } else {
            // 显示类型图标
            typeIconLabel.isHidden = false
            thumbnailImageView.isHidden = true
            
            // 类型图标
            typeIconLabel.text = item.typeIcon
            
            // 内容文本（限制更短，适合键盘高度）
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
            
            // 操作提示
            actionLabel.text = "点击插入"
        }
        
        // 时间显示
        timeLabel.text = item.relativeTimeString
        
        // 收藏状态
        starIconView.isHidden = !item.isStarred
    }
}


