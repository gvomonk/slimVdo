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
    
    @Published public private(set) var totalDiskSpace: Int64 = 64 * 1024 * 1024 * 1024
    @Published public private(set) var freeDiskSpace: Int64 = 20 * 1024 * 1024 * 1024
    @Published public private(set) var photoCount: Int = 0
    @Published public private(set) var videoCount: Int = 0
    
    // 分类占用
    @Published public private(set) var estimatedPhotosSize: Int64 = 0
    @Published public private(set) var estimatedVideosSize: Int64 = 0
    
    public static let shared = StorageAnalyzer()
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        refreshStorageInfo()
    }
    
    /// 向上对齐到标准的 iPhone 商业容量
    private func roundToMarketedCapacity(_ bytes: Int64) -> Int64 {
        let gb = Double(bytes) / (1024.0 * 1024.0 * 1024.0)
        let standardCapacities: [Double] = [8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096]
        
        for cap in standardCapacities {
            if gb <= cap * 1.1 {
                return Int64(cap * 1024 * 1024 * 1024)
            }
        }
        return bytes
    }
    
    /// 触发重新分析物理容量和相册媒体分布
    public func refreshStorageInfo() {
        let fileManager = FileManager.default
        if let docURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).last {
            do {
                let values = try docURL.resourceValues(forKeys: [
                    .volumeTotalCapacityKey,
                    .volumeAvailableCapacityForImportantUsageKey
                ])
                if let total = values.volumeTotalCapacity {
                    self.totalDiskSpace = roundToMarketedCapacity(Int64(total))
                }
                if let free = values.volumeAvailableCapacityForImportantUsage {
                    self.freeDiskSpace = free
                }
            } catch {
                print("⚠️ Volume resource values failed: \(error)")
                let path = NSHomeDirectory()
                if let attrs = try? fileManager.attributesOfFileSystem(forPath: path) {
                    if let space = attrs[.systemSize] as? Int64 {
                        self.totalDiskSpace = roundToMarketedCapacity(space)
                    }
                    if let free = attrs[.systemFreeSize] as? Int64 {
                        self.freeDiskSpace = free
                    }
                }
            }
        }
        
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited {
            self.scanPhotoLibrary()
        } else {
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
    
    /// 系统及其他 App 占用空间
    public var otherAppSpace: Int64 {
        let mediaSum = estimatedPhotosSize + estimatedVideosSize
        return max(0, usedDiskSpace - mediaSum)
    }
    
    /// 全量遍历扫描系统相册，精确计算每张照片和每个视频的物理文件大小
    private func scanPhotoLibrary() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let options = PHFetchOptions()
            let photos = PHAsset.fetchAssets(with: .image, options: options)
            let videos = PHAsset.fetchAssets(with: .video, options: options)
            
            let pCount = photos.count
            let vCount = videos.count
            
            // 全量遍历所有照片，精确累加每张的物理 fileSize
            var totalPhotoBytes: Int64 = 0
            for i in 0..<pCount {
                let asset = photos.object(at: i)
                let resources = PHAssetResource.assetResources(for: asset)
                if let size = (resources.first?.value(forKey: "fileSize") as? NSNumber)?.int64Value {
                    totalPhotoBytes += size
                }
            }
            
            // 全量遍历所有视频，精确累加每个的物理 fileSize
            var totalVideoBytes: Int64 = 0
            for i in 0..<vCount {
                let asset = videos.object(at: i)
                let resources = PHAssetResource.assetResources(for: asset)
                if let size = (resources.first?.value(forKey: "fileSize") as? NSNumber)?.int64Value {
                    totalVideoBytes += size
                }
            }
            
            DispatchQueue.main.async {
                self.photoCount = pCount
                self.videoCount = vCount
                self.estimatedPhotosSize = totalPhotoBytes
                self.estimatedVideosSize = totalVideoBytes
            }
        }
    }
}
