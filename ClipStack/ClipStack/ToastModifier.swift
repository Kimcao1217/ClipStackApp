//
//  ToastModifier.swift
//  ClipStack
//
//  Toast 提示修饰符 - 让任何 View 都能显示 Toast
//

import SwiftUI

// MARK: - Toast 修饰符

struct ToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    let type: ToastType
    
    enum ToastType {
        case success, error, warning, info
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            case .warning: return .orange
            case .info: return .blue
            }
        }
    }
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isShowing {
                VStack {
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Image(systemName: type.icon)
                            .font(.title3)
                            .foregroundColor(type.color)
                        
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Color(.systemBackground)
                            .opacity(0.95)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    )
                    .cornerRadius(12)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 80)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isShowing)
                    .onAppear {
                        // 1.5 秒后自动消失
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                isShowing = false
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - View 扩展（便捷调用）

extension View {
    func toast(
        message: String,
        isShowing: Binding<Bool>,
        type: ToastModifier.ToastType = .info
    ) -> some View {
        self.modifier(ToastModifier(isShowing: isShowing, message: message, type: type))
    }
}
