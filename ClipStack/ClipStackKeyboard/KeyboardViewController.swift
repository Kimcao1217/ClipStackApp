//
//  KeyboardViewController.swift
//  ClipStackKeyboard
//
//  自定义键盘扩展主控制器
//  显示剪贴板历史记录（含图片）并支持快速插入/复制
//  分段控件筛选功能

import UIKit
import CoreData

class KeyboardViewController: UIInputViewController {
    
    // Core Data持久化控制器
    private let persistenceController = PersistenceController.shared
    
    // 剪贴板条目数据
    private var clipItems: [ClipItem] = []

    // 分页加载相关
private var currentPage = 0
private let itemsPerPage = 10  // 每页10条
private var isLoadingMore = false
private var hasMoreData = true

// 图片缓存池（自动管理内存）
private var imageCache: [UUID: UIImage] = [:]
private let maxCacheSize = 20  // 最多缓存 20 张图片
    
    // 当前选中的筛选类型
    private enum FilterType: Int {
        case all = 0
        case text = 1
        case link = 2
        case image = 3
        case starred = 4
        
        var title: String {
            switch self {
            case .all: return "全部"
            case .text: return "文本"
            case .link: return "链接"
            case .image: return "图片"
            case .starred: return "收藏"
            }
        }
        
        var predicate: NSPredicate? {
            switch self {
            case .all:
                return nil
            case .text:
                return NSPredicate(format: "contentType == %@", "text")
            case .link:
                return NSPredicate(format: "contentType == %@", "link")
            case .image:
                return NSPredicate(format: "contentType == %@", "image")
            case .starred:
                return NSPredicate(format: "isStarred == %@", NSNumber(value: true))
            }
        }
    }
    
    private var currentFilter: FilterType = .all
    
    // UI组件
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let headerView = UIView()
    private let headerLabel = UILabel()
    private let switchKeyboardButton = UIButton(type: .system)
    private let emptyStateLabel = UILabel()
    
    // 筛选器
    private let filterSegmentedControl = UISegmentedControl(items: ["全部", "文本", "链接", "图片", "收藏"])
    
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
        
        // 筛选器（分段控件）
        filterSegmentedControl.selectedSegmentIndex = 0  // 默认选中"全部"
        filterSegmentedControl.addTarget(self, action: #selector(handleFilterChanged), for: .valueChanged)
        filterSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filterSegmentedControl)
        
        // ===== 滚动视图 =====
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.delegate = self
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
            
            // 筛选器（在工具栏下方）
            filterSegmentedControl.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
            filterSegmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            filterSegmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            filterSegmentedControl.heightAnchor.constraint(equalToConstant: 28),
            
            // 滚动视图（在筛选器下方）
            scrollView.topAnchor.constraint(equalTo: filterSegmentedControl.bottomAnchor, constant: 8),
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
        // 设置键盘高度为280
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
    
