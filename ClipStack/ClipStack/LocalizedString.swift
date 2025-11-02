//
//  LocalizedString.swift
//  ClipStack
//
//  多语言工具类
//  使用方法：Text(L10n.searchPlaceholder)
//

import Foundation

/// 本地化字符串枚举（命名简短，符合苹果规范）
enum L10n {
    // MARK: - 通用按钮
    static let cancel = NSLocalizedString("common.cancel", comment: "取消按钮")
    static let confirm = NSLocalizedString("common.confirm", comment: "确认按钮")
    static let delete = NSLocalizedString("common.delete", comment: "删除按钮")
    static let save = NSLocalizedString("common.save", comment: "保存按钮")
    static let done = NSLocalizedString("common.done", comment: "完成按钮")
    static let close = NSLocalizedString("common.close", comment: "关闭按钮")
    static let copy = NSLocalizedString("common.copy", comment: "复制按钮")
    static let share = NSLocalizedString("common.share", comment: "分享按钮")
    static let settings = NSLocalizedString("common.settings", comment: "设置按钮")
    
    // MARK: - 通用状态
    static let loading = NSLocalizedString("common.loading", comment: "加载中状态")
    static let error = NSLocalizedString("common.error", comment: "错误提示")
    static let success = NSLocalizedString("common.success", comment: "成功提示")
    static let empty = NSLocalizedString("common.empty", comment: "空状态")
    
    // MARK: - 通用时间
    static let justNow = NSLocalizedString("time.justNow", comment: "刚刚")
    static let minutesAgo = NSLocalizedString("time.minutesAgo", comment: "X分钟前")
    static let hoursAgo = NSLocalizedString("time.hoursAgo", comment: "X小时前")
    static let yesterday = NSLocalizedString("time.yesterday", comment: "昨天")
    static let daysAgo = NSLocalizedString("time.daysAgo", comment: "X天前")
    
    // 🔹 阶段 1 会添加更多 key（搜索、筛选、列表等）
    // MARK: - 主界面（ContentView）
    static let appTitle = NSLocalizedString("app.title", comment: "应用标题")
    
    // 搜索
    static let searchPlaceholder = NSLocalizedString("search.placeholder", comment: "搜索框占位符")
    static let searchNoResults = NSLocalizedString("search.noResults", comment: "搜索无结果")
    static let searchTryOtherKeywords = NSLocalizedString("search.tryOtherKeywords", comment: "搜索建议")
    
    // 筛选
    static let filterTitle = NSLocalizedString("filter.title", comment: "筛选标题")
    static let filterAll = NSLocalizedString("filter.all", comment: "全部筛选")
    static let filterText = NSLocalizedString("filter.text", comment: "文本筛选")
    static let filterLink = NSLocalizedString("filter.link", comment: "链接筛选")
    static let filterImage = NSLocalizedString("filter.image", comment: "图片筛选")
    static let filterStarred = NSLocalizedString("filter.starred", comment: "收藏筛选")
    static let filterEmpty = NSLocalizedString("filter.empty", comment: "筛选结果为空")
    static let filterSwitchToAll = NSLocalizedString("filter.switchToAll", comment: "切换到全部")
    
    // 空状态
    static let emptyHistoryTitle = NSLocalizedString("empty.history.title", comment: "空历史标题")
    static let emptyHistoryMessage = NSLocalizedString("empty.history.message", comment: "空历史提示")
    
    // 添加条目
    static let addItemTitle = NSLocalizedString("addItem.title", comment: "添加条目标题")
    static let addItemContentLabel = NSLocalizedString("addItem.contentLabel", comment: "内容标签")
    static let addItemSourceLabel = NSLocalizedString("addItem.sourceLabel", comment: "来源标签")
    static let addItemSourcePlaceholder = NSLocalizedString("addItem.sourcePlaceholder", comment: "来源占位符")
    
