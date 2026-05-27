//
//  PhotoCompressionResultView.swift
//  SlimVdo
//
//  Created by Antigravity on 2026/5/25.
//

import SwiftUI

@available(iOS 16.0, *)
struct PhotoCompressionResultView: View {
    @ObservedObject var viewModel: PhotoCompressionViewModel
    
    // 按住比对状态
    @State private var isPressingCompare = false
    
    // 保存/替换状态
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
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(Color.emeraldGreen.opacity(0.12))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "photo.stack.fill")
                            .font(.title2)
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
                        
                        // 2. Statistics Card（与视频结果页统一风格）
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
                                        .foregroundColor(.blue)
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
                                
                                // 质量
                                CompactComparisonRow(
                                    label: "质量",
                                    leftValue: "100%",
                                    rightValue: "\(Int(viewModel.settings.compressionQuality * 100))%"
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
                        
                        // 3. Touch Gesture Comparator (原位按住无缝对比器)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Spacer()
                                Text(isPressingCompare ? "原图" : "压缩图")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(isPressingCompare ? .orange : .blue)
                            }
                            .padding(.horizontal)
                            
                            // 对比预览区域
                            ZStack(alignment: .topTrailing) {
                                if let origURL = viewModel.originalURL,
                                   let compURL = viewModel.compressedURL,
                                   let origImg = UIImage(contentsOfFile: origURL.path),
                                   let compImg = UIImage(contentsOfFile: compURL.path) {
                                    
                                    Image(uiImage: isPressingCompare ? origImg : compImg)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 300)
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(isPressingCompare ? Color.orange.opacity(0.5) : Color.blue.opacity(0.3), lineWidth: 1.5)
                                        )
                                        .gesture(
                                            DragGesture(minimumDistance: 0)
                                                .onChanged { _ in
                                                    if !isPressingCompare {
                                                        isPressingCompare = true
                                                    }
                                                }
                                                .onEnded { _ in
                                                    isPressingCompare = false
                                                }
                                        )
                                }
                                
                                // 操作指引浮层
                                Text(isPressingCompare ? "松开还原" : "按住比对")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(isPressingCompare ? Color.orange.opacity(0.8) : Color.black.opacity(0.6))
                                    .cornerRadius(10)
                                    .padding(12)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 24)
                }
                
                // 4. Action CTAs Footer
                VStack(spacing: 16) {
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    HStack(spacing: 16) {
                        // 动作一：另存为
                        Button(action: {
                            Task {
                                do {
                                    try await viewModel.saveToPhotosLibrary()
                                    alertMessage = "已保存压缩后的照片副本至系统相册"
                                    saveSuccess = true
                                    showAlert = true
                                } catch {
                                    alertMessage = "保存相片失败: \(error.localizedDescription)"
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
                        
                        // 动作二：覆盖替换
                        Button(action: {
                            Task {
                                do {
                                    try await viewModel.replaceOriginalPhoto()
                                    alertMessage = "已成功替换原图"
                                    saveSuccess = true
                                    showAlert = true
                                } catch {
                                    if (error as NSError).code != -1 {
                                        alertMessage = "覆盖替换相片失败: \(error.localizedDescription)"
                                        saveSuccess = false
                                        showAlert = true
                                    }
                                }
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.on.doc")
                                Text("一键替换")
                            }
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .indigo],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: .blue.opacity(0.2), radius: 4)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 动作三：返回
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
