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
            title: L10n.onboardingPage1Title,  // ✅ 本地化
            subtitle: L10n.onboardingPage1Subtitle,  // ✅ 本地化
            features: [
                L10n.onboardingPage1Feature1,  // ✅ 本地化
                L10n.onboardingPage1Feature2,  // ✅ 本地化
                L10n.onboardingPage1Feature3,  // ✅ 本地化
                L10n.onboardingPage1Feature4   // ✅ 本地化
            ]
        ),
        OnboardingPage(
            icon: "keyboard.fill",
            iconColor: .green,
            title: L10n.onboardingPage2Title,  // ✅ 本地化
            subtitle: L10n.onboardingPage2Subtitle,  // ✅ 本地化
            steps: [
                ("1", L10n.onboardingPage2Step1),  // ✅ 本地化
                ("2", L10n.onboardingPage2Step2),  // ✅ 本地化
                ("3", L10n.onboardingPage2Step3),  // ✅ 本地化
                ("4", L10n.onboardingPage2Step4)   // ✅ 本地化
            ],
            footnote: L10n.onboardingPage2Footnote  // ✅ 本地化
        ),
        OnboardingPage(
            icon: "square.grid.2x2.fill",
            iconColor: .orange,
            title: L10n.onboardingPage3Title,  // ✅ 本地化
            subtitle: L10n.onboardingPage3Subtitle,  // ✅ 本地化
            steps: [
                ("1", L10n.onboardingPage3Step1),  // ✅ 本地化
                ("2", L10n.onboardingPage3Step2),  // ✅ 本地化
                ("3", L10n.onboardingPage3Step3),  // ✅ 本地化
                ("4", L10n.onboardingPage3Step4)   // ✅ 本地化
            ],
            footnote: L10n.onboardingPage3Footnote  // ✅ 本地化
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
                        Button(L10n.onboardingSkip) {  // ✅ 本地化
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
                Text(currentPage < pages.count - 1 ? L10n.onboardingNext : L10n.onboardingStart)  // ✅ 本地化
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
        print("✅ \(L10n.logOnboardingCompleted)")  // ✅ 本地化
        
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
