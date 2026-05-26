//
//  PhotoCompressionViewModel.swift
//  SlimVdo
//
//  Created by Antigravity on 2026/5/25.
//

import Foundation
import PhotosUI
import SwiftUI
import Combine
import UniformTypeIdentifiers

/// 照片压缩流状态机
public enum PhotoCompressionState: Equatable {
    case idle
    case loadingAsset
    case configuring
    case processing
    case completed
    case failed(error: String)
    
    public static func == (lhs: PhotoCompressionState, rhs: PhotoCompressionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loadingAsset, .loadingAsset), (.configuring, .configuring), (.processing, .processing), (.completed, .completed):
            return true
        case (.failed(let le), .failed(let re)):
            return le == re
        default:
            return false
        }
    }
}

@available(iOS 16.0, *)
@MainActor
public final class PhotoCompressionViewModel: ObservableObject {
    
    // MARK: - Published 驱动状态
    
    @Published public var state: PhotoCompressionState = .idle
    @Published public var settings = PhotoCompressionSettings.settings(for: .standard)
    
    // 照片元数据
    @Published public var photoTitle: String = ""
    @Published public var originalSize: Int64 = 0
    @Published public var width: CGFloat = 0.0
    @Published public var height: CGFloat = 0.0
    @Published public var codecUsed: String = ""
    
    // 压缩结果
    @Published public var compressedSize: Int64 = 0
    
    public var originalURL: URL?
    public var compressedURL: URL?
    public var originalAsset: PHAsset?
    
    public var originalURLs: [URL] = []
    public var compressedURLs: [URL] = []
    public var originalAssets: [PHAsset] = []
    
    private let historyService = StorageHistoryService.shared
    
    public init() {}
    
    // MARK: - 智能体积预测
    
    /// 毫秒级动态估计大小 (Bytes)
    public var estimatedSize: Int64 {
        guard originalSize > 0 else { return 0 }
        
        let scale = settings.resolutionScale
        let resolutionAreaRatio = scale * scale
        
        // 估算 HEIC 相较于 JPEG 的极大红利 (如果是 JPEG 导入且选择输出为 HEIC，体积额外折半)
        let originalIsJPEG = codecUsed.contains("JPEG")
        let outputIsHEIC = settings.format == .heic
        let formatDiscount = (originalIsJPEG && outputIsHEIC) ? 0.50 : 1.0
        
        // 品质调节因子系数 (线性拟合)
        let qualityFactor = settings.compressionQuality
        
        let est = Double(originalSize) * Double(resolutionAreaRatio) * formatDiscount * Double(qualityFactor)
        
        // 安全保护范围界限 (5% ~ 90%)
        let minBound = Int64(Double(originalSize) * 0.05)
        let maxBound = Int64(Double(originalSize) * 0.90)
        
        return max(minBound, min(Int64(est), maxBound))
    }
    
    /// 预计节省比例
    public var estimatedSavingsRatio: Double {
        guard originalSize > 0 else { return 0.0 }
        let saved = Double(originalSize - estimatedSize)
        return max(0.0, saved / Double(originalSize))
    }
    
    /// 实际压缩后节省比例
    public var actualSavingsRatio: Double {
        guard originalSize > 0, compressedSize > 0 else { return 0.0 }
        let saved = Double(originalSize - compressedSize)
        return max(0.0, saved / Double(originalSize))
    }
    
    // MARK: - 照片选择与载入 (现代 loadTransferable 接口)
    
