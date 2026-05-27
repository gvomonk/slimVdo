//
//  PhotoCompressionConfigView.swift
//  SlimVdo
//
//  Created by Antigravity on 2026/5/25.
//

import SwiftUI

@available(iOS 16.0, *)
struct PhotoCompressionConfigView: View {
    @ObservedObject var viewModel: PhotoCompressionViewModel
    
    @State private var isCustomExpanded = false
    @State private var showMetadataTooltip = false
    
    var body: some View {
        ZStack {
            // Dark Background
            Color(red: 0.05, green: 0.05, blue: 0.08)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // 1. Navigation Header
                HStack {
                    Button(action: {
                        withAnimation {
                            viewModel.cleanup()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("返回")
                        }
                        .foregroundColor(.blue)
                    }
                    Spacer()
                    Text("照片压缩")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: {}) {
                        Text("返回")
                            .opacity(0.0)
                    }
                }
                .padding()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        
                        // 2. Thumbnail & Meta Info Card
                        VStack(spacing: 16) {
                            // Local Thumbnail Preview
                            if viewModel.originalURLs.count == 1,
                               let origURL = viewModel.originalURL,
                               let uiImage = UIImage(contentsOfFile: origURL.path) {
                                Color.clear
                                    .frame(height: 180)
                                    .overlay(
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    )
                                    .clipped()
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                                    .shadow(radius: 6)
                            }
                            
                            // Info list
                            if viewModel.originalURLs.count == 1 {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    InfoRow(label: "相片名", value: viewModel.cleanPhotoTitle)
                                    InfoRow(label: "文件大小", value: formatBytes(viewModel.originalSize))
                                    InfoRow(label: "物理尺寸", value: "\(Int(viewModel.width)) × \(Int(viewModel.height))")
                                    InfoRow(label: "原始格式", value: viewModel.codecUsed)
                                }
                            } else {
                                InfoRow(label: "相片数", value: "\(viewModel.originalURLs.count) 张")
                                InfoRow(label: "总大小", value: formatBytes(viewModel.originalSize))
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.02))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        
                        // 3. 预设按钮行 — 一行 5 个百分比胶囊
                        VStack(alignment: .leading, spacing: 12) {
                            Text("快速压缩:")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach([PhotoCompressionPreset.p85, .p70, .p50, .p30, .p15], id: \.id) { preset in
                                        Button(action: {
                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                                let newSettings = PhotoCompressionSettings.settings(for: preset)
                                                viewModel.settings = newSettings
                                            }
                                        }) {
                                            Text(preset.displayName)
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundColor(viewModel.settings.preset == preset ? .white : .gray)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(
                                                    viewModel.settings.preset == preset
                                                    ? AnyShapeStyle(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                                                    : AnyShapeStyle(Color.white.opacity(0.04))
                                                )
                                                .cornerRadius(20)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 20)
                                                        .stroke(viewModel.settings.preset == preset ? Color.clear : Color.white.opacity(0.06), lineWidth: 1)
                                                )
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // 4. 自定义参数（折叠下拉菜单）
                        VStack(spacing: 0) {
                            // 折叠按钮头
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    isCustomExpanded.toggle()
                                }
                            }) {
                                HStack {
                                    Text("自定义参数")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: isCustomExpanded ? "chevron.up" : "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding(16)
                            }
                            
                            if isCustomExpanded {
                                VStack(spacing: 14) {
                                    // A. 输出格式
                                    HStack {
                                        Text("输出格式")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Spacer()
                                        Picker("格式", selection: photoSettingsBindingAutoCustom(\.format)) {
                                            Text("HEIC").tag(PhotoFormat.heic)
                                            Text("JPEG").tag(PhotoFormat.jpeg)
                                        }
                                        .pickerStyle(.segmented)
                                        .frame(width: 180)
                                    }
                                    
                                    // B. 分辨率滑动条
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text("分辨率")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Spacer()
                                            Text("(\(Int(viewModel.width * viewModel.settings.resolutionScale))x\(Int(viewModel.height * viewModel.settings.resolutionScale))) \(Int(viewModel.settings.resolutionScale * 100))%")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.blue)
                                        }
                                        
                                        Slider(value: photoSettingsBindingAutoCustom(\.resolutionScale), in: 0.1...1.0, step: 0.05)
                                            .tint(.blue)
                                    }
                                    
                                    // C. 压缩质量滑动条
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text("压缩质量")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Spacer()
                                            Text("\(Int(viewModel.settings.compressionQuality * 100))%")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.blue)
                                        }
                                        
                                        Slider(value: photoSettingsBindingAutoCustom(\.compressionQuality), in: 0.1...1.0, step: 0.05)
                                            .tint(.blue)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .background(Color.white.opacity(0.02))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        
                        // 5. 保留元数据（单列独立行 + info tooltip）
                        MetadataToggleRow(keepMetadata: $viewModel.settings.keepMetadata, showTooltip: $showMetadataTooltip, tintColor: .blue)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 24)
                }
                
                // 6. Predictive Savings & Trigger Footer
                VStack(spacing: 16) {
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("预估体积变化")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            HStack(spacing: 8) {
                                Text(formatBytes(viewModel.originalSize))
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .strikethrough()
                                
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Text(formatBytes(viewModel.estimatedSize))
                                    .font(.title3)
                                    .fontWeight(.black)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Spacer()
                        
                        Text(String(format: "省 %.0f%%", viewModel.estimatedSavingsRatio * 100))
                            .font(.headline)
                            .fontWeight(.black)
                            .foregroundColor(.emeraldGreen)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.emeraldGreen.opacity(0.12))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        Task {
                            await viewModel.startCompression()
                        }
                    }) {
                        Text("开始压缩")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .indigo, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .background(Color(red: 0.04, green: 0.04, blue: 0.06))
            }
        }
    }
    
    // MARK: - 自动切换为自定义预设的 Binding 工厂
    
    private func photoSettingsBindingAutoCustom<T: Equatable>(_ keyPath: WritableKeyPath<PhotoCompressionSettings, T>) -> Binding<T> {
        Binding<T>(
            get: { viewModel.settings[keyPath: keyPath] },
            set: { newValue in
                viewModel.settings[keyPath: keyPath] = newValue
                viewModel.settings.preset = .custom
            }
        )
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
}
