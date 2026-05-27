//
//  PhotoCompressor.swift
//  SlimVdo
//
//  Created by Antigravity on 2026/5/25.
//

import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

/// 核心硬件加速照片压缩处理引擎
public final class PhotoCompressor {
    
    private init() {}
    
    /// 压缩并缩放单张照片，返回生成新照片的沙盒物理 URL 地址
    /// - Parameters:
    ///   - inputURL: 原始照片沙盒 URL
    ///   - settings: 压缩配置
    /// - Returns: 压缩 HEIC/JPEG 存盘物理地址
    public nonisolated static func compressPhoto(
        inputURL: URL,
        settings: PhotoCompressionSettings
    ) throws -> URL {
        // 从原始路径提取真正的相片名，追加 _1 作为输出，保障不带多余的 UUID 串
        let tempDir = FileManager.default.temporaryDirectory
        let inputFilename = inputURL.lastPathComponent
        var outputName = ""
        
        if inputFilename.hasPrefix("slimvdo_photo_source_") {
            // "slimvdo_photo_source_" 长度为 21，UUID 长度为 36，后面下划线 1 字符共 58 字符
            let prefixLength = 21 + 36 + 1
            if inputFilename.count > prefixLength {
                let startIndex = inputFilename.index(inputFilename.startIndex, offsetBy: prefixLength)
                let rest = String(inputFilename[startIndex...])
                let urlAsset = URL(fileURLWithPath: rest)
                let baseName = urlAsset.deletingPathExtension().lastPathComponent
                outputName = "slimvdo_photo_output_\(baseName)_1.\(settings.format.pathExtension)"
            }
        }
        
        if outputName.isEmpty {
            let baseName = inputURL.deletingPathExtension().lastPathComponent
            outputName = "slimvdo_photo_output_\(baseName)_1.\(settings.format.pathExtension)"
        }
        
        let outputURL = tempDir.appendingPathComponent(outputName)
        
        // 彻底使用 Swift 的标准 autoreleasepool 闭包限制临时像素和元数据缓存，杜绝内存堆积
        try autoreleasepool {
            // 1. 创建 ImageIO 图像源
            guard let imageSource = CGImageSourceCreateWithURL(inputURL as CFURL, nil) else {
                throw NSError(domain: "PhotoCompressor", code: -20, userInfo: [NSLocalizedDescriptionKey: "无法解析源图像文件"])
            }
            
            // 2. 提取源图像的元数据字典 (Exif, GPS, TIFF等)
            var metadata: [String: Any] = [:]
            if settings.keepMetadata {
                if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
                    metadata = properties
                    // CreateThumbnailWithTransform 已物理旋转像素，
                    // 必须将 Orientation 归一化为 1，否则查看器会二次旋转
                    metadata[kCGImagePropertyOrientation as String] = 1
                    // 同时归一化 TIFF 子字典中的 Orientation
                    if var tiff = metadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
                        tiff[kCGImagePropertyTIFFOrientation as String] = 1
                        metadata[kCGImagePropertyTIFFDictionary as String] = tiff
                    }
                }
            }
            
            // 3. 计算目标最大分辨率像素尺寸 (Downsampling 目标边界)
            var maxPixelSize: CGFloat = 0.0
            if settings.resolutionScale < 0.99 {
                // 读取原始像素宽高
                if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
                   let width = properties[kCGImagePropertyPixelWidth as String] as? CGFloat,
                   let height = properties[kCGImagePropertyPixelHeight as String] as? CGFloat {
                    let maxDim = max(width, height)
                    maxPixelSize = maxDim * settings.resolutionScale
                }
            }
            
            // 4. 高效下采样解码 (ImageIO Downsampling - 业内极致高性能防闪退最佳实践)
            // 它是苹果官方推荐的图像缩放手段，直接在解码阶段输出目标大小，不消耗额外内存，完全规避 OOM
            var options: [String: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways as String: true,
                kCGImageSourceShouldCacheImmediately as String: true,
                kCGImageSourceCreateThumbnailWithTransform as String: true
            ]
            if maxPixelSize > 0 {
                options[kCGImageSourceThumbnailMaxPixelSize as String] = Int(maxPixelSize)
            }
            
            guard let scaledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
                throw NSError(domain: "PhotoCompressor", code: -21, userInfo: [NSLocalizedDescriptionKey: "图像缩放硬件下采样失败"])
            }
            
            // 5. 开启硬件流式编码写出
            let outputFormatUTI = settings.format.uti as CFString
            guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, outputFormatUTI, 1, nil) else {
                throw NSError(domain: "PhotoCompressor", code: -22, userInfo: [NSLocalizedDescriptionKey: "创建目标图像目标出错"])
            }
            
            // 6. 配置硬件压缩质量属性字典
            var writeOptions: [String: Any] = [
                kCGImageDestinationLossyCompressionQuality as String: settings.compressionQuality
            ]
            
            if settings.keepMetadata {
                // 把元数据（已归一化 Orientation）合入 writeOptions
                for (key, val) in metadata {
                    writeOptions[key] = val
                }
            }
            // keepMetadata == false 时：不写入任何元数据键，
            // CGImageDestination 默认不含 GPS/Exif/TIFF，等同于彻底抹除
            
            CGImageDestinationAddImage(destination, scaledImage, writeOptions as CFDictionary)
            
            // 7. 写入盘文件并收尾
            guard CGImageDestinationFinalize(destination) else {
                throw NSError(domain: "PhotoCompressor", code: -23, userInfo: [NSLocalizedDescriptionKey: "图像硬件存盘写出失败"])
            }
        }
        
        return outputURL
    }
}