    /// 从 SwiftUI 相册选择器结果中异步载入照片并解析元数据
    public func selectPhotos(photosPickerItems: [PhotosPickerItem]) async {
        self.state = .loadingAsset
        
        do {
            var urls: [URL] = []
            var totalSize: Int64 = 0
            var assets: [PHAsset] = []
            
            for item in photosPickerItems {
                guard let rawData = try await item.loadTransferable(type: Data.self) else { continue }
                
                let tempDir = FileManager.default.temporaryDirectory
                let sourceURL = tempDir.appendingPathComponent("slimvdo_photo_source_\(UUID().uuidString).jpg")
                try rawData.write(to: sourceURL)
                urls.append(sourceURL)
                
                if let fileAttributes = try? FileManager.default.attributesOfItem(atPath: sourceURL.path) {
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
                self.state = .failed(error: "未选中任何合法的图像文件")
                return
            }
            
            self.originalURLs = urls
            self.originalSize = totalSize
            self.originalAssets = assets
            
            // 使用第一张照片作为代表解析基础元数据
            let firstURL = urls[0]
            self.originalURL = firstURL
            self.originalAsset = assets.first
            
            // 用 ImageIO 极速解析物理属性
            guard let imageSource = CGImageSourceCreateWithURL(firstURL as CFURL, nil) else {
                throw NSError(domain: "PhotoCompressionViewModel", code: -31, userInfo: [NSLocalizedDescriptionKey: "无法解析照片的属性信息"])
            }
            
            if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
                self.width = properties[kCGImagePropertyPixelWidth as String] as? CGFloat ?? 0
                self.height = properties[kCGImagePropertyPixelHeight as String] as? CGFloat ?? 0
            }
            
            if urls.count > 1 {
                self.photoTitle = "批量压缩 (\(urls.count)张照片)"
            } else {
                self.photoTitle = originalAsset?.value(forKey: "filename") as? String ?? firstURL.lastPathComponent
            }
            
            if let type = CGImageSourceGetType(imageSource) {
                let typeString = type as String
                if typeString == UTType.heic.identifier {
                    self.codecUsed = "HEIC (高效编码)"
                } else if typeString == UTType.jpeg.identifier {
                    self.codecUsed = "JPEG (传统格式)"
                } else {
                    self.codecUsed = "PNG / 其他图像"
                }
            } else {
                self.codecUsed = "未知图像"
            }
            
            // 成功，切入配置页面
            self.settings = PhotoCompressionSettings.settings(for: .standard)
            self.compressedSize = 0
            self.compressedURL = nil
            self.state = .configuring
            
        } catch {
            self.state = .failed(error: "读取照片信息失败: \(error.localizedDescription)")
            self.cleanup()
        }
    }
    
    /// 选择相册照片并流式拷贝解析 (NSItemProvider 兼容版本)
    public func selectPhoto(itemProvider: NSItemProvider, assetIdentifier: String?) async {
        self.state = .loadingAsset
        
        if let id = assetIdentifier {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
            self.originalAsset = fetchResult.firstObject
            if let first = self.originalAsset {
                self.originalAssets = [first]
            }
        }
        
        do {
            guard let rawData = try await loadRawImageData(itemProvider: itemProvider) else {
                throw NSError(domain: "PhotoCompressionViewModel", code: -30, userInfo: [NSLocalizedDescriptionKey: "无法解析该照片的原始数据包"])
            }
            
            // 写入沙盒 /tmp
            let tempDir = FileManager.default.temporaryDirectory
            let sourceURL = tempDir.appendingPathComponent("slimvdo_photo_source_\(UUID().uuidString).jpg")
            try rawData.write(to: sourceURL)
            self.originalURLs = [sourceURL]
            self.originalURL = sourceURL
            
            try await prepareSelectedPhoto(localURL: sourceURL)
            
        } catch {
            self.state = .failed(error: "读取照片信息失败: \(error.localizedDescription)")
            self.cleanup()
        }
    }
    
    private func prepareSelectedPhoto(localURL: URL) async throws {
        self.originalURL = localURL
        
        // 用 ImageIO 极速解析物理属性
        guard let imageSource = CGImageSourceCreateWithURL(localURL as CFURL, nil) else {
            throw NSError(domain: "PhotoCompressionViewModel", code: -31, userInfo: [NSLocalizedDescriptionKey: "无法解析照片的属性信息"])
        }
        
        // 提取大小、格式和分辨率
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
        self.originalSize = fileAttributes[.size] as? Int64 ?? 0
        self.photoTitle = originalAsset?.value(forKey: "filename") as? String ?? localURL.lastPathComponent
        
        if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
            self.width = properties[kCGImagePropertyPixelWidth as String] as? CGFloat ?? 0
            self.height = properties[kCGImagePropertyPixelHeight as String] as? CGFloat ?? 0
        }
        
        if let type = CGImageSourceGetType(imageSource) {
            let typeString = type as String
            if typeString == UTType.heic.identifier {
                self.codecUsed = "HEIC (高效编码)"
            } else if typeString == UTType.jpeg.identifier {
                self.codecUsed = "JPEG (传统格式)"
            } else {
                self.codecUsed = "PNG / 其他图像"
            }
        } else {
            self.codecUsed = "未知图像"
        }
        
