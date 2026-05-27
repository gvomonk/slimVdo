//
//  CompressionViewModel.swift
//  SlimVdo
//
//  Created by Antigravity on 2026/5/25.
//

import Combine
import CoreTransferable
import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// 压缩生命周期状态机
public enum CompressionState: Equatable {
    case idle
    case loadingAsset
    case configuring
    case processing(progress: Double, eta: String, speedFPS: String)
    case completed
    case failed(error: String)
    
    public static func == (lhs: CompressionState, rhs: CompressionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loadingAsset, .loadingAsset), (.configuring, .configuring), (.completed, .completed):
            return true
        case (.processing(let lp, let le, let lf), .processing(let rp, let re, let rf)):
            return lp == rp && le == re && lf == rf
        case (.failed(let le), .failed(let re)):
            return le == re
        default:
            return false
        }
    }
}

@available(iOS 16.0, *)
private struct PickedMovie: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { receivedFile in
            let destinationURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("slimvdo_source_\(UUID().uuidString).mp4")
            try FileManager.default.copyItem(at: receivedFile.file, to: destinationURL)
            return PickedMovie(url: destinationURL)
        }
    }
}

@available(iOS 15.0, *)
@MainActor
public final class CompressionViewModel: ObservableObject {
    
    // MARK: - Published Properties (沙盒与数据驱动)
    
    @Published public var state: CompressionState = .idle
    @Published public var settings = CompressionSettings.settings(for: .p70)
    
    // 所选视频源元数据
    @Published public var videoTitle: String = ""
    @Published public var originalSize: Int64 = 0
    @Published public var duration: TimeInterval = 0.0
    @Published public var width: CGFloat = 0.0
    @Published public var height: CGFloat = 0.0
    @Published public var fps: Double = 0.0
    @Published public var codecUsed: String = ""
    
    // 压缩结果数据
    @Published public var compressedSize: Int64 = 0
    
    // MARK: - 私有属性与依赖
    
    private let compressor = VideoCompressor()
    private let historyService = StorageHistoryService.shared
    
    public var originalURL: URL?
    public var compressedURL: URL?
    public var originalAsset: PHAsset?
    
    public var originalURLs: [URL] = []
    public var compressedURLs: [URL] = []
    public var originalAssets: [PHAsset] = []
    
    @Published public var originalBitrate: Double = 0.0 // in bps
    @Published public var originalAudioBitrate: Double = 128_000.0 // in bps
    
    /// 原始文件的容器格式（从文件扩展名推断）
    public var originalContainerFormat: VideoContainerFormat {
        guard let url = originalURL else { return .mp4 }
        return url.pathExtension.lowercased() == "mov" ? .mov : .mp4
    }
    
    /// 原始文件的编码格式（从 codecUsed 推断）
    public var originalCodec: VideoCodec {
        let codec = codecUsed.lowercased()
        if codec.contains("hevc") || codec.contains("hvc1") || codec.contains("h.265") || codec.contains("265") {
            return .hevc
        }
        return .h264
    }
    
    // 计时器辅助
    private var compressionStartTime: Date?
    
    public init() {
        // 在启动时，例行清理一次可能残留的 tmp 缓存，确保 0 存储浪费
        compressor.clearAllTempFiles()
    }
    
    // MARK: - 智能体积预测属性
    
    /// 根据当前配置滑块实时动态预测的大小 (Bytes)
    public var estimatedSize: Int64 {
        guard originalSize > 0 else { return 0 }
        return VideoCompressor.estimateOutputSize(
            originalSize: originalSize,
            settings: settings,
            originalDuration: duration,
            originalWidth: width,
            originalHeight: height,
            originalFPS: fps
        )
    }
    
    /// 预测的磁盘节省比例 (如 0.78 表示预计节省 78%)
    public var estimatedSavingsRatio: Double {
        guard originalSize > 0 else { return 0.0 }
        let saved = Double(originalSize - estimatedSize)
        return max(0.0, saved / Double(originalSize))
    }
    
    /// 压缩后视频的最终实际空间节省比例
    public var actualSavingsRatio: Double {
        guard originalSize > 0, compressedSize > 0 else { return 0.0 }
        let saved = Double(originalSize - compressedSize)
        return max(0.0, saved / Double(originalSize))
    }
    
    // MARK: - 视频拾取与元数据提取
    
