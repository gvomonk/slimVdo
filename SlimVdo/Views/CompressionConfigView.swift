//
//  CompressionConfigView.swift
//  SlimVdo
//
//  Created by Antigravity on 2026/5/25.
//

import SwiftUI
import AVFoundation

@available(iOS 16.0, *)
struct CompressionConfigView: View {
    @ObservedObject var viewModel: CompressionViewModel
    
    @State private var videoThumbnail: UIImage? = nil
    @State private var isCustomExpanded = false
    // 刻度点 tooltip 状态
    @State private var tooltipText: String? = nil
    @State private var tooltipDotId: String? = nil
    // 保留元数据 tooltip
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
                    VStack(spacing: 20) {
                        
                        // 2. Video Source Information Card — 双列元数据展示
                        VStack(spacing: 12) {
                            // Local Video Thumbnail Preview
                            if viewModel.originalURLs.count == 1,
                               viewModel.originalURL != nil,
                               let uiImage = videoThumbnail {
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
                            
                            // 两列元数据网格
                            if viewModel.originalURLs.count == 1 {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    InfoRow(label: "文件名", value: viewModel.videoTitle)
                                    InfoRow(label: "时长", value: formatDuration(viewModel.duration))
                                    InfoRow(label: "大小", value: formatBytes(viewModel.originalSize))
                                    InfoRow(label: "分辨率", value: "\(Int(viewModel.width))×\(Int(viewModel.height))")
                                    InfoRow(label: "编码", value: "\(viewModel.codecUsed)")
                                    InfoRow(label: "帧率", value: "\(Int(viewModel.fps)) FPS")
                                    InfoRow(label: "码率", value: String(format: "%.1f Mbps", viewModel.originalBitrate / 1_000_000.0))
                                }
                            } else {
                                InfoRow(label: "文件", value: viewModel.videoTitle)
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
                            Text("快速压缩至原图的:")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            HStack(spacing: 8) {
                                ForEach([CompressionPreset.p85, .p70, .p50, .p30, .p15], id: \.id) { preset in
                                    Button(action: {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            let newSettings = CompressionSettings.settings(for: preset)
                                            viewModel.settings = newSettings
                                            // 设置默认的输出格式为原文件的
                                            viewModel.settings.outputFormat = viewModel.originalContainerFormat
                                            viewModel.settings.codec = viewModel.originalCodec
                                        }
                                    }) {
                                        Text(preset.displayName)
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(viewModel.settings.preset == preset ? .white : .gray)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(
                                                viewModel.settings.preset == preset
                                                ? AnyShapeStyle(LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
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
                        
                        // 4. 自定义参数（折叠下拉菜单）
                        VStack(spacing: 0) {
                            // 折叠按钮头
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    isCustomExpanded.toggle()
                                }
                            }) {
                                HStack {
                                    Text("自定义压缩参数")
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
                                    
                                    // A. 编码格式
                                    HStack {
                                        Text("编码格式")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Spacer()
                                        Picker("编码格式", selection: settingsBindingAutoCustom(\.codec)) {
                                            Text("HEVC").tag(VideoCodec.hevc)
                                            Text("H.264").tag(VideoCodec.h264)
                                        }
                                        .pickerStyle(.segmented)
                                        .frame(width: 180)
                                    }
                                    
                                    // B. 输出格式
                                    HStack {
                                        Text("输出格式")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Spacer()
                                        Picker("输出格式", selection: settingsBindingAutoCustom(\.outputFormat)) {
                                            Text("MOV").tag(VideoContainerFormat.mov)
                                            Text("MP4").tag(VideoContainerFormat.mp4)
                                        }
                                        .pickerStyle(.segmented)
                                        .frame(width: 180)
                                    }
                                    
                                    // C. 分辨率滑动条
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text("分辨率")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Spacer()
                                            Text("(\(Int(viewModel.width * viewModel.settings.resolutionScale))x\(Int(viewModel.height * viewModel.settings.resolutionScale))) \(Int(viewModel.settings.resolutionScale * 100))%")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.purple)
                                        }
                                        
                                        Slider(value: settingsBindingAutoCustom(\.resolutionScale), in: 0.1...1.0, step: 0.05)
                                            .tint(.purple)
                                    }
                                    
                                    // D. 码率滑动条
                                    VStack(alignment: .leading, spacing: 6) {
                                        let originalMbps = max(1.0, viewModel.originalBitrate / 1_000_000.0)
                                        let currentMbps = (viewModel.originalBitrate * viewModel.settings.customVideoBitrateMultiplier) / 1_000_000.0
                                        let bitratePercent = Int((viewModel.settings.customVideoBitrateMultiplier) * 100)
                                        
                                        let bitrateBinding = Binding<Double>(
                                            get: {
                                                min(originalMbps, max(0.4, currentMbps))
                                            },
                                            set: { newValue in
                                                viewModel.settings.customVideoBitrateMultiplier = newValue / (viewModel.originalBitrate / 1_000_000.0)
                                                viewModel.settings.preset = .custom
                                            }
                                        )
                                        HStack {
                                            Text("码率")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Spacer()
                                            Text("(\(String(format: "%.1f", currentMbps)) Mbps) \(bitratePercent)%")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.purple)
                                        }
                                        
                                        let bitrateDots: [DotConfig] = {
                                            var dots: [DotConfig] = []
                                            if 4.0 > 0.4 && 4.0 < originalMbps {
                                                dots.append(DotConfig(value: 4.0, label: "建议值: 4.0 Mbps"))
                                            }
                                            return dots
                                        }()
                                        
                                        SnappingSliderWithDots(
                                            value: bitrateBinding,
                                            range: 0.4...originalMbps,
                                            step: 0.1,
                                            dots: bitrateDots,
                                            tooltipText: $tooltipText,
                                            tooltipDotId: $tooltipDotId,
                                            sliderId: "bitrate"
                                        )
                                    }
                                    
                                    // E. 帧率滑动条
                                    VStack(alignment: .leading, spacing: 6) {
                                        let currentFps = viewModel.settings.frameRate == 0 ? Double(viewModel.fps) : Double(viewModel.settings.frameRate)
                                        let fpsPercent = Int((currentFps / Double(max(1, viewModel.fps))) * 100)
                                        
                                        let fpsBinding = Binding<Double>(
                                            get: { currentFps },
                                            set: { newValue in
                                                var target = newValue
                                                let snapTargets = [24.0, 30.0, 60.0]
                                                for snap in snapTargets {
                                                    if snap <= Double(viewModel.fps) && abs(newValue - snap) < 2.0 {
                                                        target = snap
                                                        break
                                                    }
                                                }
                                                if abs(target - Double(viewModel.fps)) < 1.0 {
                                                    viewModel.settings.frameRate = 0
                                                } else {
                                                    viewModel.settings.frameRate = Int(round(target))
                                                }
                                                viewModel.settings.preset = .custom
                                            }
                                        )
                                        HStack {
                                            Text("帧率")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Spacer()
                                            Text("(\(Int(currentFps)) FPS) \(fpsPercent)%")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.purple)
                                        }
                                        
                                        let maxFps = Double(max(2.0, viewModel.fps))
                                        let fpsDots: [DotConfig] = [24.0, 30.0, 60.0]
                                            .filter { $0 > 2.0 && $0 < maxFps }
                                            .map { DotConfig(value: $0, label: "建议值: \(Int($0)) FPS") }
                                        
                                        SnappingSliderWithDots(
                                            value: fpsBinding,
                                            range: 2.0...maxFps,
                                            step: 1.0,
                                            dots: fpsDots,
                                            tooltipText: $tooltipText,
                                            tooltipDotId: $tooltipDotId,
                                            sliderId: "fps"
                                        )
                                    }
                                    
                                    // F. 音频码率滑动条 (0 = 静音, max = 原音透传)
                                    VStack(alignment: .leading, spacing: 6) {
                                        let audioMaxKbps = max(64.0, viewModel.originalAudioBitrate / 1000.0)
                                        let currentAudioKbps: Double = {
                                            if viewModel.settings.audioBitrate <= 0 {
                                                return 0
                                            } else if !viewModel.settings.compressAudio {
                                                return audioMaxKbps
                                            } else {
                                                return viewModel.settings.audioBitrate / 1000.0
                                            }
                                        }()
                                        let audioPercent = audioMaxKbps > 0 ? Int((currentAudioKbps / audioMaxKbps) * 100) : 0
                                        
                                        let audioBinding = Binding<Double>(
                                            get: { currentAudioKbps },
                                            set: { newValue in
                                                if newValue <= 1.0 {
                                                    viewModel.settings.compressAudio = true
                                                    viewModel.settings.audioBitrate = 0
                                                } else if newValue >= audioMaxKbps - 1.0 {
                                                    viewModel.settings.compressAudio = false
                                                    viewModel.settings.audioBitrate = viewModel.originalAudioBitrate
                                                } else {
                                                    viewModel.settings.compressAudio = true
                                                    var target = newValue
                                                    let snapTargets = [64.0, 128.0]
                                                    for snap in snapTargets {
                                                        if snap < audioMaxKbps && abs(newValue - snap) < 8.0 {
                                                            target = snap
                                                            break
                                                        }
                                                    }
                                                    viewModel.settings.audioBitrate = Double(Int(target) * 1000)
                                                }
                                                viewModel.settings.preset = .custom
                                            }
                                        )
                                        HStack {
                                            Text("音频码率")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Spacer()
                                            Text("(\(Int(currentAudioKbps)) Kbps) \(audioPercent)%")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.purple)
                                        }
                                        
                                        var audioDots: [DotConfig] = []
                                        let _ = {
                                            audioDots.append(DotConfig(value: 0, label: "视频静音"))
                                            if 64.0 < audioMaxKbps {
                                                audioDots.append(DotConfig(value: 64.0, label: "建议值: 64 Kbps"))
                                            }
                                            if 128.0 < audioMaxKbps {
                                                audioDots.append(DotConfig(value: 128.0, label: "建议值: 128 Kbps"))
                                            }
                                        }()
                                        
                                        SnappingSliderWithDots(
                                            value: audioBinding,
                                            range: 0...audioMaxKbps,
                                            step: 8.0,
                                            dots: audioDots,
                                            tooltipText: $tooltipText,
                                            tooltipDotId: $tooltipDotId,
                                            sliderId: "audio"
                                        )
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
                        MetadataToggleRow(keepMetadata: $viewModel.settings.keepMetadata, showTooltip: $showMetadataTooltip, tintColor: .purple)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 24)
                }
                