        // 成功，切入配置页面
        self.settings = PhotoCompressionSettings.settings(for: .standard)
        self.compressedSize = 0
        self.compressedURL = nil
        self.state = .configuring
    }
    
    // MARK: - 照片压缩执行
    
    /// 开始进行硬件级别照片压缩
    public func startCompression() async {
        guard !originalURLs.isEmpty else {
            self.state = .failed(error: "未找到有效的源照片文件")
            return
        }
        
        self.state = .processing
        
        let settingsCopy = self.settings
        
        do {
            var compURLs: [URL] = []
            var totalCompSize: Int64 = 0
            
            for input in originalURLs {
                let outputURL = try await Task.detached(priority: .userInitiated) {
                    try PhotoCompressor.compressPhoto(inputURL: input, settings: settingsCopy)
                }.value
                compURLs.append(outputURL)
                let fileAttributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
                totalCompSize += fileAttributes[FileAttributeKey.size] as? Int64 ?? 0
            }
            
            self.compressedURLs = compURLs
            self.compressedURL = compURLs.first
            self.compressedSize = totalCompSize
            self.state = .completed
            
        } catch {
            self.state = .failed(error: error.localizedDescription)
        }
    }
    
    // MARK: - 保存与覆盖一键置换
    
    /// 保存压缩后的照片，同步继承原始地理位置与创建日期元数据
    public func saveToPhotosLibrary() async throws {
        guard !compressedURLs.isEmpty else {
            throw NSError(domain: "PhotoCompressionViewModel", code: -35, userInfo: [NSLocalizedDescriptionKey: "找不到输出的照片文件"])
        }
        
        for (idx, outputURL) in compressedURLs.enumerated() {
            let asset = idx < originalAssets.count ? originalAssets[idx] : nil
            try await PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: outputURL)
                if let orig = asset {
                    creationRequest?.creationDate = orig.creationDate
                    creationRequest?.location = orig.location
                }
            }
        }
        
        registerHistoryRecord()
        cleanup()
    }
    
    /// 覆盖替换原照片资产，一键释放体积
    public func replaceOriginalPhoto() async throws {
        guard !compressedURLs.isEmpty else {
            throw NSError(domain: "PhotoCompressionViewModel", code: -36, userInfo: [NSLocalizedDescriptionKey: "缺失原图对象，无法替换"])
        }
        
        // 1. 保存压缩版本，继承日期定位
        for (idx, outputURL) in compressedURLs.enumerated() {
            let asset = idx < originalAssets.count ? originalAssets[idx] : nil
            try await PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: outputURL)
                if let orig = asset {
                    creationRequest?.creationDate = orig.creationDate
                    creationRequest?.location = orig.location
                }
            }
        }
        
        // 2. 一键请求删除原大文件照片，由系统级弹窗进行保障确认
        if !self.originalAssets.isEmpty {
            try await PHPhotoLibrary.shared().performChanges { [self] in
                PHAssetChangeRequest.deleteAssets(self.originalAssets as NSArray)
            }
        }
        
        registerHistoryRecord()
        cleanup()
    }
    
    // MARK: - 清理与重置 (0 磁盘垃圾占用)
    
    public func cleanup() {
        let fm = FileManager.default
        for url in originalURLs {
            try? fm.removeItem(at: url)
        }
        originalURLs.removeAll()
        originalURL = nil
        
        for url in compressedURLs {
            try? fm.removeItem(at: url)
        }
        compressedURLs.removeAll()
        compressedURL = nil
        
        originalAssets.removeAll()
        originalAsset = nil
        originalSize = 0
        compressedSize = 0
        photoTitle = ""
        state = .idle
    }
    
    // MARK: - 辅助方法
    
    private func loadRawImageData(itemProvider: NSItemProvider) async throws -> Data? {
        return try await withCheckedThrowingContinuation { continuation in
            itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: data)
                }
            }
        }
    }
    
    private func registerHistoryRecord() {
        let beforeRes = "\(Int(width))x\(Int(height))"
        let afterRes = "\(Int(width * settings.resolutionScale))x\(Int(height * settings.resolutionScale))"
        
        let record = CompressionRecord(
            videoTitle: photoTitle,
            originalSize: originalSize,
            compressedSize: compressedSize,
            duration: 0.0, // 静态相片无时长
            compressionDuration: 0.2, // 照片压缩极快
            resolutionBefore: beforeRes,
            resolutionAfter: afterRes,
            codecUsed: settings.format == .heic ? "HEIC (相片)" : "JPEG (相片)"
        )
        historyService.addRecord(record)
    }
}
