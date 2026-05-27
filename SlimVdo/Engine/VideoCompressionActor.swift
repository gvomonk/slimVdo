//
//  VideoCompressionActor.swift
//  SlimVdo
//
//  Created by Antigravity on 2026/5/25.
//

import Foundation
import AVFoundation
import CoreImage
import Photos
import VideoToolbox

/// 压缩进度的状态回调结构体
public struct CompressionProgressUpdate: Sendable {
    public let progress: Double  // 0.0 ~ 1.0
    public let currentFPS: Double // 压缩速度帧率
}

/// 核心视频压缩 Actor，隔离在后台线程运行，保证线程安全
@available(iOS 15.0, *)
public actor VideoCompressionActor {
    
    nonisolated(unsafe) private var isCancelled = false
    
    public init() {}
    
    /// 触发取消标记
    public func cancel() {
        self.isCancelled = true
    }
    
    /// 执行核心压缩任务
    /// - Parameters:
    ///   - inputURL: 输入视频的沙盒 URL
    ///   - outputURL: 输出压缩视频的临时沙盒 URL
    ///   - settings: 压缩配置选项
    ///   - progressHandler: 实时进度通知回调 (progress, fps)
    public func compress(
        inputURL: URL,
        outputURL: URL,
        settings: CompressionSettings,
        progressHandler: @Sendable @escaping (CompressionProgressUpdate) -> Void
    ) async throws {
        self.isCancelled = false
        
        // 1. 加载 Asset 与轨道
        let asset = AVURLAsset(url: inputURL)
        
        // 获取视频和音频轨道
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "VideoCompressionActor", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法找到视频轨道"])
        }
        
        let audioTrack = try await asset.loadTracks(withMediaType: .audio).first
        
        // 2. 获取源视频的宽高、帧率和码率信息
        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let sourceFPS = try await videoTrack.load(.nominalFrameRate)
        let sourceBitrate = try await videoTrack.load(.estimatedDataRate)
        let duration = try await asset.load(.duration)
        let totalDurationSeconds = CMTimeGetSeconds(duration)
        
        // 计算目标宽高 (必须是 16 的倍数，否则部分硬件解码器会报错或出现绿边)
        let originalWidth = naturalSize.width
        let originalHeight = naturalSize.height
        var targetWidth = originalWidth * settings.resolutionScale
        var targetHeight = originalHeight * settings.resolutionScale
        
        // 保证是 16 的倍数
        targetWidth = CGFloat(Int(targetWidth / 16) * 16)
        targetHeight = CGFloat(Int(targetHeight / 16) * 16)
        if targetWidth < 16 { targetWidth = 16 }
        if targetHeight < 16 { targetHeight = 16 }
        
        // 3. 计算目标视频码率 (bps)
        // 根据分辨率面积缩放比例、编码器效率、自定义系数计算
        let originalPixels = originalWidth * originalHeight
        let targetPixels = targetWidth * targetHeight
        let pixelRatio = targetPixels / originalPixels
        
        // HEVC H.265 比 H.264 编码效率高约 40%，因此在同等画质下可以设置更低码率
        let codecEfficiencyMultiplier: Double = (settings.codec == .hevc) ? 0.6 : 1.0
        
        // 估算基准码率：按分辨率面积等比缩减原视频码率，并应用编码器系数和用户自定义系数
        let baseTargetBitrate = Double(sourceBitrate) * Double(pixelRatio) * codecEfficiencyMultiplier * settings.customVideoBitrateMultiplier
        
        // 设置码率上下限安全边界，防止画质崩溃或体积反而变大
        let minBitrate: Double = 400_000 // 最低 400 Kbps 保证基本轮廓
        let maxBitrate: Double = min(Double(sourceBitrate) * 0.9, 25_000_000) // 最高不超原码率的 90%
        let finalVideoBitrate = max(minBitrate, min(baseTargetBitrate, maxBitrate))
        
        // 4. 创建 AVAssetReader 和 AVAssetWriter
        let reader = try AVAssetReader(asset: asset)
        let writerFileType: AVFileType = settings.outputFormat == .mov ? .mov : .mp4
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: writerFileType)
        
        // 5. 配置视频输入输出
        // 解压视频设置（使用硬件最高效的 420YpCbCr8BiPlanar 格式，即 NV12）
        let readerVideoSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ]
        let readerVideoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerVideoSettings)
        readerVideoOutput.alwaysCopiesSampleData = false
        if reader.canAdd(readerVideoOutput) {
            reader.add(readerVideoOutput)
        } else {
            throw NSError(domain: "VideoCompressionActor", code: -2, userInfo: [NSLocalizedDescriptionKey: "无法添加视频读取输出"])
        }
        
        // 压缩视频设置
        var compressionProperties: [String: Any] = [
            AVVideoAverageBitRateKey: Int(finalVideoBitrate)
        ]
        if settings.codec == .hevc {
            compressionProperties[kVTCompressionPropertyKey_ProfileLevel as String] = kVTProfileLevel_HEVC_Main_AutoLevel
        } else {
            compressionProperties[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel
        }
        
        // 如果指定了目标帧率，设置最大关键帧间隔 (GOP) 为目标帧率，即 1 秒 1 个关键帧
        if settings.frameRate > 0 {
            compressionProperties[AVVideoMaxKeyFrameIntervalKey] = settings.frameRate
        } else {
            compressionProperties[AVVideoMaxKeyFrameIntervalKey] = Int(sourceFPS)
        }
        
        let writerVideoSettings: [String: Any] = [
            AVVideoCodecKey: settings.codec.identifier,
            AVVideoWidthKey: Int(targetWidth),
            AVVideoHeightKey: Int(targetHeight),
            AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
            AVVideoCompressionPropertiesKey: compressionProperties
        ]
        
        let writerVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: writerVideoSettings)
        writerVideoInput.expectsMediaDataInRealTime = false
        writerVideoInput.transform = preferredTransform // 保持视频拍摄朝向旋转角度
        
        if writer.canAdd(writerVideoInput) {
            writer.add(writerVideoInput)
        } else {
            throw NSError(domain: "VideoCompressionActor", code: -3, userInfo: [NSLocalizedDescriptionKey: "无法添加视频写入输入"])
        }
        
        // 6. 配置音频输入输出 (根据设置选择 AAC 重新编码或原样透传)
        var readerAudioOutput: AVAssetReaderTrackOutput?
        var writerAudioInput: AVAssetWriterInput?
        
        if let audio = audioTrack {
            // 音频码率为 0 时，完全跳过音频轨道（生成无声视频）
            if settings.audioBitrate > 0 {
                if settings.compressAudio {
                    // 压缩音频：解压音频设置 (PCM)
                    let readerAudioSettings: [String: Any] = [
                        AVFormatIDKey: kAudioFormatLinearPCM
                    ]
                    let audioOutput = AVAssetReaderTrackOutput(track: audio, outputSettings: readerAudioSettings)
                    audioOutput.alwaysCopiesSampleData = false
                    if reader.canAdd(audioOutput) {
                        reader.add(audioOutput)
                        readerAudioOutput = audioOutput
                    }
                    
                    // 压缩音频设置 (AAC)
                    let writerAudioSettings: [String: Any] = [
                        AVFormatIDKey: kAudioFormatMPEG4AAC,
                        AVSampleRateKey: 44100,
                        AVNumberOfChannelsKey: 2,
                        AVEncoderBitRateKey: Int(settings.audioBitrate)
                    ]
                    let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: writerAudioSettings)
                    audioInput.expectsMediaDataInRealTime = false
                    if writer.canAdd(audioInput) {
                        writer.add(audioInput)
                        writerAudioInput = audioInput
                    }
                } else {
                    // 透传原音频
                    let audioOutput = AVAssetReaderTrackOutput(track: audio, outputSettings: nil)
                    audioOutput.alwaysCopiesSampleData = false
                    if reader.canAdd(audioOutput) {
                        reader.add(audioOutput)
                        readerAudioOutput = audioOutput
                    }
                    
                    let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
                    audioInput.expectsMediaDataInRealTime = false
                    if writer.canAdd(audioInput) {
                        writer.add(audioInput)
                        writerAudioInput = audioInput
                    }
                }
            }
            // audioBitrate == 0: 不添加任何音频轨道，生成静音视频
        }
        
        // 7. 处理拍摄日期与 GPS 定位等元数据拷贝
        if settings.keepMetadata {
            let originalMetadata = try await asset.load(.metadata)
            if !originalMetadata.isEmpty {
                writer.metadata = originalMetadata
            }
        }
        
        // 8. 启动 Reader & Writer
        guard reader.startReading() else {
            throw reader.error ?? NSError(domain: "VideoCompressionActor", code: -4, userInfo: [NSLocalizedDescriptionKey: "无法启动视频读取"])
        }
        
        guard writer.startWriting() else {
            throw writer.error ?? NSError(domain: "VideoCompressionActor", code: -5, userInfo: [NSLocalizedDescriptionKey: "无法启动视频写入"])
        }
        
        writer.startSession(atSourceTime: .zero)
        
        // 9. 配置流式 CVPixelBuffer 缩放像素池 (如果需要分辨率缩放)
        let needsScaling = settings.resolutionScale < 0.99
        var pixelBufferPool: CVPixelBufferPool?
        
        if needsScaling {
            pixelBufferPool = createPixelBufferPool(width: Int(targetWidth), height: Int(targetHeight))
        }
        
        // 创建 VTPixelTransferSession 会话进行底层的纯硬件缩放，彻底消除 OOM 内存积累
        var transferSession: VTPixelTransferSession?
        if needsScaling {
            VTPixelTransferSessionCreate(allocator: kCFAllocatorDefault, pixelTransferSessionOut: &transferSession)
        }
        
        // 10. 核心循环：多路并行读取与写入
        let videoQueue = DispatchQueue(label: "com.slimvdo.compression.video")
        let audioQueue = DispatchQueue(label: "com.slimvdo.compression.audio")
        
        let startTime = Date()
        var lastProgressTime = Date()
        
        // 记录视频统计帧数，以便计算 FPS
        var processedVideoFrames = 0
        var totalVideoFramesInput = 0
        
        // 计算抽帧逻辑（用于帧率降减，例如 60 FPS 降至 30 FPS）
        let shouldDropFrames = settings.frameRate > 0 && Double(settings.frameRate) < Double(sourceFPS)
        let frameKeepInterval = shouldDropFrames ? Double(sourceFPS) / Double(settings.frameRate) : 1.0
        var frameIndexAccumulator = 0.0
        
        // 利用 GCD 信号量/协同来等待音视频两条轨道流式写完
        let group = DispatchGroup()
        
        // A. 视频写入循环
        group.enter()
        writerVideoInput.requestMediaDataWhenReady(on: videoQueue) {
            var shouldExit = false
            while !shouldExit && writerVideoInput.isReadyForMoreMediaData {
                autoreleasepool {
                    if self.isCancelled {
                        writerVideoInput.markAsFinished()
                        group.leave()
                        shouldExit = true
                        return
                    }
                    
                    guard let sampleBuffer = readerVideoOutput.copyNextSampleBuffer() else {
                        writerVideoInput.markAsFinished()
                        group.leave()
                        shouldExit = true
                        return
                    }
                    
                    totalVideoFramesInput += 1
                    
                    // 抽帧判定（降帧率）
                    if shouldDropFrames {
                        frameIndexAccumulator += 1.0
                        if frameIndexAccumulator < frameKeepInterval {
                            // 丢弃这一帧，继续读取下一帧
                            return
                        } else {
                            frameIndexAccumulator -= frameKeepInterval
                        }
                    }
                    
                    let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    let currentSeconds = CMTimeGetSeconds(presentationTime)
                    
                    // 获取像素缓冲区
                    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                        // 损坏的帧，继续
                        return
                    }
                    
                    var outputPixelBuffer = pixelBuffer
                    
                    // 如果需要硬件缩放，调用 VideoToolbox 进行底层的极致硬件缩放，零内存缓存泄露
                    if needsScaling, let pool = pixelBufferPool, let session = transferSession {
                        var scaledBuffer: CVPixelBuffer?
                        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &scaledBuffer)
                        
                        if status == kCVReturnSuccess, let destBuffer = scaledBuffer {
                            let transferStatus = VTPixelTransferSessionTransferImage(session, from: pixelBuffer, to: destBuffer)
                            if transferStatus == noErr {
                                outputPixelBuffer = destBuffer
                            }
                        }
                    }
                    
                    // 将处理完的像素帧，利用自定义 AVAssetWriterInputPixelBufferAdaptor 提交，
                    // 或直接根据原 SampleBuffer 的 timing 构建新 SampleBuffer 提交。
                    // 这里我们为了保证简单和极高兼容性，直接重新用原始 sampleBuffer 的时长 and 参数写回：
                    var timingInfo = CMSampleTimingInfo(
                        duration: CMSampleBufferGetDuration(sampleBuffer),
                        presentationTimeStamp: presentationTime,
                        decodeTimeStamp: CMSampleBufferGetDecodeTimeStamp(sampleBuffer)
                    )
                    
                    var scaledSampleBuffer: CMSampleBuffer?
                    var formatDescription: CMVideoFormatDescription?
                    CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: outputPixelBuffer, formatDescriptionOut: &formatDescription)
                    
                    if let format = formatDescription {
                        CMSampleBufferCreateForImageBuffer(
                            allocator: kCFAllocatorDefault,
                            imageBuffer: outputPixelBuffer,
                            dataReady: true,
                            makeDataReadyCallback: nil,
                            refcon: nil,
                            formatDescription: format,
                            sampleTiming: &timingInfo,
                            sampleBufferOut: &scaledSampleBuffer
                        )
                        
                        if let finalSample = scaledSampleBuffer {
                            writerVideoInput.append(finalSample)
                            processedVideoFrames += 1
                        }
                    }
                    
                    // B. 进度更新广播 (每 0.1 秒限制一次，避免高频刷新阻塞主线程)
                    let now = Date()
                    if now.timeIntervalSince(lastProgressTime) >= 0.1 {
                        lastProgressTime = now
                        let rawProgress = totalDurationSeconds > 0 ? (currentSeconds / totalDurationSeconds) : 0.0
                        let currentProgress = min(0.99, max(0.0, rawProgress))
                        
                        let elapsed = now.timeIntervalSince(startTime)
                        let fps = elapsed > 0 ? Double(processedVideoFrames) / elapsed : 0.0
                        
                        progressHandler(CompressionProgressUpdate(progress: currentProgress, currentFPS: fps))
                    }
                }
            }
        }
        
        // B. 音频写入循环 (如果有音频)
        if let readerAudio = readerAudioOutput, let writerAudio = writerAudioInput {
            group.enter()
            writerAudio.requestMediaDataWhenReady(on: audioQueue) {
                var shouldExit = false
                while !shouldExit && writerAudio.isReadyForMoreMediaData {
                    autoreleasepool {
                        if self.isCancelled {
                            writerAudio.markAsFinished()
                            group.leave()
                            shouldExit = true
                            return
                        }
                        
                        guard let sampleBuffer = readerAudio.copyNextSampleBuffer() else {
                            writerAudio.markAsFinished()
                            group.leave()
                            shouldExit = true
                            return
                        }
                        
                        writerAudio.append(sampleBuffer)
                    }
                }
            }
        }
        
        // 等待两条写入流水线均结束（使用非阻塞式异步等待，释放 Actor 线程以响应取消请求）
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            group.notify(queue: .global()) {
                continuation.resume()
            }
        }
        
        // 释放 VTPixelTransferSession 硬件资源
        if let session = transferSession {
            VTPixelTransferSessionInvalidate(session)
        }
        
        // 11. 收尾处理与文件持久化写入
        if isCancelled {
            reader.cancelReading()
            writer.cancelWriting()
            throw NSError(domain: "VideoCompressionActor", code: -9, userInfo: [NSLocalizedDescriptionKey: "用户取消了压缩任务"])
        }
        
        if reader.status == .failed {
            writer.cancelWriting()
            throw reader.error ?? NSError(domain: "VideoCompressionActor", code: -6, userInfo: [NSLocalizedDescriptionKey: "读取视频源时发生未名错误"])
        }
        
        // 完成写入，等待存盘（非阻塞式异步等待）
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer.finishWriting {
                continuation.resume()
            }
        }
        
        if writer.status == .failed {
            throw writer.error ?? NSError(domain: "VideoCompressionActor", code: -7, userInfo: [NSLocalizedDescriptionKey: "写入压缩文件时失败"])
        }
        
        // 压缩彻底结束，抛出 100% 进度
        let totalElapsed = Date().timeIntervalSince(startTime)
        let finalFPS = totalElapsed > 0 ? Double(processedVideoFrames) / totalElapsed : 0.0
        progressHandler(CompressionProgressUpdate(progress: 1.0, currentFPS: finalFPS))
    }
    
    // MARK: - 辅助方法
    
    /// 创建高度复用的 CVPixelBufferPool 以免连续分配内存
    private func createPixelBufferPool(width: Int, height: Int) -> CVPixelBufferPool? {
        let poolSettings: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 5 // 缓冲池大小为 5 帧
        ]
        
        let bufferSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] // 强制分配 IOSurface 以便硬解硬件渲染
        ]
        
        var pool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(kCFAllocatorDefault, poolSettings as CFDictionary, bufferSettings as CFDictionary, &pool)
        
        if status == kCVReturnSuccess {
            return pool
        }
        return nil
    }
}
