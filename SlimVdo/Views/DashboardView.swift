//
//  DashboardView.swift
//  SlimVdo
//
//  Created by Antigravity on 2026/5/25.
//

import SwiftUI
import PhotosUI

@available(iOS 16.0, *)
struct DashboardView: View {
    @ObservedObject var viewModel: CompressionViewModel
    @ObservedObject var photoViewModel: PhotoCompressionViewModel
    @StateObject private var storageAnalyzer = StorageAnalyzer.shared
    
    @State private var selectedVideos: [PhotosPickerItem] = []
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var animateBar = false
    
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    var body: some View {
        ZStack {
            // Dynamic Background based on mode
            Color(isDarkMode ? Color(red: 0.05, green: 0.05, blue: 0.08) : Color(red: 0.96, green: 0.96, blue: 0.98))
                .ignoresSafeArea()
            
            if isDarkMode {
                RadialGradient(
                    colors: [Color.purple.opacity(0.12), Color.clear],
                    center: .topLeading,
                    startRadius: 50,
                    endRadius: 300
                )
                .ignoresSafeArea()
                
                RadialGradient(
                    colors: [Color.blue.opacity(0.08), Color.clear],
                    center: .bottomTrailing,
                    startRadius: 100,
                    endRadius: 400
                )
                .ignoresSafeArea()
            } else {
                RadialGradient(
                    colors: [Color.purple.opacity(0.04), Color.clear],
                    center: .topLeading,
                    startRadius: 50,
                    endRadius: 350
                )
                .ignoresSafeArea()
            }
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 28) {
                    
                    // 1. Header (品牌与主题切换)
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SlimVdo")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: isDarkMode ? [.white, .purple.opacity(0.8)] : [.black, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        Spacer()
                        
                        HStack(spacing: 20) {
                            // Dark/Light Mode switch
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    isDarkMode.toggle()
                                }
                            }) {
                                Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                                    .font(.system(size: 26, weight: .medium))
                                    .foregroundColor(isDarkMode ? .orange : .purple)
                            }
                            
