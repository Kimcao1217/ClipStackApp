//
//  OnboardingPageView.swift
//  ClipStack
//
//  引导页单页视图 - iOS 原生风格（统一蓝色）
//

import SwiftUI

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // ✅ 统一图标高度（用 frame 而不是 font size）
            Image(systemName: page.icon)
                .font(.system(size: 100, weight: .thin))
                .foregroundStyle(page.iconColor)
                .padding(.bottom, 20)
            
            // 标题
            Text(page.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 32)
            
            // 副标题
            Text(page.subtitle)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            // 内容区域
            if !page.features.isEmpty {
                // ✅ 功能列表（第1页）- 统一灰色圆点
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(page.features.enumerated()), id: \.offset) { index, feature in
                        HStack(alignment: .top, spacing: 12) {
                            // ✅ 改为灰色圆点（不抢镜）
                            Circle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 6, height: 6)
                                .padding(.top, 7)
                            
                            Text(removeEmoji(from: feature))
                                .font(.body)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 50)
                
            } else if !page.steps.isEmpty {
                // ✅ 步骤列表（第2、3页）- 统一蓝色数字
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(page.steps, id: \.number) { step in
                        HStack(alignment: .top, spacing: 16) {
                            // 步骤数字（统一蓝色）
                            Text(step.number)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(page.iconColor)  // ✅ 统一蓝色
                                .cornerRadius(16)
                            
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
            
            // ✅ 底部说明（左对齐 + 锁图标）
            if let footnote = page.footnote {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                    
                    Text(footnote)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
            }
            
            Spacer()
        }
    }
    
    // ✅ 辅助函数：移除字符串开头的 Emoji
    private func removeEmoji(from text: String) -> String {
        let pattern = "^[\\p{Emoji}\\s]+"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(text.startIndex..., in: text)
            return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        }
        return text
    }
}

// MARK: - 预览

struct OnboardingPageView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            OnboardingPageView(
                page: OnboardingPage(
                    icon: "clipboard.fill",
                    iconColor: Color(red: 0.0, green: 0.48, blue: 1.0),
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
            .preferredColorScheme(.light)
            
            OnboardingPageView(
                page: OnboardingPage(
                    icon: "keyboard.fill",
                    iconColor: Color(red: 0.0, green: 0.48, blue: 1.0),
                    title: L10n.onboardingPage2Title,
                    subtitle: L10n.onboardingPage2Subtitle,
                    steps: [
                        ("1", L10n.onboardingPage2Step1),
                        ("2", L10n.onboardingPage2Step2)
                    ],
                    footnote: L10n.onboardingPage2Footnote
                )
            )
            .preferredColorScheme(.dark)
        }
    }
}
