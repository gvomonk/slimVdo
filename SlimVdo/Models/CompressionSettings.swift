//
//  CompressionSettings.swift
//  SlimVdo
//
//  Created by Antigravity on 2026/5/25.
//

import Foundation
import CoreGraphics

/// 支持的视频编码格式
public enum VideoCodec: String, Codable, CaseIterable {
    case h264 = "H.264 (兼容性佳)"
    case hevc = "HEVC / H.265 (高效率)"
    
    public var identifier: String {
        switch self {
        case .h264: return "avc1"
        case .hevc: return "hvc1"
        }
    }
}

/// 预设档位
public enum CompressionPreset: String, Codable, CaseIterable, Identifiable {
    case extreme = "极限压缩"
    case standard = "标准平衡"
    case high = "极致高清"
    case custom = "自定义"
    
    public var id: String { self.rawValue }
    
    public var displayName: String { self.rawValue }
    
    public var iconName: String {
        switch self {
        case .extreme: return "scalemass"
        case .standard: return "checkmark.seal.fill"
        case .high: return "sparkles"
        case .custom: return "slider.horizontal.3"
        }
    }
    
    public var description: String {
        switch self {
        case .extreme: return "极小体积，适合快速分享"
        case .standard: return "完美平衡，保留最佳视听体验"
        case .high: return "超高保真，极细微画质损耗"
        case .custom: return "自由调整分辨率与比特率"
        }
    }
}

/// 视频压缩的详细配置参数
public struct CompressionSettings: Codable, Equatable {
    public var preset: CompressionPreset
    public var codec: VideoCodec
    public var resolutionScale: CGFloat // 0.1 ~ 1.0 (比例)
    public var frameRate: Int // 0 表示保持原样，或者 24, 30, 60
    public var compressAudio: Bool
    public var audioBitrate: Double // 比特率 (bps)
    public var customVideoBitrateMultiplier: Double // 自定义比特率系数 (0.1 ~ 2.0)，默认为 1.0
    
    public init(
        preset: CompressionPreset = .standard,
        codec: VideoCodec = .hevc,
        resolutionScale: CGFloat = 0.75,
        frameRate: Int = 30,
        compressAudio: Bool = true,
        audioBitrate: Double = 128_000,
        customVideoBitrateMultiplier: Double = 1.0
    ) {
        self.preset = preset
        self.codec = codec
        self.resolutionScale = resolutionScale
        self.frameRate = frameRate
        self.compressAudio = compressAudio
        self.audioBitrate = audioBitrate
        self.customVideoBitrateMultiplier = customVideoBitrateMultiplier
    }
    
    /// 获取当前预设对应的默认设置
    public static func settings(for preset: CompressionPreset) -> CompressionSettings {
        switch preset {
        case .extreme:
            return CompressionSettings(
                preset: .extreme,
                codec: .hevc,
                resolutionScale: 0.50, // 540p/720p 级别
                frameRate: 24,         // 降低帧率
                compressAudio: true,
                audioBitrate: 64_000,  // 音频极限压缩
                customVideoBitrateMultiplier: 0.5 // 比特率系数非常低
            )
        case .standard:
            return CompressionSettings(
                preset: .standard,
                codec: .hevc,
                resolutionScale: 0.75, // 约 1080p 级别
                frameRate: 30,
                compressAudio: true,
                audioBitrate: 128_000, // 高质量 AAC
                customVideoBitrateMultiplier: 1.0 // 黄金平衡点
            )
        case .high:
            return CompressionSettings(
                preset: .high,
                codec: .hevc,
                resolutionScale: 1.0,  // 保持原分辨率
                frameRate: 0,          // 保持原帧率
                compressAudio: true,
                audioBitrate: 192_000, // 高保真音频
                customVideoBitrateMultiplier: 1.6 // 高比特率确保无损感
            )
        case .custom:
            return CompressionSettings(
                preset: .custom,
                codec: .hevc,
                resolutionScale: 0.75,
                frameRate: 30,
                compressAudio: true,
                audioBitrate: 128_000,
                customVideoBitrateMultiplier: 1.0
            )
        }
    }
}
