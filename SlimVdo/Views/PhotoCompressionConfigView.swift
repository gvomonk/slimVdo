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
                        .foregroundColor(.purple)
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
                    VStack(spacing: 24) {
                        
                        // 2. Thumbnail & Meta Info Card
                        VStack(spacing: 16) {
                            // Local Thumbnail Preview
                            if viewModel.originalURLs.count == 1,
                               let origURL = viewModel.originalURL,
                               let uiImage = UIImage(contentsOfFile: origURL.path) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 180)
                                    .clipped()
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                                    .shadow(radius: 6)
                            }
                            
                            // Info list
                            VStack(spacing: 10) {
                                InfoRow(label: "相片名", value: viewModel.photoTitle)
                                InfoRow(label: "文件大小", value: formatBytes(viewModel.originalSize))
                                if viewModel.originalURLs.count == 1 {
                                    InfoRow(label: "物理尺寸", value: "\(Int(viewModel.width)) × \(Int(viewModel.height))")
                                    InfoRow(label: "原始格式", value: viewModel.codecUsed)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.02))
                        .cornerRadius(24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        
                        // 3. Quick Presets Card Grid
                        VStack(alignment: .leading, spacing: 12) {
                            Text("压缩预设")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            HStack(spacing: 12) {
                                ForEach([PhotoCompressionPreset.extreme, .standard, .high], id: \.self) { p in
                                    Button(action: {
                                        withAnimation {
                                            viewModel.settings = PhotoCompressionSettings.settings(for: p)
                                            isCustomExpanded = false
                                        }
                                    }) {
                                        VStack(spacing: 8) {
                                            Image(systemName: p.iconName)
                                                .font(.title3)
                                                .foregroundColor(viewModel.settings.preset == p ? .white : .blue.opacity(0.7))
                                            
                                            Text(p.displayName)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(viewModel.settings.preset == p ? .white : .white.opacity(0.7))
                                            
                                            Text(getPresetSnippet(p))
                                                .font(.system(size: 9))
                                                .foregroundColor(.gray)
                                                .multilineTextAlignment(.center)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .padding(.horizontal, 6)
                                        .background(viewModel.settings.preset == p ? Color.blue.opacity(0.3) : Color.white.opacity(0.02))
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(viewModel.settings.preset == p ? Color.blue : Color.white.opacity(0.05), lineWidth: 1.5)
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            // Custom settings drawer trigger
                            Button(action: {
                                withAnimation {
                                    isCustomExpanded.toggle()
                                    if isCustomExpanded {
                                        viewModel.settings.preset = .custom
                                    } else {
                                        viewModel.settings = PhotoCompressionSettings.settings(for: .standard)
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "slider.horizontal.3")
                                    Text("自定义")
                                        .fontWeight(.bold)
                                    Spacer()
                                    Image(systemName: isCustomExpanded ? "chevron.up" : "chevron.down")
                                }
                                .padding()
                                .foregroundColor(.white)
                                .background(viewModel.settings.preset == .custom ? Color.blue.opacity(0.2) : Color.white.opacity(0.02))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(viewModel.settings.preset == .custom ? Color.blue : Color.white.opacity(0.05), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal)
                        }
                        
                        // 4. Custom Parameter Sliders Drawer
                        if isCustomExpanded || viewModel.settings.preset == .custom {
                            VStack(spacing: 20) {
                                // A. 格式选择
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("输出格式")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    Picker("格式", selection: $viewModel.settings.format) {
                                        Text("HEIC").tag(PhotoFormat.heic)
                                        Text("JPEG").tag(PhotoFormat.jpeg)
                                    }
                                    .pickerStyle(.segmented)
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.08))
                                
                                // B. 分辨率滑动条
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text("分辨率")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Spacer()
                                        Text("\(Int(viewModel.settings.resolutionScale * 100))% (\(Int(viewModel.width * viewModel.settings.resolutionScale))x\(Int(viewModel.height * viewModel.settings.resolutionScale)))")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                    }
                                    
                                    Slider(value: $viewModel.settings.resolutionScale, in: 0.1...1.0, step: 0.05)
                                        .tint(.blue)
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.08))
                                
                                // C. 质量因子滑动条
                                VStack(alignment: .leading, spacing: 10) {
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
                                    
                                    Slider(value: $viewModel.settings.compressionQuality, in: 0.1...1.0, step: 0.05)
                                        .tint(.blue)
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.08))
                                
                                // D. 元数据保留开关
                                Toggle(isOn: $viewModel.settings.keepMetadata) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("保留元数据")
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                    }
                                }
                                .tint(.blue)
                            }
                            .padding(16)
                            .background(Color.white.opacity(0.02))
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            )
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 24)
                }
                
                // 5. Predictive Savings & Trigger Footer
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
                    
                    // "开始硬件压缩" 蓝色高保真按钮
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
    
    private func getPresetSnippet(_ preset: PhotoCompressionPreset) -> String {
        switch preset {
        case .extreme: return "极速减小 75%"
        case .standard: return "完美平衡 60%"
        case .high: return "高保真减小 30%"
        case .custom: return ""
        }
    }
}
