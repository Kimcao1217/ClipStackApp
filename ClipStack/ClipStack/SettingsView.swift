//
//  SettingsView.swift
//  ClipStack
//
//  设置页面 - 显示账户信息、存储管理、版本信息
//

import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var proManager = ProManager.shared
    
    @State private var historyCount = 0
    @State private var starredCount = 0
    @State private var totalSize: Int64 = 0
    
    var body: some View {
        List {
            // MARK: - 账户信息区
            
            Section {
                HStack(spacing: 16) {
                    Image(systemName: proManager.isPro ? "crown.fill" : "person.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(proManager.isPro ? .yellow : .blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(proManager.isPro ? "Pro 版本" : "免费版本")
                            .font(.headline)
                        
                        if proManager.isPro {
                            Text("无限制，感谢支持！")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("历史 \(historyCount)/5 • 收藏 \(starredCount)/5")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
                
                if !proManager.isPro {
                    Button {
                        // 后续接入付费墙
                        print("🛒 打开付费墙")
                    } label: {
                        HStack {
                            Image(systemName: "star.fill")
                            Text("升级到 Pro 版")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                    }
                    .foregroundColor(.blue)
                }
            } header: {
                Text("账户")
            }
            
            // MARK: - 存储管理区
            
            Section {
                HStack {
                    Label("历史记录", systemImage: "clock")
                    Spacer()
                    Text("\(historyCount) 条")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label("收藏", systemImage: "star.fill")
                    Spacer()
                    Text("\(starredCount) 条")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label("占用空间", systemImage: "externaldrive")
                    Spacer()
                    Text(formatBytes(totalSize))
                        .foregroundColor(.secondary)
                }
                
                Button {
                    clearImageCache()
                } label: {
                    HStack {
                        Label("清理图片缓存", systemImage: "trash")
                        Spacer()
                    }
                }
                .foregroundColor(.red)
            } header: {
                Text("存储管理")
            } footer: {
                Text("清理图片缓存不会删除条目，只会释放图片占用的空间")
            }
            
            // MARK: - 其他设置区
            
            Section {
                Link(destination: URL(string: "https://github.com/yourusername/clipstack")!) {
                    HStack {
                        Label("使用帮助", systemImage: "questionmark.circle")
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button {
                    // 后续实现反馈功能
                    print("📧 打开反馈页面")
                } label: {
                    Label("意见反馈", systemImage: "envelope")
                }
                
                Link(destination: URL(string: "https://apps.apple.com/app/idXXXXXXXXXX?action=write-review")!) {
                    HStack {
                        Label("App Store 评分", systemImage: "star")
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("其他")
            }
            
            // MARK: - 关于区
            
            Section {
                HStack {
                    Text("版本")
                    Spacer()
                    Text(getAppVersion())
                        .foregroundColor(.secondary)
                }
                
                // ⚠️ 测试用：手动切换 Pro 状态（正式版删除）
                #if DEBUG
                Button {
                    proManager.setProStatus(!proManager.isPro)
                    loadData()  // 刷新数据
                } label: {
                    HStack {
                        Label("测试：切换 Pro 状态", systemImage: "ant")
                        Spacer()
                        Text(proManager.isPro ? "ON" : "OFF")
                            .foregroundColor(proManager.isPro ? .green : .red)
                    }
                }
                #endif
            } header: {
                Text("关于")
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadData()
        }
    }
    
    // MARK: - 数据加载
    
    private func loadData() {
        let historyRequest: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
        historyRequest.predicate = NSPredicate(format: "isStarred == %@", NSNumber(value: false))
        
        let starredRequest: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
        starredRequest.predicate = NSPredicate(format: "isStarred == %@", NSNumber(value: true))
        
        let allRequest: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
        
        do {
            historyCount = try viewContext.count(for: historyRequest)
            starredCount = try viewContext.count(for: starredRequest)
            
            let allItems = try viewContext.fetch(allRequest)
            totalSize = allItems.reduce(0) { $0 + ($1.thumbnailSize > 0 ? $1.thumbnailSize : 0) }
            
            print("📊 设置页面数据：历史 \(historyCount)，收藏 \(starredCount)，占用 \(formatBytes(totalSize))")
        } catch {
            print("❌ 加载设置数据失败: \(error)")
        }
    }
    
    // MARK: - 工具方法
    
    private func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(bytes) / 1024.0 / 1024.0)
        }
    }
    
    private func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    private func clearImageCache() {
        let request: NSFetchRequest<ClipItem> = ClipItem.fetchRequest()
        request.predicate = NSPredicate(format: "imageData != nil")
        
        do {
            let items = try viewContext.fetch(request)
            var clearedSize: Int64 = 0
            
            for item in items {
                clearedSize += item.thumbnailSize
                item.imageData = nil  // 清空图片数据
            }
            
            try viewContext.save()
            
            print("✅ 已清理图片缓存：释放 \(formatBytes(clearedSize))")
            
            // 刷新数据
            loadData()
            
            // 显示提示
            showAlert(title: "清理完成", message: "已释放 \(formatBytes(clearedSize)) 空间")
        } catch {
            print("❌ 清理图片缓存失败: \(error)")
            showAlert(title: "清理失败", message: error.localizedDescription)
        }
    }
    
    private func showAlert(title: String, message: String) {
        // 简单实现：使用系统 Alert
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootVC = window.rootViewController else {
                return
            }
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "好的", style: .default))
            rootVC.present(alert, animated: true)
        }
    }
}

// MARK: - 预览

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
}
