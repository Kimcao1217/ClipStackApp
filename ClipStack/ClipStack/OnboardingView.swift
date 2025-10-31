//
//  OnboardingView.swift
//  ClipStack
//
//  首次启动引导流程 - 3页滑动式引导
//

import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "clipboard.fill",
            iconColor: .blue,
            title: "欢迎使用 ClipStack",
            subtitle: "强大的剪贴板历史管理工具",
            features: [
                "📝 自动保存剪贴板历史",
                "🔗 支持文本、链接和图片",
                "⭐ 收藏常用内容",
                "☁️ iCloud 跨设备同步（即将推出）"
            ]
        ),
        OnboardingPage(
            icon: "keyboard.fill",
            iconColor: .green,
            title: "添加自定义键盘",
            subtitle: "在任何 App 中快速插入历史内容",
            steps: [
                ("1", "打开系统设置 → 通用 → 键盘"),
                ("2", "点击\"键盘\"→\"添加新键盘\""),
                ("3", "选择\"ClipStack\"并开启"),
                ("4", "⚠️ 开启\"允许完全访问\"（需要此权限才能复制图片）")
            ],
            footnote: "我们不会收集你的键入内容，所有数据仅保存在本地"
        ),
        OnboardingPage(
            icon: "square.grid.2x2.fill",
            iconColor: .orange,
            title: "添加桌面小组件",
            subtitle: "一键查看和复制常用内容",
            steps: [
                ("1", "长按主屏幕空白处进入编辑模式"),
                ("2", "点击左上角的 ＋ 按钮"),
                ("3", "搜索\"ClipStack\"并选择"),
                ("4", "拖动到桌面并完成添加")
            ],
            footnote: "支持小、中、大三种尺寸"
        )
    ]
    
    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                colors: [
                    pages[currentPage].iconColor.opacity(0.1),
                    pages[currentPage].iconColor.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.3), value: currentPage)
            
            VStack(spacing: 0) {
                // 跳过按钮
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("跳过") {
                            completeOnboarding()
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                    }
                }
                
                // 页面内容
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                // 底部按钮
                bottomButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .interactiveDismissDisabled()  // 禁止下拉关闭
    }
    
    // MARK: - 底部按钮
    
    private var bottomButton: some View {
        Button {
            if currentPage < pages.count - 1 {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    currentPage += 1
                }
                
                // 触觉反馈
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            } else {
                completeOnboarding()
            }
        } label: {
            HStack {
                Text(currentPage < pages.count - 1 ? "下一步" : "开始使用")
                    .fontWeight(.semibold)
                
                Image(systemName: currentPage < pages.count - 1 ? "arrow.right" : "checkmark")
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .foregroundColor(.white)
            .background(pages[currentPage].iconColor)
            .cornerRadius(16)
            .shadow(color: pages[currentPage].iconColor.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .animation(.easeInOut(duration: 0.3), value: currentPage)
    }
    
    // MARK: - 完成引导
    
    private func completeOnboarding() {
    // ⭐ 标记已完成引导
    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    print("✅ 引导流程已完成，下次启动不再显示")
    
    // 触觉反馈
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)
    
    // ⭐ 关键：关闭引导页（现在会正常工作了）
    dismiss()
}
}

// MARK: - 数据模型

struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var features: [String] = []  // 功能列表（第1页用）
    var steps: [(number: String, text: String)] = []  // 步骤列表（第2、3页用）
    var footnote: String? = nil  // 底部说明文字
}

// MARK: - 预览

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