                            // Refresh button
                            Button(action: {
                                withAnimation {
                                    storageAnalyzer.refreshStorageInfo()
                                }
                            }) {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.system(size: 26, weight: .medium))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3))
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    // ==========================================
                    // 模块 1: 手机容量分析看板 (Storage Graph)
                    // ==========================================
                    VStack(alignment: .leading, spacing: 18) {
                        Text("存储空间")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.8))
                        
                        // 磁盘总体汇总
                        HStack(alignment: .bottom) {
                            Text(formatGBNumberOnly(storageAnalyzer.usedDiskSpace))
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(isDarkMode ? .white : .black)
                            Text(" / \(formatGBNumberOnly(storageAnalyzer.totalDiskSpace)) GB")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(formatBytes(storageAnalyzer.freeDiskSpace)) 可用")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.emeraldGreen)
                        }
                        
                        // 横向彩虹条进度条 (横向占比 Bar)
                        GeometryReader { geo in
                            HStack(spacing: 0) {
                                // 照片 (绿色段)
                                if storageAnalyzer.estimatedPhotosSize > 0 {
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.green.opacity(0.8), .emeraldGreen],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: animateBar ? CGFloat(Double(storageAnalyzer.estimatedPhotosSize) / Double(storageAnalyzer.totalDiskSpace)) * geo.size.width : 0)
                                }
                                
                                // 视频 (紫色段)
                                if storageAnalyzer.estimatedVideosSize > 0 {
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.purple, .indigo],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: animateBar ? CGFloat(Double(storageAnalyzer.estimatedVideosSize) / Double(storageAnalyzer.totalDiskSpace)) * geo.size.width : 0)
                                }
                                
                                // 其他应用 (蓝色段)
                                if storageAnalyzer.otherAppSpace > 0 {
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.blue.opacity(0.6), .cyan.opacity(0.6)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: animateBar ? CGFloat(Double(storageAnalyzer.otherAppSpace) / Double(storageAnalyzer.totalDiskSpace)) * geo.size.width : 0)
                                }
                                
                                // 剩余空间 (灰色打底填充)
                                Rectangle()
                                    .fill(isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.05))
                            }
                            .cornerRadius(8)
                            .shadow(color: .purple.opacity(0.1), radius: 4)
                        }
                        .frame(height: 16)
                        .onAppear {
                            withAnimation(.spring(response: 1.2, dampingFraction: 0.85, blendDuration: 0)) {
                                animateBar = true
                            }
                        }
                        
                        // Breakdown 分类徽章统计
                        VStack(spacing: 12) {
                            HStack(spacing: 16) {
                                // 照片指标
                                StorageIndicatorRow(
                                    color: .emeraldGreen,
                                    label: "照片",
                                    sizeStr: formatBytes(storageAnalyzer.estimatedPhotosSize),
                                    countStr: "\(storageAnalyzer.photoCount)",
                                    isDarkMode: isDarkMode
                                )
                                
                                // 视频指标
                                StorageIndicatorRow(
                                    color: .purple,
                                    label: "视频",
                                    sizeStr: formatBytes(storageAnalyzer.estimatedVideosSize),
                                    countStr: "\(storageAnalyzer.videoCount)",
                                    isDarkMode: isDarkMode
                                )
                            }
                            
                            HStack(spacing: 16) {
                                // 其他 App 指标
                                StorageIndicatorRow(
                                    color: .blue.opacity(0.6),
                                    label: "其他",
                                    sizeStr: formatBytes(storageAnalyzer.otherAppSpace),
                                    countStr: "",
                                    isDarkMode: isDarkMode
                                )
                                
                                // 剩余空间指标
                                StorageIndicatorRow(
                                    color: .white.opacity(0.2),
                                    label: "剩余",
                                    sizeStr: formatBytes(storageAnalyzer.freeDiskSpace),
                                    countStr: "",
                                    isDarkMode: isDarkMode
                                )
                            }
                        }
                    }
                    .padding(20)
                    .background(isDarkMode ? Color.white.opacity(0.02) : Color.black.opacity(0.02))
                    .cornerRadius(24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    
                    // ==========================================
                    // 模块 2: 罗列核心功能卡片网格 (Feature Cards Grid)
                    // ==========================================
                    VStack(alignment: .leading, spacing: 16) {
                        Text("媒体工具")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.8))
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            
                            // 卡片一：视频压缩
                            PhotosPicker(
                                selection: $selectedVideos,
                                maxSelectionCount: 20,
                                matching: .videos,
                                photoLibrary: .shared()
                            ) {
                                FeatureCard(
                                    title: "视频压缩",
                                    icon: "video.fill",
                                    gradient: LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    isDarkMode: isDarkMode
                                )
                            }
                            .onChange(of: selectedVideos, perform: { newItems in
                                guard !newItems.isEmpty else { return }
                                Task {
                                    await viewModel.selectVideos(photosPickerItems: newItems)
                                    selectedVideos = []
                                }
                            })
                            
                            // 卡片二：照片压缩
                            PhotosPicker(
                                selection: $selectedPhotos,
                                maxSelectionCount: 50,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                FeatureCard(
                                    title: "照片压缩",
                                    icon: "photo.fill",
                                    gradient: LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    isDarkMode: isDarkMode
                                )
                            }
                            .onChange(of: selectedPhotos, perform: { newItems in
                                guard !newItems.isEmpty else { return }
                                Task {
                                    await photoViewModel.selectPhotos(photosPickerItems: newItems)
                                    selectedPhotos = []
                                }
                            })
                            
                            // 卡片三：智能清理占位卡片 (磨砂 Coming Soon)
                            FeatureCard(
                                title: "智能清理",
                                icon: "wand.and.stars",
                                gradient: LinearGradient(colors: [Color.white.opacity(0.04), Color.white.opacity(0.02)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                isPlaceholder: true,
                                isDarkMode: isDarkMode
                            )
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 32)
                }
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func formatBytes(_ bytes: Int64) -> String {
        let doubleBytes = Double(bytes)
        if doubleBytes >= 1024 * 1024 * 1024 {
            return String(format: "%.1f GB", doubleBytes / (1024 * 1024 * 1024))
        } else if doubleBytes >= 1024 * 1024 {
            return String(format: "%.1f MB", doubleBytes / (1024 * 1024))
        } else if doubleBytes >= 1024 {
            return String(format: "%.1f KB", doubleBytes / 1024)
        } else {
            return "\(bytes) B"
        }
    }
    
    private func formatGBNumberOnly(_ bytes: Int64) -> String {
        let gb = Double(bytes) / (1024 * 1024 * 1024)
        return String(format: "%.1f", gb)
    }
}

// MARK: - 手机容量详情子行

struct StorageIndicatorRow: View {
    let color: Color
    let label: String
    let sizeStr: String
    let countStr: String
    var isDarkMode: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(label)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(isDarkMode ? .white : .black)
                    
                    if !countStr.isEmpty {
                        Text("(\(countStr))")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }
                
                Text(sizeStr)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(isDarkMode ? .white.opacity(0.95) : .black.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(isDarkMode ? Color.white.opacity(0.02) : Color.black.opacity(0.01))
        .cornerRadius(18)
    }
}

// MARK: - 功能入口卡片子组件

struct FeatureCard: View {
    let title: String
    let icon: String
    let gradient: LinearGradient
    var isPlaceholder: Bool = false
    var isDarkMode: Bool = true
    
    private var iconBgColor: Color {
        if isPlaceholder {
            return isDarkMode ? Color.white.opacity(0.04) : Color.black.opacity(0.03)
        } else {
            return .clear
        }
    }
    
    private var textColor: Color {
        if isPlaceholder {
            return isDarkMode ? Color.white.opacity(0.4) : Color.black.opacity(0.3)
        } else {
            return isDarkMode ? .white : .black
        }
    }
    
    private var borderColor: Color {
        if isPlaceholder {
            return isDarkMode ? Color.white.opacity(0.02) : Color.black.opacity(0.02)
        } else {
            return isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.05)
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // High-quality glowing circular icon container
            ZStack {
                if isPlaceholder {
                    Circle()
                        .fill(iconBgColor)
                        .frame(width: 56, height: 56)
                } else {
                    Circle()
                        .fill(gradient)
                        .frame(width: 56, height: 56)
                        .shadow(color: .purple.opacity(0.2), radius: 8)
                }
                
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(isPlaceholder ? .gray : .white)
            }
            
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(textColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(isDarkMode ? Color.white.opacity(0.02) : Color.black.opacity(0.01))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}