                // 6. Dynamic Predictive Storage Saver Bar & Launch Footer
                VStack(spacing: 16) {
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
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
            .onAppear {
                if let url = viewModel.originalURL {
                    generateThumbnail(for: url)
                }
            }
        }
    }
    
    // MARK: - 自动切换为自定义预设的 Binding 工厂
    
    private func settingsBindingAutoCustom<T: Equatable>(_ keyPath: WritableKeyPath<CompressionSettings, T>) -> Binding<T> {
        Binding<T>(
            get: { viewModel.settings[keyPath: keyPath] },
            set: { newValue in
                viewModel.settings[keyPath: keyPath] = newValue
                viewModel.settings.preset = .custom
            }
        )
    }
    
    // MARK: - 辅助方法
    
    private func generateThumbnail(for url: URL) {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 400)
        
        let time = CMTime(seconds: 0.0, preferredTimescale: 600)
        generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, image, _, _, _ in
            if let image = image {
                let uiImage = UIImage(cgImage: image)
                DispatchQueue.main.async {
                    self.videoThumbnail = uiImage
                }
            }
        }
    }
    
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

// MARK: - 保留元数据行 + info tooltip（视频和照片共用）

struct MetadataToggleRow: View {
    @Binding var keepMetadata: Bool
    @Binding var showTooltip: Bool
    var tintColor: Color = .purple
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack {
                HStack(spacing: 4) {
                    Text("保留元数据")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showTooltip = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            withAnimation {
                                showTooltip = false
                            }
                        }
                    }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: $keepMetadata)
                    .labelsHidden()
                    .tint(tintColor)
            }
            .padding(16)
            .background(Color.white.opacity(0.02))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
            
            // Tooltip 气泡
            if showTooltip {
                Text("保留原文件拍摄日期、摄像头信息、坐标信息……")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.purple.opacity(0.92))
                    .cornerRadius(10)
                    .shadow(color: .purple.opacity(0.3), radius: 6)
                    .offset(x: -20, y: -36)
                    .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .bottomTrailing)))
            }
        }
    }
}

