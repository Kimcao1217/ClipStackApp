//
//  KeyboardViewController.swift
//  ClipStackKeyboard
//
//  自定义键盘扩展主控制器
//  显示剪贴板历史记录并支持快速插入

import UIKit
import CoreData

class KeyboardViewController: UIInputViewController {
    
    // Core Data持久化控制器
    private let persistenceController = PersistenceController.shared
    
    // 剪贴板条目数据
    private var clipItems: [ClipItem] = []
    
    // UI组件
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let headerView = UIView()
    private let headerLabel = UILabel()
    private let switchKeyboardButton = UIButton(type: .system)
    private let emptyStateLabel = UILabel()
    
    // 键盘高度约束
    private var heightConstraint: NSLayoutConstraint?
    
    // MARK: - 生命周期
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("⌨️ 键盘扩展启动")
        
        setupUI()
        setupKeyboardHeight()
        loadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 每次显示键盘时刷新数据
        print("👀 键盘即将显示，刷新数据")
        loadData()
    }
    
    // MARK: - UI设置
    
    private func setupUI() {
        view.backgroundColor = UIColor.systemGray5
        
        // ===== 顶部工具栏 =====
        headerView.backgroundColor = UIColor.systemGray4
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)
        
        // 标题标签
        headerLabel.text = "📋 ClipStack"
        headerLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(headerLabel)
        
        // 切换键盘按钮（地球图标）
        switchKeyboardButton.setImage(UIImage(systemName: "globe"), for: .normal)
        switchKeyboardButton.addTarget(self, action: #selector(handleSwitchKeyboard), for: .touchUpInside)
        switchKeyboardButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(switchKeyboardButton)
        
        // ===== 滚动视图 =====
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        
        // ===== 内容栈视图 =====
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        
        // ===== 空状态标签 =====
        emptyStateLabel.text = "还没有剪贴板历史\n在主App中添加内容"
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.textColor = .secondaryLabel
        emptyStateLabel.font = .systemFont(ofSize: 14)
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.isHidden = true
        view.addSubview(emptyStateLabel)
        
        // ===== 布局约束 =====
        NSLayoutConstraint.activate([
            // 顶部工具栏
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 44),
            
            // 标题
            headerLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            headerLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            
            // 切换键盘按钮
            switchKeyboardButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            switchKeyboardButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            switchKeyboardButton.widthAnchor.constraint(equalToConstant: 44),
            switchKeyboardButton.heightAnchor.constraint(equalToConstant: 44),
            
            // 滚动视图
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 栈视图
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -8),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -8),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -16),
            
            // 空状态标签
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            emptyStateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }
    
    private func setupKeyboardHeight() {
        // ⚠️ 关键：设置键盘高度为280（根据官方文档建议）
        // 参考：https://developer.apple.com/documentation/uikit/configuring-a-custom-keyboard-interface
        heightConstraint = NSLayoutConstraint(
            item: view!,
            attribute: .height,
            relatedBy: .equal,
            toItem: nil,
            attribute: .notAnAttribute,
            multiplier: 0.0,
            constant: 280
        )
        heightConstraint?.priority = .required
        view.addConstraint(heightConstraint!)
        
        print("⚙️ 键盘高度设置为: 280")
    }
    
    // MARK: - 数据加载
    
    private func loadData() {
        let context = persistenceController.container.viewContext
        
        let fetchRequest: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipItem.createdAt, ascending: false)]
        fetchRequest.fetchLimit = 20  // 只显示最近20条，避免性能问题
        
        do {
            clipItems = try context.fetch(fetchRequest)
            print("✅ 键盘扩展加载了 \(clipItems.count) 条数据")
            
            updateUI()
        } catch {
            print("❌ 键盘扩展数据加载失败: \(error.localizedDescription)")
            clipItems = []
            updateUI()
        }
    }
    
    // MARK: - UI更新
    
    private func updateUI() {
        // 清空现有视图
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        if clipItems.isEmpty {
            // 显示空状态
            emptyStateLabel.isHidden = false
            scrollView.isHidden = true
        } else {
            // 显示数据列表
            emptyStateLabel.isHidden = true
            scrollView.isHidden = false
            
            for item in clipItems {
                let rowView = ClipItemKeyboardRow()
                rowView.clipItem = item
                rowView.translatesAutoresizingMaskIntoConstraints = false
                
                // 设置点击回调
                rowView.onTap = { [weak self, weak item] in
                    guard let self = self, let item = item else { return }
                    self.handleItemTap(item)
                }
                
                stackView.addArrangedSubview(rowView)
                
                // 设置行高度
                NSLayoutConstraint.activate([
                    rowView.heightAnchor.constraint(equalToConstant: 60)
                ])
            }
        }
    }
    
    // MARK: - 用户交互
    
    @objc private func handleSwitchKeyboard() {
        // 切换到系统默认键盘或其他键盘
        // ⚠️ 关键：调用UIInputViewController的方法
        advanceToNextInputMode()
        print("🌐 切换键盘")
    }
    
    private func handleItemTap(_ item: ClipItem) {
        guard let content = item.content else {
            print("⚠️ 条目内容为空")
            return
        }
        
        print("📝 准备插入文本: \(content.prefix(50))...")
        
        // ⚠️ 关键：使用textDocumentProxy插入文本到当前输入框
        // 参考：https://developer.apple.com/documentation/uikit/uiinputviewcontroller/textdocumentproxy
        textDocumentProxy.insertText(content)
        
        // 更新使用计数（在后台上下文中）
        let context = persistenceController.container.newBackgroundContext()
        context.perform {
            // 在后台上下文中获取对象
            if let itemInContext = try? context.existingObject(with: item.objectID) as? ClipItem {
                itemInContext.markAsUsed()
                
                do {
                    try context.save()
                    print("✅ 使用次数已更新")
                } catch {
                    print("❌ 使用次数更新失败: \(error.localizedDescription)")
                }
            }
        }
        
        // 添加触觉反馈
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        print("✅ 文本插入成功")
    }
    
    // MARK: - 系统方法重写
    
    override func textWillChange(_ textInput: UITextInput?) {
        // 当输入框即将变化时调用（例如切换输入框）
    }
    
    override func textDidChange(_ textInput: UITextInput?) {
        // 当输入框内容变化时调用
    }
}