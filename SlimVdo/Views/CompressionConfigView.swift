//
//  CompressionConfigView.swift
//  SlimVdo
//
//  Created by Antigravity on 2026/5/25.
//

import SwiftUI

@available(iOS 16.0, *)
struct CompressionConfigView: View {
    @ObservedObject var viewModel: CompressionViewModel
    
    // 自定义折叠面板展开状态
    @State private var isCustomSettingsExpanded = false
    
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
                    Text("视频压缩")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    // Spacer balancing
                    Button(action: {}) {
                        Text("返回")
                            .opacity(0.0)
                    }
                }
                .padding()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // 2. Video Source Information Card (源视频属性详情)
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.purple)
                                Text("视频属性")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                            
                            VStack(spacing: 10) {
                                InfoRow(label: "文件名", value: viewModel.videoTitle)
                                InfoRow(label: "文件大小", value: formatBytes(viewModel.originalSize))
                                if viewModel.originalURLs.count == 1 {
                                    InfoRow(label: "视频时长", value: formatDuration(viewModel.duration))
                                    InfoRow(label: "物理分辨率", value: "\(Int(viewModel.width)) × \(Int(viewModel.height))")
                                    InfoRow(label: "原始编码/帧率", value: "\(viewModel.codecUsed) / \(Int(viewModel.fps)) FPS")
                                }
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
                        
                        // 3. Preset Quick Select cards
                        VStack(alignment: .leading, spacing: 12) {
                            Text("压缩预设")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            HStack(spacing: 12) {
                                ForEach([CompressionPreset.extreme, .standard, .high], id: \.self) { p in
                                    Button(action: {
                                        withAnimation {
                                            viewModel.settings = CompressionSettings.settings(for: p)
                                            isCustomSettingsExpanded = false
                                        }
                                    }) {
                                        VStack(spacing: 8) {
                                            Image(systemName: p.iconName)
                                                .font(.title2)
                                                .foregroundColor(viewModel.settings.preset == p ? .white : .purple.opacity(0.7))
                                            
                                            Text(p.displayName)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(viewModel.settings.preset == p ? .white : .white.opacity(0.7))
                                            
                                            Text(getPresetDescriptionSnippet(p))
                                                .font(.system(size: 10))
                                                .foregroundColor(.gray)
                                                .multilineTextAlignment(.center)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .padding(.horizontal, 8)
                                        .background(viewModel.settings.preset == p ? Color.purple.opacity(0.3) : Color.white.opacity(0.02))
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(viewModel.settings.preset == p ? Color.purple : Color.white.opacity(0.05), lineWidth: 1.5)
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            // Custom trigger card
                            Button(action: {
                                withAnimation {
                                    isCustomSettingsExpanded.toggle()
                                    if isCustomSettingsExpanded {
                                        viewModel.settings.preset = .custom
                                    } else {
                                        viewModel.settings = CompressionSettings.settings(for: .standard)
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "slider.horizontal.3")
                                    Text("自定义")
                                        .fontWeight(.bold)
                                    Spacer()
                                    Image(systemName: isCustomSettingsExpanded ? "chevron.up" : "chevron.down")
                                }
                                .padding()
                                .foregroundColor(.white)
                                .background(viewModel.settings.preset == .custom ? Color.purple.opacity(0.2) : Color.white.opacity(0.02))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(viewModel.settings.preset == .custom ? Color.purple : Color.white.opacity(0.05), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal)
                        }
                        
                        // 4. Custom Parameter Drawers
                        if isCustomSettingsExpanded || viewModel.settings.preset == .custom {
                            VStack(spacing: 20) {
                                // A. 编码器选择
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("编码格式")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    Picker("编码格式", selection: $viewModel.settings.codec) {
                                        Text("HEVC").tag(VideoCodec.hevc)
                                        Text("H.264").tag(VideoCodec.h264)
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
                                            .foregroundColor(.purple)
                                    }
                                    
                                    Slider(value: $viewModel.settings.resolutionScale, in: 0.1...1.0, step: 0.05)
                                        .tint(.purple)
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.08))
                                
                                // C. 比特率滑动条 (码率系数)
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text("码率")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Spacer()
                                        Text(String(format: "%.1fx 码率", viewModel.settings.customVideoBitrateMultiplier))
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.purple)
                                    }
                                    
                                    Slider(value: $viewModel.settings.customVideoBitrateMultiplier, in: 0.2...2.0, step: 0.05)
                                        .tint(.purple)
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.08))
                                
                                // D. 帧率选择器
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text("帧率")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Spacer()
                                        Text(viewModel.settings.frameRate == 0 ? "原画 \(Int(viewModel.fps)) FPS" : "\(viewModel.settings.frameRate) FPS")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.purple)
                                    }
                                    
                                    Picker("目标帧率", selection: $viewModel.settings.frameRate) {
                                        Text("保持原样").tag(0)
                                        Text("60 FPS").tag(60)
                                        Text("30 FPS").tag(30)
                                        Text("24 FPS").tag(24)
                                    }
                                    .pickerStyle(.segmented)
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.08))
                                
                                // E. 音频开关及比特率
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("压缩音频")
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $viewModel.settings.compressAudio)
                                        .tint(.purple)
                                }
                                
                                if viewModel.settings.compressAudio {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Text("音频采样码率")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Spacer()
                                            Text("\(Int(viewModel.settings.audioBitrate / 1000)) Kbps")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.purple)
                                        }
                                        
                                        Picker("音频码率", selection: $viewModel.settings.audioBitrate) {
                                            Text("192K").tag(192_000.0)
                                            Text("128K").tag(128_000.0)
                                            Text("64K").tag(64_000.0)
                                        }
                                        .pickerStyle(.segmented)
                                    }
                                    .transition(.opacity)
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
                        }
                    }
                    .padding(.bottom, 24)
                }
                
                // 5. Dynamic Predictive Storage Saver Bar & Launch Footer (动感预测栏 + 提交按钮)
                VStack(spacing: 16) {
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    // 预测结果比对栏
                    HStack(alignment: .center) {
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
                        
                        // 预估省空间比率 Badge
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
                    
                    // "开始压缩" 炫酷霓虹按钮
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
                                    colors: [.purple, .indigo, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
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
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func getPresetDescriptionSnippet(_ preset: CompressionPreset) -> String {
        switch preset {
        case .extreme: return "极速减小 80%"
        case .standard: return "平衡压缩 70%"
        case .high: return "高画质压缩 40%"
        case .custom: return ""
        }
    }
}

// MARK: - 信息单行子组件

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.footnote)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