    /// 根据当前筛选器加载数据（支持分页）
private func loadData(isLoadingMore: Bool = false) {
    let context = persistenceController.container.viewContext
    
    let fetchRequest: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
    fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipItem.createdAt, ascending: false)]
    
    // 应用筛选条件
    if let predicate = currentFilter.predicate {
        fetchRequest.predicate = predicate
    }
    
    // ⭐ 分页加载：只获取当前页的数据
    if isLoadingMore {
        currentPage += 1
    } else {
        currentPage = 0
        clipItems.removeAll()
        imageCache.removeAll()  // 清空缓存
    }
    
    fetchRequest.fetchLimit = itemsPerPage
    fetchRequest.fetchOffset = currentPage * itemsPerPage
    
    do {
        let newItems = try context.fetch(fetchRequest)
        
        if isLoadingMore {
            clipItems.append(contentsOf: newItems)
        } else {
            clipItems = newItems
        }
        
        hasMoreData = newItems.count == itemsPerPage
        
        print("✅ 键盘扩展加载 \(newItems.count) 条数据（第 \(currentPage) 页，筛选器：\(currentFilter.title)）")
        print("📊 当前总共 \(clipItems.count) 条，还有更多数据：\(hasMoreData)")
        
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
            // 显示空状态（根据筛选器调整提示文案）
            emptyStateLabel.isHidden = false
            scrollView.isHidden = true
            
            // 根据筛选器显示不同的空状态提示
            switch currentFilter {
            case .all:
                emptyStateLabel.text = "还没有剪贴板历史\n在主App中添加内容"
            case .text:
                emptyStateLabel.text = "还没有文本内容\n试试分享文字到ClipStack"
            case .link:
                emptyStateLabel.text = "还没有链接\n试试分享网页到ClipStack"
            case .image:
                emptyStateLabel.text = "还没有图片\n试试分享照片到ClipStack"
            case .starred:
                emptyStateLabel.text = "还没有收藏的内容\n在主App中收藏常用内容"
            }
        } else {
            // 显示数据列表
            emptyStateLabel.isHidden = true
            scrollView.isHidden = false
            
            for item in clipItems {
    let rowView = ClipItemKeyboardRow()
    rowView.clipItem = item
    rowView.imageCache = imageCache  // ⭐ 传递缓存池
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

// ⭐ 如果还有更多数据，显示加载提示
if hasMoreData {
    let loadingLabel = UILabel()
    loadingLabel.text = "上滑加载更多..."
    loadingLabel.textAlignment = .center
    loadingLabel.font = .systemFont(ofSize: 12)
    loadingLabel.textColor = .secondaryLabel
    loadingLabel.translatesAutoresizingMaskIntoConstraints = false
    stackView.addArrangedSubview(loadingLabel)
    
    NSLayoutConstraint.activate([
        loadingLabel.heightAnchor.constraint(equalToConstant: 40)
    ])
}
        }
    }
    
    // MARK: - 用户交互
    
    @objc private func handleSwitchKeyboard() {
        // 切换到系统默认键盘或其他键盘
        advanceToNextInputMode()
        print("🌐 切换键盘")
    }
    
    /// 筛选器切换处理
    @objc private func handleFilterChanged() {
        let selectedIndex = filterSegmentedControl.selectedSegmentIndex
        guard let newFilter = FilterType(rawValue: selectedIndex) else { return }
        
        print("🔄 筛选器切换: \(currentFilter.title) → \(newFilter.title)")
        
        currentFilter = newFilter
        
        // 添加轻微的触觉反馈
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        
        // 重新加载数据
        loadData()
    }
    
    private func handleItemTap(_ item: ClipItem) {
        // ⭐ 根据内容类型处理
        if item.contentType == "image" {
            // 图片类型：复制到剪贴板
            copyImageToPasteboard(item)
        } else {
            // 文本/链接类型：插入到输入框
            insertTextToInputField(item)
        }
    }
    
    /// 复制图片到剪贴板
    private func copyImageToPasteboard(_ item: ClipItem) {
        guard let imageData = item.imageData,
              let image = UIImage(data: imageData) else {
            print("⚠️ 图片数据为空")
            showToast("❌ 图片加载失败")
            return
        }
        
        // ⭐ 检查是否有完全访问权限
        if !hasFullAccess() {
            showFullAccessRequiredAlert()
            return
        }
        
        // 复制到系统剪贴板
        UIPasteboard.general.image = image
        
        print("📋 图片已复制到剪贴板")
        showToast("✅ 图片已复制")
        
        // 触觉反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    /// ⭐ 检测是否有完全访问权限
    private func hasFullAccess() -> Bool {
        // 方法1：尝试访问剪贴板
        if UIPasteboard.general.hasStrings || UIPasteboard.general.hasImages {
            return true
        }
        
        // 方法2：检查是否能写入
        let testString = "test"
        UIPasteboard.general.string = testString
        let canWrite = UIPasteboard.general.string == testString
        
        return canWrite
    }
    
    /// ⭐ 显示权限请求提示
    private func showFullAccessRequiredAlert() {
        // 创建提示视图
        let alertView = UIView()
        alertView.backgroundColor = UIColor.systemBackground
        alertView.layer.cornerRadius = 12
        alertView.layer.shadowColor = UIColor.black.cgColor
        alertView.layer.shadowOpacity = 0.3
        alertView.layer.shadowOffset = CGSize(width: 0, height: 2)
        alertView.layer.shadowRadius = 8
        alertView.translatesAutoresizingMaskIntoConstraints = false
        
        // 图标
        let iconLabel = UILabel()
        iconLabel.text = "🔒"
        iconLabel.font = .systemFont(ofSize: 40)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        alertView.addSubview(iconLabel)
        
        // 标题
        let titleLabel = UILabel()
        titleLabel.text = "需要开启\"允许完全访问\""
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        alertView.addSubview(titleLabel)
        
        // 说明
        let messageLabel = UILabel()
        messageLabel.text = "复制图片到剪贴板需要此权限\n\n设置 → 通用 → 键盘 → ClipStack\n→ 开启\"允许完全访问\""
        messageLabel.font = .systemFont(ofSize: 12)
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        alertView.addSubview(messageLabel)
        
        // 关闭按钮
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("我知道了", for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        closeButton.backgroundColor = .systemBlue
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.layer.cornerRadius = 8
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(dismissAlert), for: .touchUpInside)
        alertView.addSubview(closeButton)
        
        // 添加到视图
        view.addSubview(alertView)
        
        // 保存引用（用于关闭）
        alertView.tag = 999
        
        // 布局
        NSLayoutConstraint.activate([
            alertView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            alertView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            alertView.widthAnchor.constraint(equalToConstant: 280),
            
            iconLabel.topAnchor.constraint(equalTo: alertView.topAnchor, constant: 20),
            iconLabel.centerXAnchor.constraint(equalTo: alertView.centerXAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: alertView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: alertView.trailingAnchor, constant: -16),
            
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: alertView.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: alertView.trailingAnchor, constant: -16),
            
            closeButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 20),
            closeButton.leadingAnchor.constraint(equalTo: alertView.leadingAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: alertView.trailingAnchor, constant: -16),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            closeButton.bottomAnchor.constraint(equalTo: alertView.bottomAnchor, constant: -20)
        ])
        
        // 淡入动画
        alertView.alpha = 0
        alertView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0, options: [], animations: {
            alertView.alpha = 1
            alertView.transform = .identity
        })
        
        print("🔒 显示权限请求提示")
    }
    
    @objc private func dismissAlert() {
        if let alertView = view.viewWithTag(999) {
            UIView.animate(withDuration: 0.2, animations: {
                alertView.alpha = 0
                alertView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            }) { _ in
                alertView.removeFromSuperview()
            }
        }
    }
    
    /// 插入文本到输入框
    private func insertTextToInputField(_ item: ClipItem) {
        guard let content = item.content else {
            print("⚠️ 条目内容为空")
            return
        }
        
        print("📝 准备插入文本: \(content.prefix(50))...")
        
        // 使用textDocumentProxy插入文本到当前输入框
        textDocumentProxy.insertText(content)
        
        // 触觉反馈
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        print("✅ 文本插入成功")
    }
    
    /// ⭐ 显示提示信息（Toast）
    private func showToast(_ message: String) {
        // 创建一个临时标签显示提示
        let toastLabel = UILabel()
        toastLabel.text = message
        toastLabel.font = .systemFont(ofSize: 14, weight: .medium)
        toastLabel.textColor = .white
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        toastLabel.textAlignment = .center
        toastLabel.layer.cornerRadius = 8
        toastLabel.layer.masksToBounds = true
        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(toastLabel)
        
        NSLayoutConstraint.activate([
            toastLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            toastLabel.heightAnchor.constraint(equalToConstant: 40),
            toastLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ])
        
        // 1.5秒后淡出消失
        UIView.animate(withDuration: 0.3, delay: 1.5, options: [], animations: {
            toastLabel.alpha = 0
        }) { _ in
            toastLabel.removeFromSuperview()
        }
    }
    
    // MARK: - 系统方法重写
    
    override func textWillChange(_ textInput: UITextInput?) {
        // 当输入框即将变化时调用（例如切换输入框）
    }
    
    override func textDidChange(_ textInput: UITextInput?) {
        // 当输入框内容变化时调用
    }
    
}

