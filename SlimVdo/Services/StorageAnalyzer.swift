//
//  StorageAnalyzer.swift
//  SlimVdo
//
//  Created by Antigravity on 2026/5/25.
//

import Foundation
import Photos
import Combine

/// 手机真实存储空间分析服务
public final class StorageAnalyzer: ObservableObject {
    
    @Published public private(set) var totalDiskSpace: Int64 = 64 * 1024 * 1024 * 1024 // 默认 64GB
    @Published public private(set) var freeDiskSpace: Int64 = 20 * 1024 * 1024 * 1024  // 默认 20GB
    @Published public private(set) var photoCount: Int = 0
    @Published public private(set) var videoCount: Int = 0
    
    // 分类占用估计
    @Published public private(set) var estimatedPhotosSize: Int64 = 0
    @Published public private(set) var estimatedVideosSize: Int64 = 0
    
    public static let shared = StorageAnalyzer()
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        refreshStorageInfo()
    }
    
    /// 触发重新分析物理容量和相册媒体分布
    public func refreshStorageInfo() {
        // 1. 获取系统真实物理磁盘大小
        let path = NSHomeDirectory()
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: path)
            if let space = attrs[.systemSize] as? Int64 {
                self.totalDiskSpace = space
            }
            if let free = attrs[.systemFreeSize] as? Int64 {
                self.freeDiskSpace = free
            }
        } catch {
            print("⚠️ 无法获取真实设备容量: \(error.localizedDescription)")
        }
        
        // 2. 检查照片库授权并统计张数个数
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited {
            self.scanPhotoLibrary()
        } else {
            // 没有权限则请求权限并统计
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    self?.scanPhotoLibrary()
                }
            }
        }
    }
    
    /// 实际已使用空间
    public var usedDiskSpace: Int64 {
        return max(0, totalDiskSpace - freeDiskSpace)
    }
    
    /// 系统及其他 App 占用空间 (已用空间扣除相册后)
    public var otherAppSpace: Int64 {
        let mediaSum = estimatedPhotosSize + estimatedVideosSize
        return max(0, usedDiskSpace - mediaSum)
    }
    
    /// 扫描系统相册
    private func scanPhotoLibrary() {
        // Photos 框架的 fetch 方法在后台查询非常迅速，返回的是元数据列表，不占用内存
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 极速获取照片与视频资产总数
            let photos = PHAsset.fetchAssets(with: .image, options: nil)
            let videos = PHAsset.fetchAssets(with: .video, options: nil)
            
            // 统计数量
            let pCount = photos.count
            let vCount = videos.count
            
            // 智能拟合字节大小
            // 在 iOS 平均场景下，一张普通照片（包含 HEIC/JPEG）约为 3.5MB
            let pEstimatedSize = Int64(pCount) * 3_500_000
            // 一个手机视频平均约为 40MB
            let vEstimatedSize = Int64(vCount) * 40_000_000
            
            // 安全边界处理：确保估计的总和不超出设备已用空间
            let systemUsed = self.usedDiskSpace
            var finalPEst = pEstimatedSize
            var finalVEst = vEstimatedSize
            
            if (pEstimatedSize + vEstimatedSize) > systemUsed {
                // 如果超标，等比压缩拟合值，预留 20% 空间给系统
                let scale = Double(systemUsed) * 0.8 / Double(pEstimatedSize + vEstimatedSize)
                finalPEst = Int64(Double(pEstimatedSize) * scale)
                finalVEst = Int64(Double(vEstimatedSize) * scale)
            }
            
            DispatchQueue.main.async {
                self.photoCount = pCount
                self.videoCount = vCount
                self.estimatedPhotosSize = finalPEst
                self.estimatedVideosSize = finalVEst
            }
        }
    }
}
