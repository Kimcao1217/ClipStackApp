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
    
    // ⭐ 优化：只保存 NSManagedObjectID（不直接持有 Core Data 对象）
    private var clipItemIDs: [NSManagedObjectID] = []

    // 分页加载相关
    private var currentPage = 0
    private let itemsPerPage = 10  // 每页10条
    private var isLoadingMore = false
    private var hasMoreData = true

    // ⭐ 优化：图片缓存池（限制大小，自动清理）
    private var imageCache: NSCache<NSUUID, UIImage> = {
        let cache = NSCache<NSUUID, UIImage>()
        cache.countLimit = 20  // 最多缓存 20 张图片
        cache.totalCostLimit = 10 * 1024 * 1024  // 最多 10MB
        return cache
    }()
    
    // 当前选中的筛选类型
    private enum FilterType: Int {
        case all = 0
        case text = 1
        case link = 2
        case image = 3
        case starred = 4
        
        var title: String {
            switch self {
            case .all: return L10n.keyboardFilterAll
            case .text: return L10n.keyboardFilterText
            case .link: return L10n.keyboardFilterLink
            case .image: return L10n.keyboardFilterImage
            case .starred: return L10n.keyboardFilterStarred
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
    private lazy var filterSegmentedControl: UISegmentedControl = {
        let items = [
            L10n.keyboardFilterAll,
            L10n.keyboardFilterText,
            L10n.keyboardFilterLink,
            L10n.keyboardFilterImage,
            L10n.keyboardFilterStarred
        ]
        return UISegmentedControl(items: items)
    }()
    
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
    
    // ⭐ 新增：内存警告处理
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        print("⚠️ 键盘扩展收到内存警告，清理缓存")
        
        // 清空图片缓存
        imageCache.removeAllObjects()
        
        // 只保留当前页数据
        if clipItemIDs.count > itemsPerPage {
            clipItemIDs = Array(clipItemIDs.prefix(itemsPerPage))
            currentPage = 0
            hasMoreData = true
            updateUI()
        }
    }
    
    // MARK: - UI设置
    
    private func setupUI() {
        view.backgroundColor = UIColor.systemGray5
        
        // ===== 顶部工具栏 =====
        headerView.backgroundColor = UIColor.systemGray4
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)
        
        // 标题标签
        headerLabel.text = L10n.keyboardTitle
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
        emptyStateLabel.text = L10n.keyboardEmptyAll
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
    
    /// ⭐ 优化：只加载 ObjectID（不直接持有对象）
    private func loadData(isLoadingMore: Bool = false) {
        let context = persistenceController.container.viewContext
        
        let fetchRequest: NSFetchRequest<NSManagedObjectID> = NSFetchRequest(entityName: "ClipItem")
        fetchRequest.resultType = .managedObjectIDResultType
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipItem.createdAt, ascending: false)]
        
        // 应用筛选条件
        if let predicate = currentFilter.predicate {
            fetchRequest.predicate = predicate
        }
        
        // ⭐ 分页加载
        if isLoadingMore {
            currentPage += 1
        } else {
            currentPage = 0
            clipItemIDs.removeAll()
            imageCache.removeAllObjects()  // 清空缓存
        }
        
        fetchRequest.fetchLimit = itemsPerPage
        fetchRequest.fetchOffset = currentPage * itemsPerPage
        
        do {
            let newIDs = try context.fetch(fetchRequest) as! [NSManagedObjectID]
            
            if isLoadingMore {
                clipItemIDs.append(contentsOf: newIDs)
            } else {
                clipItemIDs = newIDs
            }
            
            hasMoreData = newIDs.count == itemsPerPage
            
            print("✅ 键盘扩展加载 \(newIDs.count) 个 ObjectID（第 \(currentPage) 页，筛选器：\(currentFilter.title)）")
            print("📊 当前总共 \(clipItemIDs.count) 个，还有更多数据：\(hasMoreData)")
            
            updateUI()
        } catch {
            print("❌ 键盘扩展数据加载失败: \(error.localizedDescription)")
            clipItemIDs = []
            updateUI()
        }
    }
    
    // MARK: - UI更新
    
    private func updateUI() {
        // 清空现有视图
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        if clipItemIDs.isEmpty {
            // 显示空状态
            emptyStateLabel.isHidden = false
            scrollView.isHidden = true
            
            switch currentFilter {
            case .all:
                emptyStateLabel.text = L10n.keyboardEmptyAll
            case .text:
                emptyStateLabel.text = L10n.keyboardEmptyText
            case .link:
                emptyStateLabel.text = L10n.keyboardEmptyLink
            case .image:
                emptyStateLabel.text = L10n.keyboardEmptyImage
            case .starred:
                emptyStateLabel.text = L10n.keyboardEmptyStarred
            }
        } else {
            // 显示数据列表
            emptyStateLabel.isHidden = true
            scrollView.isHidden = false
            
            let context = persistenceController.container.viewContext
            
            for objectID in clipItemIDs {
                // ⭐ 按需加载对象（而不是一次性全部加载）
                guard let item = try? context.existingObject(with: objectID) as? ClipItem else {
                    continue
                }
                
                let rowView = ClipItemKeyboardRow()
                rowView.clipItem = item
                rowView.imageCache = imageCache  // ⭐ 传递 NSCache
                rowView.translatesAutoresizingMaskIntoConstraints = false
                
                // 设置点击回调
                rowView.onTap = { [weak self] in
                    self?.handleItemTap(objectID: objectID)
                }
                
                stackView.addArrangedSubview(rowView)
                
                // 设置行高度
                NSLayoutConstraint.activate([
                    rowView.heightAnchor.constraint(equalToConstant: 60)
                ])
            }

            // 如果还有更多数据，显示加载提示
            if hasMoreData {
                let loadingLabel = UILabel()
                loadingLabel.text = L10n.keyboardLoadMore
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
        advanceToNextInputMode()
        print("🌐 切换键盘")
    }
    
    @objc private func handleFilterChanged() {
        let selectedIndex = filterSegmentedControl.selectedSegmentIndex
        guard let newFilter = FilterType(rawValue: selectedIndex) else { return }
        
        print("🔄 筛选器切换: \(currentFilter.title) → \(newFilter.title)")
        
        currentFilter = newFilter
        
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        
        loadData()
    }
    
    /// ⭐ 优化：通过 ObjectID 处理点击（避免持有强引用）
    private func handleItemTap(objectID: NSManagedObjectID) {
        let context = persistenceController.container.viewContext
        
        guard let item = try? context.existingObject(with: objectID) as? ClipItem else {
            print("⚠️ 条目不存在或已被删除")
            showToast(L10n.toastError)
            return
        }
        
        if item.contentType == "image" {
            copyImageToPasteboard(item)
        } else {
            insertTextToInputField(item)
        }
    }
    
    /// 复制图片到剪贴板
    private func copyImageToPasteboard(_ item: ClipItem) {
        guard let imageData = item.imageData,
              let image = UIImage(data: imageData) else {
            print("⚠️ 图片数据为空")
            showToast(L10n.keyboardImageLoadFailed)
            return
        }
        
        if !hasFullAccess() {
            showFullAccessRequiredAlert()
            return
        }
        
        UIPasteboard.general.image = image
        
        print("📋 图片已复制到剪贴板")
        showToast(L10n.keyboardImageCopied)
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    /// 检测是否有完全访问权限
    private func hasFullAccess() -> Bool {
        if UIPasteboard.general.hasStrings || UIPasteboard.general.hasImages {
            return true
        }
        
        let testString = "test"
        UIPasteboard.general.string = testString
        let canWrite = UIPasteboard.general.string == testString
        
        return canWrite
    }
    
    /// 显示权限请求提示
    private func showFullAccessRequiredAlert() {
        let alertView = UIView()
        alertView.backgroundColor = UIColor.systemBackground
        alertView.layer.cornerRadius = 12
        alertView.layer.shadowColor = UIColor.black.cgColor
        alertView.layer.shadowOpacity = 0.3
        alertView.layer.shadowOffset = CGSize(width: 0, height: 2)
        alertView.layer.shadowRadius = 8
        alertView.translatesAutoresizingMaskIntoConstraints = false
        
        let iconLabel = UILabel()
        iconLabel.text = "🔒"
        iconLabel.font = .systemFont(ofSize: 40)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        alertView.addSubview(iconLabel)
        
        let titleLabel = UILabel()
        titleLabel.text = L10n.keyboardPermissionTitle
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        alertView.addSubview(titleLabel)
        
        let messageLabel = UILabel()
        messageLabel.text = L10n.keyboardPermissionMessage
        messageLabel.font = .systemFont(ofSize: 12)
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        alertView.addSubview(messageLabel)
        
        let closeButton = UIButton(type: .system)
        closeButton.setTitle(L10n.keyboardPermissionGotIt, for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        closeButton.backgroundColor = .systemBlue
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.layer.cornerRadius = 8
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(dismissAlert), for: .touchUpInside)
        alertView.addSubview(closeButton)
        
        view.addSubview(alertView)
        alertView.tag = 999
        
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
        
        textDocumentProxy.insertText(content)
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        print("✅ 文本插入成功")
    }
    
    /// 显示提示信息（Toast）
    private func showToast(_ message: String) {
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
        
        UIView.animate(withDuration: 0.3, delay: 1.5, options: [], animations: {
            toastLabel.alpha = 0
        }) { _ in
            toastLabel.removeFromSuperview()
        }
    }
}

// MARK: - UIScrollViewDelegate（分页加载）

extension KeyboardViewController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let scrollViewHeight = scrollView.frame.height
        
        if offsetY > contentHeight - scrollViewHeight - 50 {
            loadMoreIfNeeded()
        }
    }
    
    private func loadMoreIfNeeded() {
        guard hasMoreData, !isLoadingMore else { return }
        
        print("📥 触发加载更多...")
        isLoadingMore = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.loadData(isLoadingMore: true)
            self?.isLoadingMore = false
        }
    }
}
