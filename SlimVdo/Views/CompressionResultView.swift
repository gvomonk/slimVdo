//
//  CompressionResultView.swift
//  SlimVdo
//
//  Created by Antigravity on 2026/5/25.
//

import SwiftUI
import AVKit

@available(iOS 16.0, *)
struct CompressionResultView: View {
    @ObservedObject var viewModel: CompressionViewModel
    
    // 播放器比对状态
    @State private var showOriginal = false
    @State private var originalPlayer: AVPlayer?
    @State private var compressedPlayer: AVPlayer?
    @State private var isPlaying = false
    
    // 保存/替换状态追踪
    @State private var saveSuccess = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.05, green: 0.05, blue: 0.08)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // 1. Success Header
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.emeraldGreen.opacity(0.12))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title)
                            .foregroundColor(.emeraldGreen)
                    }
                    
                    Text("压缩完成")
                        .font(.title3)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                }
                .padding(.vertical, 16)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // 2. Final Stats Card
                        VStack(spacing: 16) {
                            HStack(alignment: .bottom) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("原大小")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    Text(formatBytes(viewModel.originalSize))
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                
                                Spacer()
                                
                                VStack(spacing: 4) {
                                    Text(String(format: "-%.0f%%", viewModel.actualSavingsRatio * 100))
                                        .font(.system(size: 11, weight: .black))
                                        .foregroundColor(.emeraldGreen)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.emeraldGreen.opacity(0.12))
                                        .cornerRadius(6)
                                    
                                    Image(systemName: "arrow.right")
                                        .font(.title3)
                                        .foregroundColor(.purple)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("压缩后")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    Text(formatBytes(viewModel.compressedSize))
                                        .font(.title2)
                                        .fontWeight(.black)
                                        .foregroundColor(.white)
                                }
                            }
                            
                            if viewModel.originalURLs.count == 1 {
                                // 分辨率
                                CompactComparisonRow(
                                    label: "分辨率",
                                    leftValue: "\(Int(viewModel.width))x\(Int(viewModel.height))",
                                    rightValue: "\(Int(viewModel.width * viewModel.settings.resolutionScale))x\(Int(viewModel.height * viewModel.settings.resolutionScale))"
                                )
                                
                                // 码率
                                CompactComparisonRow(
                                    label: "码率",
                                    leftValue: String(format: "%.1f Mbps", viewModel.originalBitrate / 1_000_000.0),
                                    rightValue: String(format: "%.1f Mbps", (viewModel.originalBitrate * viewModel.settings.customVideoBitrateMultiplier) / 1_000_000.0)
                                )
                                
                                // 帧率
                                CompactComparisonRow(
                                    label: "帧率",
                                    leftValue: "\(Int(viewModel.fps)) FPS",
                                    rightValue: viewModel.settings.frameRate == 0 ? "\(Int(viewModel.fps)) FPS" : "\(viewModel.settings.frameRate) FPS"
                                )
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
                        
                        // 3. Double Player Comparator (核心：双路画质同步对比播放器)
                        VStack(alignment: .leading, spacing: 12) {
                            let videoRatio = viewModel.width > 0 && viewModel.height > 0 ? viewModel.width / viewModel.height : 16.0 / 9.0
                            
                            // 播放器容器
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.black)
                                    .aspectRatio(videoRatio, contentMode: .fit)
                                
                                if showOriginal, let player = originalPlayer {
                                    VideoPlayer(player: player)
                                        .aspectRatio(videoRatio, contentMode: .fit)
                                        .cornerRadius(20)
                                } else if let player = compressedPlayer {
                                    VideoPlayer(player: player)
                                        .aspectRatio(videoRatio, contentMode: .fit)
                                        .cornerRadius(20)
                                }
                                
                                // 浮动控制面板 (音视频同步状态下的原位切换按钮)
                                HStack {
                                    // 播放/暂停
                                    Button(action: togglePlayPause) {
                                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                            .font(.title)
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    // 按住/点击切换“原视频”与“压缩视频”
                                    Button(action: toggleCompareAsset) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                                                .font(.caption2)
                                            Text(showOriginal ? "before" : "after")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.purple)
                                        .cornerRadius(10)
                                        .shadow(color: .purple.opacity(0.3), radius: 4)
                                    }
                                }
                                .padding(12)
                                .background(LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                                .cornerRadius(20)
                            }
                            .frame(maxHeight: 400)
                            .padding(.horizontal)
                            .onAppear(perform: initializePlayers)
                            .onDisappear(perform: releasePlayers)
                        }
                    }
                    .padding(.bottom, 24)
                }
                
                // 4. Save/Replace CTA Footer
                VStack(spacing: 16) {
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    HStack(spacing: 16) {
                        // 动作一：保存为副本
                        Button(action: {
                            Task {
                                do {
                                    try await viewModel.saveToPhotosLibrary()
                                    alertMessage = "已保存压缩视频副本至系统相册"
                                    saveSuccess = true
                                    showAlert = true
                                } catch {
                                    alertMessage = "保存失败: \(error.localizedDescription)"
                                    saveSuccess = false
                                    showAlert = true
                                }
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.down.fill")
                                Text("保存副本")
                            }
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        
                        // 动作二：一键替换
                        Button(action: {
                            Task {
                                do {
                                    try await viewModel.replaceOriginalVideo()
                                    alertMessage = "已成功替换原视频"
                                    saveSuccess = true
                                    showAlert = true
                                } catch {
                                    if (error as NSError).code != -1 {
                                        alertMessage = "替换操作失败: \(error.localizedDescription)"
                                        saveSuccess = false
                                        showAlert = true
                                    }
                                }
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.on.doc")
                                Text("直接替换")
                            }
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .indigo],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: .purple.opacity(0.2), radius: 4)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 动作三：放弃并返回
                    Button(action: {
                        withAnimation {
                            viewModel.cleanup()
                        }
                    }) {
                        Text("放弃并返回")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 24)
                }
                .background(Color(red: 0.04, green: 0.04, blue: 0.06))
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(saveSuccess ? "操作成功" : "提示"),
                message: Text(alertMessage),
                dismissButton: .default(Text("好的")) {
                    if saveSuccess {
                        withAnimation {
                            viewModel.cleanup()
                        }
                    }
                }
            )
        }
    }
    
    // MARK: - 播放器同步机制
    
    private func initializePlayers() {
        guard let original = viewModel.originalURL, let compressed = viewModel.compressedURL else { return }
        
        let oAsset = AVURLAsset(url: original)
        let cAsset = AVURLAsset(url: compressed)
        
        let oItem = AVPlayerItem(asset: oAsset)
        let cItem = AVPlayerItem(asset: cAsset)
        
        self.originalPlayer = AVPlayer(playerItem: oItem)
        self.compressedPlayer = AVPlayer(playerItem: cItem)
        
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: oItem,
            queue: .main
        ) { _ in
            self.loopVideo()
        }
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: cItem,
            queue: .main
        ) { _ in
            self.loopVideo()
        }
    }
    
    private func releasePlayers() {
        originalPlayer?.pause()
        compressedPlayer?.pause()
        originalPlayer = nil
        compressedPlayer = nil
        isPlaying = false
        NotificationCenter.default.removeObserver(self)
    }
    
    private func togglePlayPause() {
        guard let oPlayer = originalPlayer, let cPlayer = compressedPlayer else { return }
        
        if isPlaying {
            oPlayer.pause()
            cPlayer.pause()
            isPlaying = false
        } else {
            let time = showOriginal ? oPlayer.currentTime() : cPlayer.currentTime()
            oPlayer.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
            cPlayer.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
            
            oPlayer.play()
            cPlayer.play()
            isPlaying = true
        }
    }
    
    private func toggleCompareAsset() {
        guard let oPlayer = originalPlayer, let cPlayer = compressedPlayer else { return }
        
        let activePlayer = showOriginal ? oPlayer : cPlayer
        let time = activePlayer.currentTime()
        
        showOriginal.toggle()
        
        let nextPlayer = showOriginal ? oPlayer : cPlayer
        
        nextPlayer.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
            if finished && self.isPlaying {
                nextPlayer.play()
            }
        }
    }
    
    private func loopVideo() {
        originalPlayer?.seek(to: .zero)
        compressedPlayer?.seek(to: .zero)
        if isPlaying {
            originalPlayer?.play()
            compressedPlayer?.play()
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
}

// MARK: - 紧凑对比行子组件

struct CompactComparisonRow: View {
    let label: String
    let leftValue: String
    let rightValue: String
    
    var body: some View {
        HStack {
            Text(leftValue)
                .font(.caption)
                .foregroundColor(.gray)
            
            Spacer()
            
            HStack(spacing: 4) {
                // Image(systemName: "arrow.right")
                //     .font(.system(size: 8))
                //     .foregroundColor(.purple.opacity(0.6))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.purple.opacity(0.8))
                // Image(systemName: "arrow.right")
                //     .font(.system(size: 8))
                //     .foregroundColor(.purple.opacity(0.6))
            }
            
            Spacer()
            
            Text(rightValue)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
}
