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
    
    nonisolated public var identifier: String {
        switch self {
        case .h264: return "avc1"
        case .hevc: return "hvc1"
        }
    }
}

/// 支持的视频输出容器格式
public enum VideoContainerFormat: String, Codable, CaseIterable {
    case mp4 = "MP4"
    case mov = "MOV"
    
    nonisolated public var pathExtension: String {
        switch self {
        case .mp4: return "mp4"
        case .mov: return "mov"
        }
    }
}

/// 预设档位（百分比代表目标文件大小占原始大小的比例）
public enum CompressionPreset: String, Codable, CaseIterable, Identifiable {
    case p85 = "85%"
    case p70 = "70%"
    case p50 = "50%"
    case p30 = "30%"
    case p15 = "15%"
    case custom = "自定义"
    
    public var id: String { self.rawValue }
    
    public var displayName: String { self.rawValue }
}

/// 视频压缩的详细配置参数
public struct CompressionSettings: Codable, Equatable {
    public var preset: CompressionPreset
    public var codec: VideoCodec
    public var outputFormat: VideoContainerFormat // 输出容器格式
    public var resolutionScale: CGFloat // 0.1 ~ 1.0 (比例)
    public var frameRate: Int // 0 表示保持原样，或者 24, 30, 60
    public var compressAudio: Bool
    public var audioBitrate: Double // 比特率 (bps)
    public var customVideoBitrateMultiplier: Double // 自定义比特率系数 (0.1 ~ 2.0)
    public var keepMetadata: Bool // 是否保留元数据（拍摄日期、GPS等）
    
    public init(
        preset: CompressionPreset = .p70,
        codec: VideoCodec = .hevc,
        outputFormat: VideoContainerFormat = .mp4,
        resolutionScale: CGFloat = 0.75,
        frameRate: Int = 0,
        compressAudio: Bool = false,
        audioBitrate: Double = 128_000,
        customVideoBitrateMultiplier: Double = 1.0,
        keepMetadata: Bool = true
    ) {
        self.preset = preset
        self.codec = codec
        self.outputFormat = outputFormat
        self.resolutionScale = resolutionScale
        self.frameRate = frameRate
        self.compressAudio = compressAudio
        self.audioBitrate = audioBitrate
        self.customVideoBitrateMultiplier = customVideoBitrateMultiplier
        self.keepMetadata = keepMetadata
    }
    
    /// 获取当前预设对应的默认设置
    public static func settings(for preset: CompressionPreset) -> CompressionSettings {
        switch preset {
        case .p85:
            return CompressionSettings(
                preset: .p85,
                codec: .hevc,
                resolutionScale: 1.0,
                frameRate: 0,
                compressAudio: false,
                audioBitrate: 128_000,
                customVideoBitrateMultiplier: 0.85
            )
        case .p70:
            return CompressionSettings(
                preset: .p70,
                codec: .hevc,
                resolutionScale: 1.0,
                frameRate: 0,
                compressAudio: false,
                audioBitrate: 128_000,
                customVideoBitrateMultiplier: 0.65
            )
        case .p50:
            return CompressionSettings(
                preset: .p50,
                codec: .hevc,
                resolutionScale: 0.75,
                frameRate: 30,
                compressAudio: false,
                audioBitrate: 128_000,
                customVideoBitrateMultiplier: 0.50
            )
        case .p30:
            return CompressionSettings(
                preset: .p30,
                codec: .hevc,
                resolutionScale: 0.60,
                frameRate: 30,
                compressAudio: false,
                audioBitrate: 96_000,
                customVideoBitrateMultiplier: 0.30
            )
        case .p15:
            return CompressionSettings(
                preset: .p15,
                codec: .hevc,
                resolutionScale: 0.50,
                frameRate: 24,
                compressAudio: false,
                audioBitrate: 64_000,
                customVideoBitrateMultiplier: 0.15
            )
        case .custom:
            return CompressionSettings(
                preset: .custom,
                codec: .hevc,
                resolutionScale: 0.75,
                frameRate: 0,
                compressAudio: false,
                audioBitrate: 128_000,
                customVideoBitrateMultiplier: 1.0
            )
        }
    }
}
