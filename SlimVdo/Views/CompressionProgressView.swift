//
//  CompressionProgressView.swift
//  SlimVdo
//
//  Created by Antigravity on 2026/5/25.
//

import SwiftUI

@available(iOS 16.0, *)
struct CompressionProgressView: View {
    @ObservedObject var viewModel: CompressionViewModel
    
    // 从 viewModel 状态中优雅解析进度遥测数据
    private var progress: Double {
        if case .processing(let p, _, _) = viewModel.state {
            return p
        }
        return 0.0
    }
    
    private var eta: String {
        if case .processing(_, let e, _) = viewModel.state {
            return e
        }
        return "--:--"
    }
    
    private var speedFPS: String {
        if case .processing(_, _, let s) = viewModel.state {
            return s
        }
        return "0.0"
    }
    
    // 动态计算已节省体积的累积数值
    private var savedBytesSoFar: Int64 {
        let totalTargetSavings = viewModel.originalSize - viewModel.estimatedSize
        guard totalTargetSavings > 0 else { return 0 }
        return Int64(Double(totalTargetSavings) * progress)
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.05, green: 0.05, blue: 0.08)
                .ignoresSafeArea()
            
            // Soft pulsating light behind progress circle
            Circle()
                .fill(Color.purple.opacity(0.12))
                .frame(width: 250, height: 250)
                .blur(radius: 30)
                .scaleEffect(1.0 + 0.15 * CGFloat(sin(progress * Double.pi * 4))) // 伴随进度波动缩放
            
            VStack(spacing: 40) {
                
                // 1. Top status message
                VStack(spacing: 8) {
                    Text("正在压缩")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding(.top, 40)
                
                // 2. Beautiful Pulsating Progress Ring (主进度环)
                ZStack {
                    // Back Ring
                    Circle()
                        .stroke(Color.white.opacity(0.04), lineWidth: 24)
                        .frame(width: 220, height: 220)
                    
                    // Front Progress Ring
                    Circle()
                        .trim(from: 0.0, to: CGFloat(progress))
                        .stroke(
                            LinearGradient(
                                colors: [.purple, .indigo, .blue],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            style: StrokeStyle(lineWidth: 22, lineCap: .round)
                        )
                        .frame(width: 220, height: 220)
                        .rotationEffect(Angle(degrees: -90))
                        .shadow(color: .purple.opacity(0.4), radius: 8, x: 0, y: 0)
                    
                    // Text Center
                    VStack(spacing: 4) {
                        Text(String(format: "%.0f%%", progress * 100))
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("ETA \(eta)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.purple)
                    }
                }
                
                // 3. Telemetry card (实时数值数据板)
                VStack(spacing: 16) {
                    // A. FPS & Speed Multiplier
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("速度")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text("\(speedFPS) FPS")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        Spacer()
                        
                        // 计算压缩相对于源的处理倍数
                        Text(calculateSpeedMultiplier())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.12))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    
                    // B. Satisfying Real-Time Space Saved Counter
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("已节省")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            
                            Text(formatBytes(savedBytesSoFar))
                                .font(.title3)
                                .fontWeight(.black)
                                .foregroundColor(.emeraldGreen)
                                .contentTransition(.numericText()) // iOS 16 数字滚动平滑切换
                        }
                        
                        Spacer()
                        
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.emeraldGreen)
                            .font(.title3)
                            .shadow(color: .emeraldGreen.opacity(0.5), radius: 4)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 20)
                .background(Color.white.opacity(0.02))
                .cornerRadius(24)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
                .padding(.horizontal, 28)
                
                // 4. Cancel Button (线程安全取消)
                Button(action: {
                    withAnimation {
                        viewModel.cancelCompression()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                        Text("中止")
                    }
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 28)
                
                Spacer()
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
    
    private func calculateSpeedMultiplier() -> String {
        guard let speed = Double(speedFPS), speed > 0, viewModel.fps > 0 else { return "硬件全速" }
        let multiplier = speed / viewModel.fps
        return String(format: "%.1fx 加速", multiplier)
    }
}
