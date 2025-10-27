//
//  DarwinNotificationCenter.swift
//  ClipStack
//
//  Darwin Notification 跨进程通知工具（Apple 原生 API）
//

import Foundation

/// Darwin Notification 通知名称
extension Notification.Name {
    static let clipStackDataChanged = Notification.Name("com.kimcao.clipstack.dataChanged")
}

/// Darwin Notification 中心（用于 App Group 跨进程通知）
class DarwinNotificationCenter {
    
    static let shared = DarwinNotificationCenter()
    
    private let notificationName = "com.kimcao.clipstack.dataChanged"
    
    // ✅ 用于存储回调闭包（避免 C 函数指针捕获上下文）
    private var callback: (() -> Void)?
    
    private init() {}
    
    /// 发送跨进程通知（Share Extension 调用）
    func postNotification() {
        let name = CFNotificationName(rawValue: notificationName as CFString)
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, name, nil, nil, true)
        print("📤 已发送 Darwin 通知: \(notificationName)")
    }
    
    /// 监听跨进程通知（主 App 调用）
    func addObserver(callback: @escaping () -> Void) {
        self.callback = callback
        
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        let name = CFNotificationName(rawValue: notificationName as CFString)
        
        CFNotificationCenterAddObserver(
            center,
            observer,
            { (center, observer, name, object, userInfo) in
                // ✅ 从 observer 恢复 self
                guard let observer = observer else { return }
                let mySelf = Unmanaged<DarwinNotificationCenter>.fromOpaque(observer).takeUnretainedValue()
                
                print("📥 收到 Darwin 通知: \(String(describing: name))")
                
                // 在主线程执行回调
                DispatchQueue.main.async {
                    mySelf.callback?()
                }
            },
            notificationName as CFString,
            nil,
            .deliverImmediately
        )
        
        print("👂 已开始监听 Darwin 通知: \(notificationName)")
    }
    
    deinit {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterRemoveEveryObserver(center, observer)
    }
}
