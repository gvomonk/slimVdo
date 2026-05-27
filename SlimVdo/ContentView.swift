//
//  ContentView.swift
//  SlimVdo
//
//  Created by Raymond Holmes on 2026/5/21.
//

import SwiftUI

@available(iOS 16.0, *)
struct ContentView: View {
    @StateObject private var viewModel = CompressionViewModel()
    @StateObject private var photoViewModel = PhotoCompressionViewModel()
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    var body: some View {
        ZStack {
            // Background color base
            Color(isDarkMode ? Color(red: 0.05, green: 0.05, blue: 0.08) : Color(red: 0.96, green: 0.96, blue: 0.98))
                .ignoresSafeArea()
            
            // Dual Routing State Machine
            Group {
                if photoViewModel.state != .idle {
                    // 1. 照片硬件压缩路由分支
                    switch photoViewModel.state {
                    case .loadingAsset:
                        VStack(spacing: 24) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .scaleEffect(1.5)
                            
                            Text("正在提取拷贝原片像素元数据...")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Button(action: {
                                withAnimation {
                                    photoViewModel.cleanup()
                                }
                            }) {
                                Text("返回")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(12)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                        
                    case .configuring:
                        PhotoCompressionConfigView(viewModel: photoViewModel)
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        
                    case .processing:
                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .scaleEffect(1.5)
                            
                            Text("正在调用 GPU 硬件加速压制 HEIC...")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                        .onAppear {
                            UIApplication.shared.isIdleTimerDisabled = true
                        }
                        .onDisappear {
                            UIApplication.shared.isIdleTimerDisabled = false
                        }
                        
                    case .completed:
                        PhotoCompressionResultView(viewModel: photoViewModel)
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
                        
                    case .failed(let error):
                        ErrorView(error: error) {
                            withAnimation {
                                photoViewModel.cleanup()
                            }
                        }
                        .transition(.opacity)
                        
                    default:
                        EmptyView()
                    }
                } else if viewModel.state != .idle {
                    // 2. 视频硬件压缩路由分支
                    switch viewModel.state {
                    case .loadingAsset:
                        VStack(spacing: 24) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                                .scaleEffect(1.5)
                            
                            Text("正在安全提取并拷贝原片元数据...")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Button(action: {
                                withAnimation {
                                    viewModel.cleanup()
                                }
                            }) {
                                Text("返回")
                                    .font(.headline)
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(12)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                        
                    case .configuring:
                        CompressionConfigView(viewModel: viewModel)
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        
                    case .processing:
                        CompressionProgressView(viewModel: viewModel)
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        
                    case .completed:
                        CompressionResultView(viewModel: viewModel)
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
                        
                    case .failed(let error):
                        ErrorView(error: error) {
                            withAnimation {
                                viewModel.cleanup()
                            }
                        }
                        .transition(.opacity)
                        
                    default:
                        EmptyView()
                    }
                } else {
                    // 3. 极简科技感手机存储主屏
                    DashboardView(viewModel: viewModel, photoViewModel: photoViewModel)
                        .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.state)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: photoViewModel.state)
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

// MARK: - 共享重用大厂规范异常展示

struct ErrorView: View {
    let error: String
    var onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.12))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title)
                    .foregroundColor(.red)
            }
            
            VStack(spacing: 8) {
                Text("处理发生异常")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button(action: onDismiss) {
                Text("返回首页")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    if #available(iOS 16.0, *) {
        ContentView()
    } else {
        Text("Requires iOS 16.0+")
    }
}