    // Toast 提示
    static let toastCopied = NSLocalizedString("toast.copied", comment: "复制成功")
    static let toastImageCopied = NSLocalizedString("toast.imageCopied", comment: "图片复制成功")
    static let toastStarred = NSLocalizedString("toast.starred", comment: "收藏成功")
    static let toastUnstarred = NSLocalizedString("toast.unstarred", comment: "取消收藏")
    static let toastStarredFull = NSLocalizedString("toast.starredFull", comment: "收藏已满")
    static let toastError = NSLocalizedString("toast.error", comment: "操作失败")
    
    // 来源
    static let sourceManual = NSLocalizedString("source.manual", comment: "手动添加")
    static let sourceUnknown = NSLocalizedString("source.unknown", comment: "未知来源")
    
    // 免费版限制
    static let freeLimitTitle = NSLocalizedString("freeLimit.title", comment: "免费版限制标题")
    static let freeLimitCount = NSLocalizedString("freeLimit.count", comment: "限制计数")
    
    // 操作按钮
    static let star = NSLocalizedString("filter.starred", comment: "收藏")
    static let unstar = NSLocalizedString("toast.unstarred", comment: "取消收藏")
    static let upgrade = NSLocalizedString("upgrade", comment: "升级")

    // MARK: - 数据层错误与日志（Persistence.swift + ClipItem+Extensions.swift）

// 错误提示
static let errorPreviewDataFailed = NSLocalizedString("error.previewDataFailed", comment: "预览数据创建失败")
static let errorAppGroupPathFailed = NSLocalizedString("error.appGroupPathFailed", comment: "无法获取App Group路径")
static let errorCoreDataLoadFailed = NSLocalizedString("error.coreDataLoadFailed", comment: "Core Data加载失败")
static let errorCleanupFailed = NSLocalizedString("error.cleanupFailed", comment: "清理历史记录失败")
static let errorQueryStarredFailed = NSLocalizedString("error.queryStarredFailed", comment: "查询收藏数失败")

// 成功提示
static let successCoreDataLoaded = NSLocalizedString("success.coreDataLoaded", comment: "Core Data加载成功")

// 时间相关
static let timeUnknown = NSLocalizedString("time.unknown", comment: "未知时间")

// 图片相关
static let imageCompressionDescription = NSLocalizedString("image.compressionDescription", comment: "图片压缩描述")

// 日志专用（控制台输出，可保持英文不翻译，或者翻译后开发者看懂即可）
static func logCurrentHistoryCount(_ current: Int, _ limit: Int) -> String {
    String(format: NSLocalizedString("log.currentHistoryCount", comment: ""), current, limit)
}

static let logAutoDeleteOldItem = NSLocalizedString("log.autoDeleteOldItem", comment: "自动删除旧条目")

static func logCleanupCompleted(_ count: Int) -> String {
    String(format: NSLocalizedString("log.cleanupCompleted", comment: ""), count)
}

static func logCurrentStarredCount(_ current: Int, _ limit: Int) -> String {
    String(format: NSLocalizedString("log.currentStarredCount", comment: ""), current, limit)
}

// MARK: - 详情页面（ClipItemDetailView.swift）

static let detailTitle = NSLocalizedString("detail.title", comment: "详情页标题")
static let detailSource = NSLocalizedString("detail.source", comment: "来源标签")
static let detailCreatedAt = NSLocalizedString("detail.createdAt", comment: "创建时间标签")
static let detailCopyContent = NSLocalizedString("detail.copyContent", comment: "复制内容按钮")
static let detailOpenInSafari = NSLocalizedString("detail.openInSafari", comment: "在Safari中打开")
static let alertDeleteTitle = NSLocalizedString("alert.deleteTitle", comment: "删除确认标题")
static let alertDeleteMessage = NSLocalizedString("alert.deleteMessage", comment: "删除确认消息")

// 日志（详情页）
static let logContentCopied = NSLocalizedString("log.contentCopied", comment: "内容已复制日志")
static let errorSaveFailed = NSLocalizedString("error.saveFailed", comment: "保存失败")
static let errorDeleteFailed = NSLocalizedString("error.deleteFailed", comment: "删除失败")

// MARK: - 设置页面（SettingsView.swift）

// 账户区
static let settingsProVersion = NSLocalizedString("settings.proVersion", comment: "Pro版本")
static let settingsFreeVersion = NSLocalizedString("settings.freeVersion", comment: "免费版本")
static let settingsUnlimitedThanks = NSLocalizedString("settings.unlimitedThanks", comment: "无限制感谢")
static let settingsUpgradeToPro = NSLocalizedString("settings.upgradeToPro", comment: "升级到Pro")
static let settingsProActivated = NSLocalizedString("settings.proActivated", comment: "Pro已激活")
static let settingsManageSubscription = NSLocalizedString("settings.manageSubscription", comment: "管理订阅")
static let settingsAccountHeader = NSLocalizedString("settings.accountHeader", comment: "账户section标题")

// 存储管理区
static let settingsHistoryLabel = NSLocalizedString("settings.historyLabel", comment: "历史记录标签")
static let settingsStarredLabel = NSLocalizedString("settings.starredLabel", comment: "收藏标签")
static let settingsStorageLabel = NSLocalizedString("settings.storageLabel", comment: "占用空间标签")
static let settingsItemCount = NSLocalizedString("settings.itemCount", comment: "条目数量格式")
static let settingsClearHistory = NSLocalizedString("settings.clearHistory", comment: "清空历史记录按钮")
static let settingsClearStarred = NSLocalizedString("settings.clearStarred", comment: "清空收藏按钮")
static let settingsResetAll = NSLocalizedString("settings.resetAll", comment: "完全重置按钮")
static let settingsClearAction = NSLocalizedString("settings.clearAction", comment: "清空操作按钮")
static let settingsDeleteAll = NSLocalizedString("settings.deleteAll", comment: "全部删除按钮")
static let settingsStorageHeader = NSLocalizedString("settings.storageHeader", comment: "存储管理section标题")
static let settingsStorageFooter = NSLocalizedString("settings.storageFooter", comment: "存储管理footer说明")

// Alert消息
static let alertClearHistoryMessage = NSLocalizedString("alert.clearHistoryMessage", comment: "清空历史记录确认消息")
static let alertClearStarredMessage = NSLocalizedString("alert.clearStarredMessage", comment: "清空收藏确认消息")
static let alertResetAllMessage = NSLocalizedString("alert.resetAllMessage", comment: "完全重置确认消息")

// 其他设置区
static let settingsResetOnboarding = NSLocalizedString("settings.resetOnboarding", comment: "重新显示引导")
static let settingsHelp = NSLocalizedString("settings.help", comment: "使用帮助")
static let settingsFeedback = NSLocalizedString("settings.feedback", comment: "意见反馈")
static let settingsRateApp = NSLocalizedString("settings.rateApp", comment: "App Store评分")
static let settingsOtherHeader = NSLocalizedString("settings.otherHeader", comment: "其他section标题")

// 关于区
static let settingsVersion = NSLocalizedString("settings.version", comment: "版本标签")
static let settingsTestTogglePro = NSLocalizedString("settings.testTogglePro", comment: "测试切换Pro")
static let settingsTestOn = NSLocalizedString("settings.testOn", comment: "ON")
static let settingsTestOff = NSLocalizedString("settings.testOff", comment: "OFF")
static let settingsAboutHeader = NSLocalizedString("settings.aboutHeader", comment: "关于section标题")

// 成功提示
static let successClearHistory = NSLocalizedString("success.clearHistory", comment: "清空历史成功")
static let successClearStarred = NSLocalizedString("success.clearStarred", comment: "清空收藏成功")
static let successResetAll = NSLocalizedString("success.resetAll", comment: "完全重置成功")
static let successOnboardingReset = NSLocalizedString("success.onboardingReset", comment: "引导已重置")

// 错误提示
static let errorLoadSettingsFailed = NSLocalizedString("error.loadSettingsFailed", comment: "加载设置失败")
static let errorDeleteFailedDetail = NSLocalizedString("error.deleteFailedDetail", comment: "删除失败详情")
static let errorAlertTitle = NSLocalizedString("error.alertTitle", comment: "错误弹窗标题")
static let alertOk = NSLocalizedString("alert.ok", comment: "好的按钮")

// 订阅状态
static let subscriptionLifetime = NSLocalizedString("subscription.lifetime", comment: "终身买断")
static let subscriptionYearly = NSLocalizedString("subscription.yearly", comment: "年付订阅")
static let subscriptionMonthly = NSLocalizedString("subscription.monthly", comment: "月付订阅")
static let subscriptionNone = NSLocalizedString("subscription.none", comment: "未订阅")

// 反馈相关
static let feedbackSubject = NSLocalizedString("feedback.subject", comment: "反馈邮件主题")
static let feedbackBody = NSLocalizedString("feedback.body", comment: "反馈邮件正文")

// 日志（设置页）
static func logSettingsDataLoaded(_ history: Int, _ starred: Int, _ size: String) -> String {
    String(format: NSLocalizedString("log.settingsDataLoaded", comment: ""), history, starred, size)
}

static let logEmailOpened = NSLocalizedString("log.emailOpened", comment: "已打开邮件客户端")
static let logSubscriptionPageOpened = NSLocalizedString("log.subscriptionPageOpened", comment: "已打开订阅页面")
static let logOnboardingReset = NSLocalizedString("log.onboardingReset", comment: "引导已重置日志")

// MARK: - 引导页面（OnboardingView.swift）

// 通用按钮
static let onboardingSkip = NSLocalizedString("onboarding.skip", comment: "跳过按钮")
static let onboardingNext = NSLocalizedString("onboarding.next", comment: "下一步按钮")
static let onboardingStart = NSLocalizedString("onboarding.start", comment: "开始使用按钮")

// 第1页：欢迎页
static let onboardingPage1Title = NSLocalizedString("onboarding.page1.title", comment: "欢迎使用 ClipStack")
static let onboardingPage1Subtitle = NSLocalizedString("onboarding.page1.subtitle", comment: "强大的剪贴板历史管理工具")
static let onboardingPage1Feature1 = NSLocalizedString("onboarding.page1.feature1", comment: "功能1：自动保存")
static let onboardingPage1Feature2 = NSLocalizedString("onboarding.page1.feature2", comment: "功能2：支持多种格式")
static let onboardingPage1Feature3 = NSLocalizedString("onboarding.page1.feature3", comment: "功能3：收藏功能")
static let onboardingPage1Feature4 = NSLocalizedString("onboarding.page1.feature4", comment: "功能4：iCloud同步")

// 第2页：键盘设置
static let onboardingPage2Title = NSLocalizedString("onboarding.page2.title", comment: "添加自定义键盘")
static let onboardingPage2Subtitle = NSLocalizedString("onboarding.page2.subtitle", comment: "在任何 App 中快速插入历史内容")
static let onboardingPage2Step1 = NSLocalizedString("onboarding.page2.step1", comment: "步骤1：打开设置")
static let onboardingPage2Step2 = NSLocalizedString("onboarding.page2.step2", comment: "步骤2：添加新键盘")
static let onboardingPage2Step3 = NSLocalizedString("onboarding.page2.step3", comment: "步骤3：选择ClipStack")
static let onboardingPage2Step4 = NSLocalizedString("onboarding.page2.step4", comment: "步骤4：开启完全访问")
static let onboardingPage2Footnote = NSLocalizedString("onboarding.page2.footnote", comment: "隐私说明")

// 第3页：桌面小组件
static let onboardingPage3Title = NSLocalizedString("onboarding.page3.title", comment: "添加桌面小组件")
static let onboardingPage3Subtitle = NSLocalizedString("onboarding.page3.subtitle", comment: "一键查看和复制常用内容")
static let onboardingPage3Step1 = NSLocalizedString("onboarding.page3.step1", comment: "步骤1：长按主屏幕")
static let onboardingPage3Step2 = NSLocalizedString("onboarding.page3.step2", comment: "步骤2：点击+按钮")
static let onboardingPage3Step3 = NSLocalizedString("onboarding.page3.step3", comment: "步骤3：搜索ClipStack")
static let onboardingPage3Step4 = NSLocalizedString("onboarding.page3.step4", comment: "步骤4：拖动到桌面")
static let onboardingPage3Footnote = NSLocalizedString("onboarding.page3.footnote", comment: "支持三种尺寸")

// 日志
static let logOnboardingCompleted = NSLocalizedString("log.onboardingCompleted", comment: "引导流程已完成日志")

// MARK: - 付费墙页面（PaywallView.swift）

// 通用按钮
static let paywallTitle = NSLocalizedString("paywall.title", comment: "付费墙标题")
static let paywallAlertTitle = NSLocalizedString("paywall.alertTitle", comment: "购买结果弹窗标题")

// 头部区域
static let paywallHeaderTitle = NSLocalizedString("paywall.headerTitle", comment: "解锁全部功能")
static let paywallHeaderSubtitle = NSLocalizedString("paywall.headerSubtitle", comment: "无限制使用")

// 功能特性
static let paywallFeature1Title = NSLocalizedString("paywall.feature1.title", comment: "无限历史记录")
static let paywallFeature1Desc = NSLocalizedString("paywall.feature1.desc", comment: "保存任意数量")
static let paywallFeature2Title = NSLocalizedString("paywall.feature2.title", comment: "无限收藏")
static let paywallFeature2Desc = NSLocalizedString("paywall.feature2.desc", comment: "收藏不受限制")
static let paywallFeature3Title = NSLocalizedString("paywall.feature3.title", comment: "iCloud 同步")
static let paywallFeature3Desc = NSLocalizedString("paywall.feature3.desc", comment: "多设备自动同步")
static let paywallFeature4Title = NSLocalizedString("paywall.feature4.title", comment: "优先支持")
static let paywallFeature4Desc = NSLocalizedString("paywall.feature4.desc", comment: "新功能优先体验")

// 产品卡片
static let paywallProductMonthly = NSLocalizedString("paywall.product.monthly", comment: "月付订阅")
static let paywallProductYearly = NSLocalizedString("paywall.product.yearly", comment: "年付订阅")
static let paywallProductLifetime = NSLocalizedString("paywall.product.lifetime", comment: "终身买断")

static let paywallDescMonthly = NSLocalizedString("paywall.desc.monthly", comment: "按月支付，随时取消")
static let paywallDescYearly = NSLocalizedString("paywall.desc.yearly", comment: "相当于每月XX元")
static let paywallDescLifetime = NSLocalizedString("paywall.desc.lifetime", comment: "一次购买，永久使用")

static let paywallDiscountYearly = NSLocalizedString("paywall.discount.yearly", comment: "省33%")
static let paywallDiscountLifetime = NSLocalizedString("paywall.discount.lifetime", comment: "最划算")
static let paywallRecommended = NSLocalizedString("paywall.recommended", comment: "🔥 最受欢迎")

// 按钮
static let paywallLoadingProducts = NSLocalizedString("paywall.loadingProducts", comment: "加载套餐中...")
static let paywallVerifying = NSLocalizedString("paywall.verifying", comment: "验证中...")
static let paywallPurchaseNow = NSLocalizedString("paywall.purchaseNow", comment: "立即购买")
static let paywallRestore = NSLocalizedString("paywall.restore", comment: "恢复购买")
static let paywallReload = NSLocalizedString("paywall.reload", comment: "重新加载")

// 错误提示
static let paywallErrorTitle = NSLocalizedString("paywall.errorTitle", comment: "无法加载套餐")
static let paywallErrorMessage = NSLocalizedString("paywall.errorMessage", comment: "请检查网络连接后重试")

// 法律链接
static let paywallPrivacy = NSLocalizedString("paywall.privacy", comment: "隐私政策")
static let paywallTerms = NSLocalizedString("paywall.terms", comment: "服务条款")

// 购买结果消息
static let paywallSuccessMessage = NSLocalizedString("paywall.successMessage", comment: "购买成功消息")
static let paywallRestoredMessage = NSLocalizedString("paywall.restoredMessage", comment: "恢复购买成功消息")
static let paywallFailedMessage = NSLocalizedString("paywall.failedMessage", comment: "购买失败消息格式")

// MARK: - StoreHelper 日志

static let logStoreHelperInit = NSLocalizedString("log.storeHelperInit", comment: "StoreHelper初始化")
static let logProductsAlreadyLoaded = NSLocalizedString("log.productsAlreadyLoaded", comment: "产品已加载")
static let logLoadingProducts = NSLocalizedString("log.loadingProducts", comment: "开始加载产品列表")
static let logProductsLoadedSuccess = NSLocalizedString("log.productsLoadedSuccess", comment: "加载成功")
static let logProductsCount = NSLocalizedString("log.productsCount", comment: "产品数量")
static let logLoadProductsFailed = NSLocalizedString("log.loadProductsFailed", comment: "加载产品失败")

static let logStartPurchase = NSLocalizedString("log.startPurchase", comment: "开始购买")
static let logVerifyingPurchase = NSLocalizedString("log.verifyingPurchase", comment: "开始验证购买")
static let logPurchaseSuccess = NSLocalizedString("log.purchaseSuccess", comment: "购买成功")
static let logPurchaseCancelled = NSLocalizedString("log.purchaseCancelled", comment: "用户取消购买")
static let logPurchasePending = NSLocalizedString("log.purchasePending", comment: "购买等待确认")
static let logPurchaseUnknown = NSLocalizedString("log.purchaseUnknown", comment: "未知购买结果")
static let logPurchaseFailed = NSLocalizedString("log.purchaseFailed", comment: "购买失败")

static let logRestoreStart = NSLocalizedString("log.restoreStart", comment: "开始恢复购买")
static let logRestoreSuccess = NSLocalizedString("log.restoreSuccess", comment: "恢复购买成功")
static let logRestoreNoRecords = NSLocalizedString("log.restoreNoRecords", comment: "未找到有效购买记录")
static let logRestoreFailed = NSLocalizedString("log.restoreFailed", comment: "恢复失败格式")

static let logListeningTransactions = NSLocalizedString("log.listeningTransactions", comment: "开始监听事务更新")
static let logReceivedTransaction = NSLocalizedString("log.receivedTransaction", comment: "收到新事务")
static let logTransactionVerifyFailed = NSLocalizedString("log.transactionVerifyFailed", comment: "事务验证失败")

static let logUnlockPro = NSLocalizedString("log.unlockPro", comment: "解锁Pro")
static let logUnlockProSilent = NSLocalizedString("log.unlockProSilent", comment: "静默解锁Pro")
static let logCheckingSubscription = NSLocalizedString("log.checkingSubscription", comment: "检查订阅状态")

static let logCurrentStatusLifetime = NSLocalizedString("log.currentStatusLifetime", comment: "当前状态：终身买断")
static let logCurrentStatusYearly = NSLocalizedString("log.currentStatusYearly", comment: "当前状态：年付订阅")
static let logCurrentStatusMonthly = NSLocalizedString("log.currentStatusMonthly", comment: "当前状态：月付订阅")
static let logCurrentStatusNone = NSLocalizedString("log.currentStatusNone", comment: "当前状态：未订阅")
static let logExpiration = NSLocalizedString("log.expiration", comment: "到期")

static let logTransactionRevoked = NSLocalizedString("log.transactionRevoked", comment: "交易已撤销")
static let logSubscriptionExpired = NSLocalizedString("log.subscriptionExpired", comment: "订阅已过期")

static let logProductNotFound = NSLocalizedString("log.productNotFound", comment: "未找到选中的产品")
static let logPreparingPurchase = NSLocalizedString("log.preparingPurchase", comment: "准备购买")

// MARK: - ProManager 日志

static let logProManagerInit = NSLocalizedString("log.proManagerInit", comment: "ProManager初始化")
static let logCurrentStatus = NSLocalizedString("log.currentStatus", comment: "当前状态")
static let logProStatusUpdated = NSLocalizedString("log.proStatusUpdated", comment: "Pro状态已更新")
static let logStoreHelperUnavailable = NSLocalizedString("log.storeHelperUnavailable", comment: "StoreHelper不可用")
static let logStoreHelperAvailable = NSLocalizedString("log.storeHelperAvailable", comment: "StoreHelper可用")

// MARK: - 图片查看器（ImageViewer.swift）

static let imageViewerSource = NSLocalizedString("imageViewer.source", comment: "来源信息格式")

// MARK: - App 全局 HUD 消息（ClipStackApp.swift）

static let appItemNotFound = NSLocalizedString("app.itemNotFound", comment: "条目不存在")
static let appImageCopied = NSLocalizedString("app.imageCopied", comment: "图片已复制")
static let appImageLoadFailed = NSLocalizedString("app.imageLoadFailed", comment: "图片加载失败")
static let appCopied = NSLocalizedString("app.copied", comment: "已复制")
static let appContentEmpty = NSLocalizedString("app.contentEmpty", comment: "内容为空")
static let appLoadFailed = NSLocalizedString("app.loadFailed", comment: "加载失败")
    // 🔹 阶段 2 会添加键盘扩展专用 key
    // MARK: - 键盘扩展（KeyboardViewController + ClipItemKeyboardRow）

static let keyboardTitle = NSLocalizedString("keyboard.title", comment: "键盘-顶部标题")

// 筛选器
static let keyboardFilterAll = NSLocalizedString("keyboard.filter.all", comment: "键盘-筛选器选项（全部）")
static let keyboardFilterText = NSLocalizedString("keyboard.filter.text", comment: "键盘-筛选器选项（文本）")
static let keyboardFilterLink = NSLocalizedString("keyboard.filter.link", comment: "键盘-筛选器选项（链接）")
static let keyboardFilterImage = NSLocalizedString("keyboard.filter.image", comment: "键盘-筛选器选项（图片）")
static let keyboardFilterStarred = NSLocalizedString("keyboard.filter.starred", comment: "键盘-筛选器选项（收藏）")

// 空状态
static let keyboardEmptyAll = NSLocalizedString("keyboard.empty.all", comment: "键盘-空状态提示（全部）")
static let keyboardEmptyText = NSLocalizedString("keyboard.empty.text", comment: "键盘-空状态提示（文本）")
static let keyboardEmptyLink = NSLocalizedString("keyboard.empty.link", comment: "键盘-空状态提示（链接）")
static let keyboardEmptyImage = NSLocalizedString("keyboard.empty.image", comment: "键盘-空状态提示（图片）")
static let keyboardEmptyStarred = NSLocalizedString("keyboard.empty.starred", comment: "键盘-空状态提示（收藏）")

// 加载提示
static let keyboardLoadMore = NSLocalizedString("keyboard.loadMore", comment: "键盘-加载更多提示")

// 操作提示
static let keyboardActionInsert = NSLocalizedString("keyboard.action.insert", comment: "键盘-文本操作提示")
static let keyboardActionCopy = NSLocalizedString("keyboard.action.copy", comment: "键盘-图片操作提示")

// Toast消息
static let keyboardImageCopied = NSLocalizedString("keyboard.imageCopied", comment: "键盘-图片复制成功提示")
static let keyboardImageLoadFailed = NSLocalizedString("keyboard.imageLoadFailed", comment: "键盘-图片加载失败提示")

// 权限提示
static let keyboardPermissionTitle = NSLocalizedString("keyboard.permission.title", comment: "键盘-权限提示标题")
static let keyboardPermissionMessage = NSLocalizedString("keyboard.permission.message", comment: "键盘-权限提示内容")
static let keyboardPermissionGotIt = NSLocalizedString("keyboard.permission.gotIt", comment: "键盘-权限提示确认按钮")
    // 🔹 阶段 3 会添加分享扩展专用 key
    // MARK: - 分享扩展（ShareViewController.swift）

// 状态提示
static let shareSaving = NSLocalizedString("share.saving", comment: "Saving indicator")
static let shareSuccess = NSLocalizedString("share.success", comment: "Success message")

// 错误提示
static let shareErrorNoContent = NSLocalizedString("share.error.noContent", comment: "Failed to get shared content")
static let shareErrorUnsupportedType = NSLocalizedString("share.error.unsupportedType", comment: "Unsupported content type")
static let shareErrorReadTextFailed = NSLocalizedString("share.error.readTextFailed", comment: "Failed to read text")
static let shareErrorEmptyText = NSLocalizedString("share.error.emptyText", comment: "Text is empty")
static let shareErrorReadLinkFailed = NSLocalizedString("share.error.readLinkFailed", comment: "Failed to read link")
static let shareErrorEmptyLink = NSLocalizedString("share.error.emptyLink", comment: "Link is empty")
static let shareErrorReadImageFailed = NSLocalizedString("share.error.readImageFailed", comment: "Failed to read image")
static let shareErrorCompressFailed = NSLocalizedString("share.error.compressFailed", comment: "Image compression failed")
static let shareErrorThumbnailFailed = NSLocalizedString("share.error.thumbnailFailed", comment: "Thumbnail generation failed")
static let shareErrorSaveFailed = NSLocalizedString("share.error.saveFailed", comment: "Save failed: %@")

// 图片标签
static let shareImageLabel = NSLocalizedString("share.imageLabel", comment: "Image content label")

// 默认来源
static let shareDefaultSource = NSLocalizedString("share.defaultSource", comment: "Default share source name")
    // 🔹 阶段 4 会添加 Widget 专用 key
    // MARK: - Widget（ClipStackWidget.swift + WidgetDataProvider.swift）

// Widget 配置
static let widgetConfigName = NSLocalizedString("widget.config.name", comment: "Widget display name")
static let widgetConfigDescription = NSLocalizedString("widget.config.description", comment: "Widget description")

// Widget UI
static let widgetTitle = NSLocalizedString("widget.title", comment: "Widget title")
static let widgetRefresh = NSLocalizedString("widget.refresh", comment: "Refresh button")
static let widgetSeparator = NSLocalizedString("widget.separator", comment: "Separator between info")
static let widgetEmptyTitle = NSLocalizedString("widget.empty.title", comment: "Empty state title")
static let widgetEmptyMessage = NSLocalizedString("widget.empty.message", comment: "Empty state message")

// Widget 预览
static let widgetPlaceholderContent = NSLocalizedString("widget.placeholder.content", comment: "Placeholder sample text")
static let widgetPreviewText = NSLocalizedString("widget.preview.text", comment: "Preview sample text")
static let widgetPreviewPhotoSource = NSLocalizedString("widget.preview.photoSource", comment: "Preview photo source")
static let widgetPreviewSmall = NSLocalizedString("widget.preview.small", comment: "Small widget preview name")
static let widgetPreviewMedium = NSLocalizedString("widget.preview.medium", comment: "Medium widget preview name")
static let widgetPreviewLarge = NSLocalizedString("widget.preview.large", comment: "Large widget preview name")
}

// MARK: - 格式化工具（支持参数替换）

extension L10n {
    /// 格式化带参数的字符串
    /// 例如：L10n.format("item.count", 5) → "5 个条目"
    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        let format = NSLocalizedString(key, comment: "")
        return String(format: format, arguments: arguments)
    }
}

// MARK: - 格式化工具（扩展）

extension L10n {
    /// 筛选为空的提示（例如："暂无图片内容"）
    static func filterEmptyMessage(for filterName: String) -> String {
        String(format: NSLocalizedString("filter.empty", comment: ""), filterName)
    }
}
