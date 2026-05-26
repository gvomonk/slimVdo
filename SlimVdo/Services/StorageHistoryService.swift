//
//  StorageHistoryService.swift
//  SlimVdo
//
//  Created by Antigravity on 2026/5/25.
//

import Foundation
import Combine

/// 压缩历史记录模型
public struct CompressionRecord: Codable, Identifiable, Equatable {
    public let id: UUID
    public let videoTitle: String
    public let originalSize: Int64        // 原始字节数
    public let compressedSize: Int64      // 压缩后字节数
    public let duration: TimeInterval     // 视频时长 (秒)
    public let compressionDuration: TimeInterval // 压缩耗时 (秒)
    public let timestamp: Date
    public let resolutionBefore: String   // 压缩前分辨率 (如 "3840x2160")
    public let resolutionAfter: String    // 压缩后分辨率 (如 "1920x1080")
    public let codecUsed: String          // 使用的编码格式 (H.264/HEVC)
    
    public init(
        id: UUID = UUID(),
        videoTitle: String,
        originalSize: Int64,
        compressedSize: Int64,
        duration: TimeInterval,
        compressionDuration: TimeInterval,
        timestamp: Date = Date(),
        resolutionBefore: String,
        resolutionAfter: String,
        codecUsed: String
    ) {
        self.id = id
        self.videoTitle = videoTitle
        self.originalSize = originalSize
        self.compressedSize = compressedSize
        self.duration = duration
        self.compressionDuration = compressionDuration
        self.timestamp = timestamp
        self.resolutionBefore = resolutionBefore
        self.resolutionAfter = resolutionAfter
        self.codecUsed = codecUsed
    }
    
    /// 计算缩减比例 (如 0.85 表示缩减了 85%)
    public var reductionRatio: Double {
        guard originalSize > 0 else { return 0.0 }
        let saved = Double(originalSize - compressedSize)
        return max(0.0, saved / Double(originalSize))
    }
    
    /// 节省的字节数
    public var bytesSaved: Int64 {
        return max(0, originalSize - compressedSize)
    }
}

/// 历史记录持久化服务类
public final class StorageHistoryService: ObservableObject {
    private let userDefaultsKey = "com.slimvdo.compression.history"
    
    @Published public private(set) var records: [CompressionRecord] = []
    
    public static let shared = StorageHistoryService()
    
    private init() {
        loadRecords()
    }
    
    /// 从 UserDefaults 加载数据
    public func loadRecords() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            self.records = []
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let decoded = try decoder.decode([CompressionRecord].self, from: data)
            // 按时间戳倒序排列（最近的排在最前面）
            self.records = decoded.sorted(by: { $0.timestamp > $1.timestamp })
        } catch {
            print("❌ 加载压缩历史记录失败: \(error.localizedDescription)")
            self.records = []
        }
    }
    
    /// 保存记录到 UserDefaults
    private func saveRecordsToPersistentStore() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(records)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("❌ 写入压缩历史记录失败: \(error.localizedDescription)")
        }
    }
    
    /// 新增一条压缩记录
    public func addRecord(_ record: CompressionRecord) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.records.insert(record, at: 0)
            self.saveRecordsToPersistentStore()
        }
    }
    
    /// 删除某一条压缩记录
    public func deleteRecord(id: UUID) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.records.removeAll(where: { $0.id == id })
            self.saveRecordsToPersistentStore()
        }
    }
    
    /// 清空所有历史记录
    public func clearHistory() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.records.removeAll()
            UserDefaults.standard.removeObject(forKey: self.userDefaultsKey)
        }
    }
    
    // MARK: - 统计宏观数据
    
    /// 累计节省的字节总数
    public var totalBytesSaved: Int64 {
        records.reduce(0) { $0 + $1.bytesSaved }
    }
    
    /// 累计原始字节总数
    public var totalOriginalBytes: Int64 {
        records.reduce(0) { $0 + $1.originalSize }
    }
    
    /// 累计压缩后字节总数
    public var totalCompressedBytes: Int64 {
        records.reduce(0) { $0 + $1.compressedSize }
    }
    
    /// 平均空间缩减比率 (如 0.78 表示平均节省了 78% 的体积)
    public var averageReductionRatio: Double {
        let original = totalOriginalBytes
        guard original > 0 else { return 0.0 }
        return Double(totalBytesSaved) / Double(original)
    }
    
    /// 累计压缩成功的视频数
    public var totalCompressedCount: Int {
        records.count
    }
}
