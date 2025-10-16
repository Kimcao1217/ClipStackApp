//
//  ClipItemKeyboardRow.swift
//  ClipStackKeyboard
//
//  键盘上显示的单个剪贴板条目行
//  简化版本，适合键盘扩展的有限高度

import UIKit

class ClipItemKeyboardRow: UIView {
    
    // UI组件
    private let typeIconLabel = UILabel()
    private let contentLabel = UILabel()
    private let timeLabel = UILabel()
    private let starIconView = UIImageView()
    
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
        
        // 配置类型图标
        typeIconLabel.font = .systemFont(ofSize: 24)
        typeIconLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(typeIconLabel)
        
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
        
        // 布局约束
        NSLayoutConstraint.activate([
            // 类型图标
            typeIconLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            typeIconLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            typeIconLabel.widthAnchor.constraint(equalToConstant: 28),
            
            // 内容标签
            contentLabel.leadingAnchor.constraint(equalTo: typeIconLabel.trailingAnchor, constant: 8),
            contentLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            contentLabel.trailingAnchor.constraint(equalTo: starIconView.leadingAnchor, constant: -8),
            
            // 时间标签
            timeLabel.leadingAnchor.constraint(equalTo: contentLabel.leadingAnchor),
            timeLabel.topAnchor.constraint(equalTo: contentLabel.bottomAnchor, constant: 4),
            timeLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            
            // 收藏图标
            starIconView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            starIconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            starIconView.widthAnchor.constraint(equalToConstant: 16),
            starIconView.heightAnchor.constraint(equalToConstant: 16)
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
        
        // 时间显示
        timeLabel.text = item.relativeTimeString
        
        // 收藏状态
        starIconView.isHidden = !item.isStarred
    }
}
