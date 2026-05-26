//
//  VideoCompressor.swift
//  SlimVdo
//
//  Created by Antigravity on 2026/5/25.
//

import Foundation
import AVFoundation

/// 视频压缩服务主协调类
@available(iOS 15.0, *)
public final class VideoCompressor {
    
    private var activeActor: VideoCompressionActor?
    
    public init() {}
    
    /// 开始压缩视频
    /// - Parameters:
    ///   - inputURL: 视频源沙盒地址
    ///   - settings: 压缩配置选项
    ///   - progressHandler: 进度回调 (0.0 ~ 1.0, currentFPS)
    /// - Returns: 压缩成功后的沙盒临时输出文件 URL
    public func compressVideo(
        inputURL: URL,
        settings: CompressionSettings,
        progressHandler: @Sendable @escaping (CompressionProgressUpdate) -> Void
    ) async throws -> URL {
        // 创建唯一临时输出路径
        let tempDir = FileManager.default.temporaryDirectory
        let uniqueName = "slimvdo_compressed_\(UUID().uuidString).mp4"
        let outputURL = tempDir.appendingPathComponent(uniqueName)
        
        // 如果文件已存在，先删除
        self.deleteFile(at: outputURL)
        
        let actor = VideoCompressionActor()
        self.activeActor = actor
        
        do {
            try await actor.compress(
                inputURL: inputURL,
                outputURL: outputURL,
                settings: settings,
                progressHandler: progressHandler
            )
            self.activeActor = nil
            return outputURL
        } catch {
            self.activeActor = nil
            // 发生错误时，清理残留输出文件
            self.deleteFile(at: outputURL)
            throw error
        }
    }
    
    /// 触发中止当前压缩任务
    public func cancelCompression() {
        Task {
            await activeActor?.cancel()
        }
    }
    
    // MARK: - 文件与缓存管理（实现 0 内存与存储污染）
    
    /// 删除指定本地文件
    public func deleteFile(at url: URL) {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            do {
                try fm.removeItem(at: url)
                print("🗑️ 已成功删除临时文件: \(url.lastPathComponent)")
            } catch {
                print("⚠️ 尝试删除文件失败: \(url.path), 错误: \(error.localizedDescription)")
            }
        }
    }
    
    /// 扫描并清空所有由 SlimVdo 产生在 tmp 目录下的垃圾临时视频文件
    public func clearAllTempFiles() {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory
        
        do {
            let contents = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            for fileURL in contents {
                if fileURL.lastPathComponent.hasPrefix("slimvdo_") {
                    try fm.removeItem(at: fileURL)
                    print("🧹 清除遗留临时文件: \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            print("⚠️ 扫描并清除临时文件夹失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 智能体积预测算法 (业内最佳实践)
    
    /// 根据当前配置和视频原信息，即时估算压缩后的大小（字节数）
    /// - Parameters:
    ///   - originalSize: 原始大小 (Bytes)
    ///   - settings: 压缩配置
    ///   - originalDuration: 视频总时长 (秒)
    ///   - originalWidth: 原始宽度 (像素)
    ///   - originalHeight: 原始高度 (像素)
    ///   - originalFPS: 原始帧率 (FPS)
    /// - Returns: 预估的输出文件字节数 (Bytes)
    public static func estimateOutputSize(
        originalSize: Int64,
        settings: CompressionSettings,
        originalDuration: TimeInterval,
        originalWidth: CGFloat,
        originalHeight: CGFloat,
        originalFPS: Double
    ) -> Int64 {
        guard originalSize > 0, originalDuration > 0 else { return 0 }
        
        // 1. 拆分原始视频的音频和视频分量大小
        // AAC 默认音频大约占 128kbps = 16KB/s
        let estimatedOriginalAudioSize = Int64(16 * 1024 * originalDuration)
        let estimatedOriginalVideoSize = max(100_000, originalSize - estimatedOriginalAudioSize)
        
        // 2. 估计分辨率面积缩减比例
        let scale = settings.resolutionScale
        let resolutionAreaRatio = scale * scale
        
        // 3. 估计编码器缩减比率 (HEVC 比 H.264 大约节省 40% 的体积)
        let codecSavings: Double = (settings.codec == .hevc) ? 0.60 : 1.0
        
        // 4. 估计帧率降低带来的增益 (丢帧减少了总数据量，但帧间预测效率会稍降)
        var frameRateRatio = 1.0
        if settings.frameRate > 0 && Double(settings.frameRate) < originalFPS {
            let ratio = Double(settings.frameRate) / originalFPS
            // 帧率减半并不等于体积减半，因为帧间压缩起主导作用。这里设定折扣指数。
            frameRateRatio = 0.75 + (0.25 * ratio)
        }
        
        // 5. 结合自定义码率滑块比例
        let customBitrateFactor = settings.customVideoBitrateMultiplier
        
        // 6. 算出估计后的视频大小
        let estimatedNewVideoSize = Double(estimatedOriginalVideoSize) * Double(resolutionAreaRatio) * codecSavings * frameRateRatio * customBitrateFactor
        
        // 7. 算出估计后的音频大小
        var estimatedNewAudioSize: Int64 = 0
        if settings.compressAudio {
            // 音频大小 = 比特率 (bps) / 8 * 时长 (秒)
            estimatedNewAudioSize = Int64((settings.audioBitrate / 8.0) * originalDuration)
        }
        
        // 8. 累加总大小并设置合理上下限约束 (保证不超过原大小的 90%，且不低于原大小的 5%)
        let totalEstimatedSize = Int64(estimatedNewVideoSize) + estimatedNewAudioSize
        
        let minBound = Int64(Double(originalSize) * 0.05)
        let maxBound = Int64(Double(originalSize) * 0.90)
        
        return max(minBound, min(totalEstimatedSize, maxBound))
    }
}