    /// 从 PHAsset 集合中高性能直连载入视频并解析元数据 (0拷贝, 毫秒级直读)
    public func selectVideosFromAssets(_ assets: [PHAsset]) async {
        self.state = .loadingAsset
        
        do {
            var urls: [URL] = []
            var totalSize: Int64 = 0
            
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = false // 强制禁止后台自动下载 iCloud 资源，彻底屏蔽系统网络询问弹窗
            options.deliveryMode = .highQualityFormat
            
            for asset in assets {
                let avAsset = try await requestAVAsset(for: asset, options: options)
                guard let urlAsset = avAsset as? AVURLAsset else {
                    throw NSError(domain: "CompressionViewModel", code: -12, userInfo: [NSLocalizedDescriptionKey: "iCloudCloudOffline"])
                }
                
                // 提取原文件名，支持原名带 _1 命名逻辑
                let resources = PHAssetResource.assetResources(for: asset)
                let originalFilename = resources.first?.originalFilename ?? "video.mp4"
                let baseName = (originalFilename as NSString).deletingPathExtension
                let ext = (originalFilename as NSString).pathExtension.lowercased()
                
                let tempDir = FileManager.default.temporaryDirectory
                let tempURL = tempDir.appendingPathComponent("slimvdo_source_\(UUID().uuidString)_\(baseName).\(ext)")
                
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try? FileManager.default.removeItem(at: tempURL)
                }
                try FileManager.default.copyItem(at: urlAsset.url, to: tempURL)
                urls.append(tempURL)
                
                let fileSize = (resources.first?.value(forKey: "fileSize") as? NSNumber)?.int64Value ?? 0
                totalSize += fileSize
            }
            
            guard !urls.isEmpty else {
                self.state = .failed(error: "未选中任何合法的视频文件")
                return
            }
            
            self.originalURLs = urls
            self.originalSize = totalSize
            self.originalAssets = assets
            
            let firstURL = urls[0]
            self.originalURL = firstURL
            self.originalAsset = assets.first
            
            // 解析第一个视频元数据用于页面占位显示
            let avAsset = AVURLAsset(url: firstURL)
            guard let videoTrack = try await avAsset.loadTracks(withMediaType: .video).first else {
                throw NSError(domain: "CompressionViewModel", code: -11, userInfo: [NSLocalizedDescriptionKey: "无法解析该视频的画面轨道"])
            }
            
            let naturalSize = try await videoTrack.load(.naturalSize)
            let preferredTransform = try await videoTrack.load(.preferredTransform)
            let nominalFPS = try await videoTrack.load(.nominalFrameRate)
            let assetDuration = try await avAsset.load(.duration)
            
            let isPortrait = abs(preferredTransform.b) > 0.0
            self.width = isPortrait ? naturalSize.height : naturalSize.width
            self.height = isPortrait ? naturalSize.width : naturalSize.height
            self.duration = CMTimeGetSeconds(assetDuration)
            self.fps = Double(nominalFPS)
            
            // 提取码率
            let rawBitrate = try? await videoTrack.load(.estimatedDataRate)
            let calculatedBitrate = Double(totalSize * 8) / duration
            self.originalBitrate = rawBitrate != nil ? Double(rawBitrate!) : calculatedBitrate
            
            if urls.count > 1 {
                self.videoTitle = "批量压缩 (\(urls.count)个视频)"
            } else {
                let resources = PHAssetResource.assetResources(for: assets[0])
                self.videoTitle = resources.first?.originalFilename ?? firstURL.lastPathComponent
            }
            
            let formats = try await videoTrack.load(.formatDescriptions)
            if let firstFormat = formats.first {
                let mediaSubType = CMFormatDescriptionGetMediaSubType(firstFormat)
                if mediaSubType == kCMVideoCodecType_HEVC {
                    self.codecUsed = "HEVC / H.265"
                } else if mediaSubType == kCMVideoCodecType_H264 {
                    self.codecUsed = "H.264 / AVC"
                } else {
                    self.codecUsed = "其他编码"
                }
            } else {
                self.codecUsed = "未知格式"
            }
            self.settings = CompressionSettings.settings(for: .p70)
            self.settings.outputFormat = self.originalContainerFormat
            self.compressedSize = 0
            self.compressedURL = nil
            self.state = .configuring
            
        } catch {
            let errorMsg = error.localizedDescription
            if errorMsg.contains("iCloud") || errorMsg.contains("Cloud") || (error as NSError).code == -1 {
                self.state = .failed(error: "本app被禁止联网\n请放心使用\n（若您正操作的文件在iCloud云端\n请先下载到本地）")
            } else {
                self.state = .failed(error: "加载视频失败: \(error.localizedDescription)")
            }
            self.cleanup()
        }
    }
    
    private func requestAVAsset(for asset: PHAsset, options: PHVideoRequestOptions) async throws -> AVAsset {
        try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, audioMix, info in
                if let avAsset = avAsset {
                    continuation.resume(returning: avAsset)
                } else {
                    let error = NSError(domain: "CompressionViewModel", code: -10, userInfo: [NSLocalizedDescriptionKey: "iCloudCloudOffline"])
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    @available(iOS 16.0, *)
    public func selectVideos(photosPickerItems: [PhotosPickerItem]) async {
        self.state = .loadingAsset
        
        do {
            var urls: [URL] = []
            var totalSize: Int64 = 0
            var assets: [PHAsset] = []
            
            for item in photosPickerItems {
                guard let movie = try await item.loadTransferable(type: PickedMovie.self) else { continue }
                urls.append(movie.url)
                if let fileAttributes = try? FileManager.default.attributesOfItem(atPath: movie.url.path) {
                    totalSize += fileAttributes[.size] as? Int64 ?? 0
                }
                
                if let id = item.itemIdentifier {
                    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
                    if let first = fetchResult.firstObject {
                        assets.append(first)
                    }
                }
            }
            
            guard !urls.isEmpty else {
                self.state = .failed(error: "未选中任何合法的视频文件")
                return
            }
            
            self.originalURLs = urls
            self.originalSize = totalSize
            self.originalAssets = assets
            
            // 使用第一个视频作为代表来解析基本元数据
            let firstURL = urls[0]
            self.originalURL = firstURL
            self.originalAsset = assets.first
            
            // 解析第一个视频元数据用于页面占位显示
            let asset = AVURLAsset(url: firstURL)
            guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                throw NSError(domain: "CompressionViewModel", code: -11, userInfo: [NSLocalizedDescriptionKey: "无法解析该视频的画面轨道"])
            }
            
            let naturalSize = try await videoTrack.load(.naturalSize)
            let preferredTransform = try await videoTrack.load(.preferredTransform)
            let nominalFPS = try await videoTrack.load(.nominalFrameRate)
            let assetDuration = try await asset.load(.duration)
            
            let isPortrait = abs(preferredTransform.b) > 0.0
            self.width = isPortrait ? naturalSize.height : naturalSize.width
            self.height = isPortrait ? naturalSize.width : naturalSize.height
            self.duration = CMTimeGetSeconds(assetDuration)
            self.fps = Double(nominalFPS)
            
            if urls.count > 1 {
                self.videoTitle = "批量压缩 (\(urls.count)个视频)"
            } else {
                self.videoTitle = originalAsset?.value(forKey: "filename") as? String ?? firstURL.lastPathComponent
            }
            
            let formats = try await videoTrack.load(.formatDescriptions)
            if let firstFormat = formats.first {
                let mediaSubType = CMFormatDescriptionGetMediaSubType(firstFormat)
                if mediaSubType == kCMVideoCodecType_HEVC {
                    self.codecUsed = "HEVC / H.265"
                } else if mediaSubType == kCMVideoCodecType_H264 {
                    self.codecUsed = "H.264 / AVC"
                } else {
                    self.codecUsed = "其他编码"
                }
            } else {
                self.codecUsed = "未知格式"
            }
            self.settings = CompressionSettings.settings(for: .p70)
            self.settings.outputFormat = self.originalContainerFormat
            self.compressedSize = 0
            self.compressedURL = nil
            self.state = .configuring
            
        } catch {
            self.state = .failed(error: "加载视频失败: \(error.localizedDescription)")
            self.cleanup()
        }
    }
    
    /// 从相册选择器结果中异步载入视频并解析元数据 (NSItemProvider 兼容)
    public func selectVideo(itemProvider: NSItemProvider, assetIdentifier: String?) async {
        self.state = .loadingAsset
        
        // 验证文件类型
        guard itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else {
            self.state = .failed(error: "选中的文件不是合法的视频格式")
            return
        }
        
        do {
            let localURL = try await loadVideoFileIntoSandbox(itemProvider: itemProvider)
            self.originalURLs = [localURL]
            self.originalURL = localURL
            
            if let id = assetIdentifier {
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
                self.originalAsset = fetchResult.firstObject
                if let first = self.originalAsset {
                    self.originalAssets = [first]
                }
            }
            
            // 解析元数据
            let asset = AVURLAsset(url: localURL)
            guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                throw NSError(domain: "CompressionViewModel", code: -11, userInfo: [NSLocalizedDescriptionKey: "无法解析该视频的画面轨道"])
            }
            
            let naturalSize = try await videoTrack.load(.naturalSize)
            let preferredTransform = try await videoTrack.load(.preferredTransform)
            let nominalFPS = try await videoTrack.load(.nominalFrameRate)
            let estimatedBitrate = try await videoTrack.load(.estimatedDataRate)
            let assetDuration = try await asset.load(.duration)
            
            let isPortrait = abs(preferredTransform.b) > 0.0
            self.width = isPortrait ? naturalSize.height : naturalSize.width
            self.height = isPortrait ? naturalSize.width : naturalSize.height
            self.duration = CMTimeGetSeconds(assetDuration)
            self.fps = Double(nominalFPS)
            self.videoTitle = originalAsset?.value(forKey: "filename") as? String ?? localURL.lastPathComponent
            
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
            self.originalSize = fileAttributes[.size] as? Int64 ?? Int64(estimatedBitrate / 8) * Int64(duration)
            
            let formats = try await videoTrack.load(.formatDescriptions)
            if let firstFormat = formats.first {
                let mediaSubType = CMFormatDescriptionGetMediaSubType(firstFormat)
                if mediaSubType == kCMVideoCodecType_HEVC {
                    self.codecUsed = "HEVC / H.265"
                } else if mediaSubType == kCMVideoCodecType_H264 {
                    self.codecUsed = "H.264 / AVC"
                } else {
                    self.codecUsed = "其他编码"
                }
            } else {
                self.codecUsed = "未知格式"
            }
            self.settings = CompressionSettings.settings(for: .p70)
            self.settings.outputFormat = self.originalContainerFormat
            self.compressedSize = 0
            self.compressedURL = nil
            self.state = .configuring
            
        } catch {
            self.state = .failed(error: "加载视频失败: \(error.localizedDescription)")
            self.cleanup()
        }
    }
    
    // MARK: - 视频压缩流执行与撤销
    
    /// 开始执行核心视频压缩逻辑
    public func startCompression() async {
        guard !originalURLs.isEmpty else {
            self.state = .failed(error: "找不到视频源文件路径")
            return
        }
        
        self.state = .processing(progress: 0.0, eta: "--:--", speedFPS: "0.0")
        self.compressionStartTime = Date()
        
        do {
            var compURLs: [URL] = []
            var totalCompSize: Int64 = 0
            
            for (idx, inputURL) in originalURLs.enumerated() {
                let baseProgress = Double(idx) / Double(originalURLs.count)
                let outputURL = try await compressor.compressVideo(inputURL: inputURL, settings: settings) { [weak self] update in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        let currentProgress = baseProgress + (update.progress / Double(self.originalURLs.count))
                        let etaStr = self.calculateETA(progress: currentProgress)
                        let fpsStr = String(format: "%.1f", update.currentFPS)
                        
                        self.state = .processing(
                            progress: currentProgress,
                            eta: etaStr,
                            speedFPS: fpsStr
                        )
                    }
                }
                compURLs.append(outputURL)
                let fileAttributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
                totalCompSize += fileAttributes[.size] as? Int64 ?? 0
            }
            
            self.compressedURLs = compURLs
            self.compressedURL = compURLs.first
            self.compressedSize = totalCompSize
            self.state = .completed
            
        } catch {
            if (error as NSError).domain == "VideoCompressionActor" && (error as NSError).code == -9 {
                self.state = .configuring
            } else {
                self.state = .failed(error: error.localizedDescription)
            }
        }
    }
    
    /// 用户在进度中点击取消
    public func cancelCompression() {
        compressor.cancelCompression()
    }
    
    // MARK: - 照片库元数据穿透保存 & 替换
    
    /// 将压缩后的视频保存到用户的 Photos 相册中，完美继承原始日期和位置元数据
    public func saveToPhotosLibrary() async throws {
        guard !compressedURLs.isEmpty else {
            throw NSError(domain: "CompressionViewModel", code: -15, userInfo: [NSLocalizedDescriptionKey: "无压缩视频输出文件"])
        }
        
        for (idx, outputURL) in compressedURLs.enumerated() {
            let asset = idx < originalAssets.count ? originalAssets[idx] : nil
            let keepMeta = settings.keepMetadata
            try await PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
                if keepMeta, let orig = asset {
                    creationRequest?.creationDate = orig.creationDate
                    creationRequest?.location = orig.location
                }
                // keepMetadata == false: 不设置 creationDate/location，
                // 系统默认为当前时刻，无坐标
            }
        }
        
        registerHistoryRecord()
        cleanup()
    }
    
    /// 保存新视频，并同步触发系统相册删除原视频（一键替换原视频，直接释放空间）
    public func replaceOriginalVideo() async throws {
        guard !compressedURLs.isEmpty else {
            throw NSError(domain: "CompressionViewModel", code: -16, userInfo: [NSLocalizedDescriptionKey: "无法替换原视频，缺失关联对象"])
        }
        
        // 1. 首先向相册保存新压缩片
        for (idx, outputURL) in compressedURLs.enumerated() {
            let asset = idx < originalAssets.count ? originalAssets[idx] : nil
            let keepMeta = settings.keepMetadata
            try await PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
                if keepMeta, let orig = asset {
                    creationRequest?.creationDate = orig.creationDate
                    creationRequest?.location = orig.location
                }
            }
        }
        
        // 2. 然后申请删除原高分辨率大片
        if !self.originalAssets.isEmpty {
            try await PHPhotoLibrary.shared().performChanges { [self] in
                PHAssetChangeRequest.deleteAssets(self.originalAssets as NSArray)
            }
        }
        
        registerHistoryRecord()
        cleanup()
    }
    
    // MARK: - 重置与清理垃圾缓存 (0 MB 占用保证)
    
    /// 清除所有暂存文件
    public func cleanup() {
        for url in originalURLs {
            compressor.deleteFile(at: url)
        }
        originalURLs.removeAll()
        originalURL = nil
        
        for url in compressedURLs {
            compressor.deleteFile(at: url)
        }
        compressedURLs.removeAll()
        compressedURL = nil
        
        originalAssets.removeAll()
        originalAsset = nil
        originalSize = 0
        compressedSize = 0
        videoTitle = ""
        state = .idle
    }
    
    // MARK: - 辅助私有计算方法
    
    /// 登记本次成功压缩到历史服务中
    private func registerHistoryRecord() {
        let beforeRes = "\(Int(width))x\(Int(height))"
        let afterRes = "\(Int(width * settings.resolutionScale))x\(Int(height * settings.resolutionScale))"
        
        let elapsed = compressionStartTime != nil ? Date().timeIntervalSince(compressionStartTime!) : 0.0
        
        let record = CompressionRecord(
            videoTitle: videoTitle,
            originalSize: originalSize,
            compressedSize: compressedSize,
            duration: duration,
            compressionDuration: elapsed,
            resolutionBefore: beforeRes,
            resolutionAfter: afterRes,
            codecUsed: settings.codec.rawValue
        )
        
        historyService.addRecord(record)
    }
    
    /// 将系统选择视频导出至 App 沙盒的内部临时目录中
    private func loadVideoFileIntoSandbox(itemProvider: NSItemProvider) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            // 请求将 Movie 类型的临时文件安全拷贝出来
            itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] (url, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let sourceURL = url else {
                    continuation.resume(throwing: NSError(domain: "CompressionViewModel", code: -12, userInfo: [NSLocalizedDescriptionKey: "无法定位拷贝源"]))
                    return
                }
                
                // 拷贝至我们沙盒的 /tmp 目录，因为系统相册提供的只读 fileURL 在闭包结束时可能会被系统销毁
                let fm = FileManager.default
                let tempDir = fm.temporaryDirectory
                let destinationURL = tempDir.appendingPathComponent("slimvdo_source_\(UUID().uuidString).mp4")
                
                do {
                    // 如果已存在，删除
                    if fm.fileExists(atPath: destinationURL.path) {
                        try fm.removeItem(at: destinationURL)
                    }
                    try fm.copyItem(at: sourceURL, to: destinationURL)
                    continuation.resume(returning: destinationURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 根据当前进度及耗时计算 ETA
    private func calculateETA(progress: Double) -> String {
        guard progress > 0.01, let start = compressionStartTime else { return "--:--" }
        
        let elapsed = Date().timeIntervalSince(start)
        let totalEstimatedTime = elapsed / progress
        let remainingTime = totalEstimatedTime - elapsed
        
        if remainingTime <= 0 {
            return "00:00"
        }
        
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
