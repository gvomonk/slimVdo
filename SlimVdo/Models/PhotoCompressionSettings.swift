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
    
    nonisolated public var uti: String {
        switch self {
        case .heic: return "public.heic"
        case .jpeg: return "public.jpeg"
        }
    }
    
    nonisolated public var pathExtension: String {
        switch self {
        case .heic: return "heic"
        case .jpeg: return "jpg"
        }
    }
}

/// 照片预设档位（与视频预设对齐，百分比代表目标大小占原始比例）
public enum PhotoCompressionPreset: String, Codable, CaseIterable, Identifiable {
    case p85 = "85%"
    case p70 = "70%"
    case p50 = "50%"
    case p30 = "30%"
    case p15 = "15%"
    case custom = "自定义"
    
    public var id: String { self.rawValue }
    public var displayName: String { self.rawValue }
}

/// 照片压缩参数配置模型
public struct PhotoCompressionSettings: Codable, Equatable {
    public var preset: PhotoCompressionPreset
    public var format: PhotoFormat
    public var resolutionScale: CGFloat   // 0.1 ~ 1.0 (分辨率百分比)
    public var compressionQuality: CGFloat // 0.1 ~ 1.0 (画质质量百分比)
    public var keepMetadata: Bool         // 是否保留 Exif 和 GPS 元数据
    
    public init(
        preset: PhotoCompressionPreset = .p70,
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
        case .p85:
            return PhotoCompressionSettings(
                preset: .p85,
                format: .heic,
                resolutionScale: 1.0,
                compressionQuality: 0.85,
                keepMetadata: true
            )
        case .p70:
            return PhotoCompressionSettings(
                preset: .p70,
                format: .heic,
                resolutionScale: 0.9,
                compressionQuality: 0.75,
                keepMetadata: true
            )
        case .p50:
            return PhotoCompressionSettings(
                preset: .p50,
                format: .heic,
                resolutionScale: 0.75,
                compressionQuality: 0.65,
                keepMetadata: true
            )
        case .p30:
            return PhotoCompressionSettings(
                preset: .p30,
                format: .heic,
                resolutionScale: 0.6,
                compressionQuality: 0.50,
                keepMetadata: true
            )
        case .p15:
            return PhotoCompressionSettings(
                preset: .p15,
                format: .heic,
                resolutionScale: 0.5,
                compressionQuality: 0.35,
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
