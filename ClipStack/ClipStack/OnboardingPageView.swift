//
//  OnboardingPageView.swift
//  ClipStack
//
//  引导页单页视图 - 可复用组件
//

import SwiftUI

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // 顶部图标
            Image(systemName: page.icon)
                .font(.system(size: 80, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [page.iconColor, page.iconColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: page.iconColor.opacity(0.3), radius: 20, x: 0, y: 10)
                .padding(.bottom, 8)
            
            // 标题
            Text(page.title)
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // 副标题
            Text(page.subtitle)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
            
            // 内容区域
            if !page.features.isEmpty {
                // 功能列表（第1页）
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(page.features, id: \.self) { feature in
                        HStack(spacing: 12) {
                            Text(feature)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.horizontal, 40)
            } else if !page.steps.isEmpty {
                // 步骤列表（第2、3页）
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(page.steps, id: \.number) { step in
                        HStack(alignment: .top, spacing: 16) {
                            // 步骤数字
                            Text(step.number)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(page.iconColor)
                                .cornerRadius(18)
                            
                            // 步骤描述
                            Text(step.text)
                                .font(.body)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 40)
            }
            
            // 底部说明
            if let footnote = page.footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 16)
            }
            
            Spacer()
        }
    }
}

// MARK: - 预览

struct OnboardingPageView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingPageView(
            page: OnboardingPage(
                icon: "clipboard.fill",
                iconColor: .blue,
                title: L10n.onboardingPage1Title,  
                subtitle: L10n.onboardingPage1Subtitle,
                features: [
                    L10n.onboardingPage1Feature1,
                    L10n.onboardingPage1Feature2,
                    L10n.onboardingPage1Feature3,
                    L10n.onboardingPage1Feature4
                ]
            )
        )
    }
}
