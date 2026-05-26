//
//  PhotoCompressionSettings.swift
//  SlimVdo
//
//  Created by Antigravity on 2026/5/25.
//

import Foundation
import CoreGraphics

/// 支持的照片输出格式
public enum PhotoFormat: String, Codable, CaseIterable {
    case heic = "HEIC (高效且体积小)"
    case jpeg = "JPEG (通用兼容)"
    
    public var uti: String {
        switch self {
        case .heic: return "public.heic"
        case .jpeg: return "public.jpeg"
        }
    }
    
    public var pathExtension: String {
        switch self {
        case .heic: return "heic"
        case .jpeg: return "jpg"
        }
    }
}

/// 照片预设档位
public enum PhotoCompressionPreset: String, Codable, CaseIterable, Identifiable {
    case extreme = "极限压缩"
    case standard = "标准平衡"
    case high = "极致高清"
    case custom = "自定义"
    
    public var id: String { self.rawValue }
    public var displayName: String { self.rawValue }
    
    public var iconName: String {
        switch self {
        case .extreme: return "photo.fill.on.rectangle.fill"
        case .standard: return "checkmark.circle.fill"
        case .high: return "sparkles"
        case .custom: return "slider.horizontal.3"
        }
    }
}

/// 照片压缩参数配置模型
public struct PhotoCompressionSettings: Codable, Equatable {
    public var preset: PhotoCompressionPreset
    public var format: PhotoFormat
    public var resolutionScale: CGFloat   // 0.1 ~ 1.0 (分辨率百分比)
    public var compressionQuality: CGFloat // 0.1 ~ 1.0 (画质质量百分比)
    public var keepMetadata: Bool         // 是否保留 Exif 和 GPS 元数据
    
    public init(
        preset: PhotoCompressionPreset = .standard,
        format: PhotoFormat = .heic,
        resolutionScale: CGFloat = 0.8,
        compressionQuality: CGFloat = 0.75,
        keepMetadata: Bool = true
    ) {
        self.preset = preset
        self.format = format
        self.resolutionScale = resolutionScale
        self.compressionQuality = compressionQuality
        self.keepMetadata = keepMetadata
    }
    
    /// 获取当前照片预设对应的配置
    public static func settings(for preset: PhotoCompressionPreset) -> PhotoCompressionSettings {
        switch preset {
        case .extreme:
            return PhotoCompressionSettings(
                preset: .extreme,
                format: .heic,
                resolutionScale: 0.5,       // 分辨率减半
                compressionQuality: 0.55,   // 极限压制
                keepMetadata: true
            )
        case .standard:
            return PhotoCompressionSettings(
                preset: .standard,
                format: .heic,
                resolutionScale: 0.8,       // 缩小 20%
                compressionQuality: 0.75,   // 黄金画质保留比
                keepMetadata: true
            )
        case .high:
            return PhotoCompressionSettings(
                preset: .high,
                format: .heic,
                resolutionScale: 1.0,       // 保持原画大小
                compressionQuality: 0.88,   // 几乎无感压缩
                keepMetadata: true
            )
        case .custom:
            return PhotoCompressionSettings(
                preset: .custom,
                format: .heic,
                resolutionScale: 0.8,
                compressionQuality: 0.75,
                keepMetadata: true
            )
        }
    }
}