// MARK: - 刻度点配置

struct DotConfig: Identifiable {
    let id = UUID()
    let value: Double
    let label: String // tooltip 文案
}

// MARK: - 带可点击刻度点的滑杆组件（增大点击区域至 30pt）

struct SnappingSliderWithDots: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let dots: [DotConfig]
    @Binding var tooltipText: String?
    @Binding var tooltipDotId: String?
    let sliderId: String
    
    var body: some View {
        ZStack(alignment: .leading) {
            Slider(value: $value, in: range, step: step)
                .tint(.purple)
            
            GeometryReader { geo in
                let padding: CGFloat = 8
                let width = geo.size.width - (padding * 2)
                let rangeSpan = range.upperBound - range.lowerBound
                
                ForEach(dots) { dot in
                    if range.contains(dot.value) && rangeSpan > 0 {
                        let fraction = (dot.value - range.lowerBound) / rangeSpan
                        let xPos = padding + CGFloat(fraction) * width
                        let isActive = abs(value - dot.value) < (step * 0.6)
                        let dotId = "\(sliderId)_\(dot.id)"
                        
                        ZStack {
                            // Tooltip 气泡
                            if tooltipDotId == dotId, let text = tooltipText {
                                Text(text)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.purple.opacity(0.9))
                                    .cornerRadius(6)
                                    .offset(y: -28)
                                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                                    .zIndex(100)
                            }
                            
                            // 可见圆点 (10pt)
                            Circle()
                                .fill(isActive ? Color.white : Color.white.opacity(0.7))
                                .frame(width: 10, height: 10)
                                .overlay(
                                    Circle()
                                        .stroke(Color.purple, lineWidth: 2)
                                )
                                .shadow(color: .purple.opacity(0.5), radius: isActive ? 4 : 2)
                        }
                        .frame(width: 30, height: 30) // 点击热区 30x30pt
                        .contentShape(Rectangle())
                        .position(x: xPos, y: geo.size.height / 2)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                value = dot.value
                                tooltipText = dot.label
                                tooltipDotId = dotId
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                withAnimation {
                                    if tooltipDotId == dotId {
                                        tooltipText = nil
                                        tooltipDotId = nil
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(height: 44)
    }
}
