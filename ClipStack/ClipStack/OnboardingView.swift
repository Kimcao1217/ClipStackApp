//
//  OnboardingView.swift
//  ClipStack
//
//  首次启动引导流程 - 完全模仿 iOS 原生风格
//

import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    
    // ✅ iOS 系统蓝（所有页面统一）
    private let systemBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "clipboard.fill",
            iconColor: Color(red: 0.0, green: 0.48, blue: 1.0),  // 蓝色
            title: L10n.onboardingPage1Title,
            subtitle: L10n.onboardingPage1Subtitle,
            features: [
                L10n.onboardingPage1Feature1,
                L10n.onboardingPage1Feature2,
                L10n.onboardingPage1Feature3,
                L10n.onboardingPage1Feature4
            ]
        ),
        OnboardingPage(
            icon: "keyboard.fill",
            iconColor: Color(red: 0.0, green: 0.48, blue: 1.0),  // ✅ 改为蓝色
            title: L10n.onboardingPage2Title,
            subtitle: L10n.onboardingPage2Subtitle,
            steps: [
                ("1", L10n.onboardingPage2Step1),
                ("2", L10n.onboardingPage2Step2),
                ("3", L10n.onboardingPage2Step3),
                ("4", L10n.onboardingPage2Step4)
            ],
            footnote: L10n.onboardingPage2Footnote
        ),
        OnboardingPage(
            icon: "square.grid.2x2.fill",
            iconColor: Color(red: 0.0, green: 0.48, blue: 1.0),  // ✅ 改为蓝色
            title: L10n.onboardingPage3Title,
            subtitle: L10n.onboardingPage3Subtitle,
            steps: [
                ("1", L10n.onboardingPage3Step1),
                ("2", L10n.onboardingPage3Step2),
                ("3", L10n.onboardingPage3Step3),
                ("4", L10n.onboardingPage3Step4)
            ],
            footnote: L10n.onboardingPage3Footnote
        )
    ]
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 跳过按钮
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button(L10n.onboardingSkip) {
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
        .interactiveDismissDisabled()
    }
    
    // MARK: - 底部按钮
    
    private var bottomButton: some View {
        Button {
            if currentPage < pages.count - 1 {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    currentPage += 1
                }
                
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            } else {
                completeOnboarding()
            }
        } label: {
            HStack {
                Text(currentPage < pages.count - 1 ? L10n.onboardingNext : L10n.onboardingStart)
                    .fontWeight(.semibold)
                
                Image(systemName: currentPage < pages.count - 1 ? "arrow.right" : "checkmark")
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .foregroundColor(.white)
            .background(systemBlue)  // ✅ 统一蓝色
            .cornerRadius(16)
            .shadow(color: systemBlue.opacity(0.3), radius: 10, x: 0, y: 5)
        }
    }
    
    // MARK: - 完成引导
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        print("✅ \(L10n.logOnboardingCompleted)")
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        dismiss()
    }
}

// MARK: - 数据模型

struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var features: [String] = []
    var steps: [(number: String, text: String)] = []
    var footnote: String? = nil
}

// MARK: - 预览

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            OnboardingView()
                .preferredColorScheme(.light)
            
            OnboardingView()
                .preferredColorScheme(.dark)
        }
    }
}