// MARK: - UIScrollViewDelegate（分页加载）

extension KeyboardViewController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // 滚动到底部时加载更多
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let scrollViewHeight = scrollView.frame.height
        
        // 当滚动到距离底部 50pt 时触发
        if offsetY > contentHeight - scrollViewHeight - 50 {
            loadMoreIfNeeded()
        }
        
        // ⭐ 主动释放不可见的图片缓存
        cleanupInvisibleImageCache()
    }
    
    private func loadMoreIfNeeded() {
        guard hasMoreData, !isLoadingMore else { return }
        
        print("📥 触发加载更多...")
        isLoadingMore = true
        
        // 延迟 0.1 秒加载（防止重复触发）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.loadData(isLoadingMore: true)
            self?.isLoadingMore = false
        }
    }
    
    /// 清理不可见的图片缓存
    private func cleanupInvisibleImageCache() {
        guard imageCache.count > maxCacheSize else { return }
        
        // 获取当前可见的行
        let visibleRows = stackView.arrangedSubviews.compactMap { $0 as? ClipItemKeyboardRow }
        let visibleIDs = Set(visibleRows.compactMap { $0.clipItem?.id })
        
        // 移除不可见的缓存
        imageCache = imageCache.filter { visibleIDs.contains($0.key) }
        
        print("🧹 清理图片缓存，剩余 \(imageCache.count) 张")
    }
}
