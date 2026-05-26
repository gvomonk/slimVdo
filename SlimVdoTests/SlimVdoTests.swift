//
//  SlimVdoTests.swift
//  SlimVdoTests
//
//  Created by Antigravity on 2026/5/25.
//

import XCTest
@testable import SlimVdo

final class SlimVdoTests: XCTestCase {
    
    override func setUpWithError() throws {
        super.setUp()
        // 每个测试前重置历史数据，保证测试隔离性
        StorageHistoryService.shared.clearHistory()
    }
    
    override func tearDownWithError() throws {
        StorageHistoryService.shared.clearHistory()
        super.tearDown()
    }
    
    // MARK: - 1. 预设参数检验测试
    
    func testPresetSettings() {
        // 验证标准平衡预设
        let standardSettings = CompressionSettings.settings(for: .standard)
        XCTAssertEqual(standardSettings.preset, .standard)
        XCTAssertEqual(standardSettings.codec, .hevc)
        XCTAssertEqual(standardSettings.resolutionScale, 0.75)
        XCTAssertEqual(standardSettings.frameRate, 30)
        XCTAssertTrue(standardSettings.compressAudio)
        XCTAssertEqual(standardSettings.audioBitrate, 128_000)
        XCTAssertEqual(standardSettings.customVideoBitrateMultiplier, 1.0)
        
        // 验证极限压缩预设
        let extremeSettings = CompressionSettings.settings(for: .extreme)
        XCTAssertEqual(extremeSettings.preset, .extreme)
        XCTAssertEqual(extremeSettings.resolutionScale, 0.50)
        XCTAssertEqual(extremeSettings.frameRate, 24)
        XCTAssertEqual(extremeSettings.audioBitrate, 64_000)
        XCTAssertEqual(extremeSettings.customVideoBitrateMultiplier, 0.5)
        
        // 验证极致高清预设
        let highSettings = CompressionSettings.settings(for: .high)
        XCTAssertEqual(highSettings.preset, .high)
        XCTAssertEqual(highSettings.resolutionScale, 1.0)
        XCTAssertEqual(highSettings.frameRate, 0) // 保持原样
        XCTAssertEqual(highSettings.audioBitrate, 192_000)
        XCTAssertEqual(highSettings.customVideoBitrateMultiplier, 1.6)
    }
    
    // MARK: - 2. 存储历史累计计算测试
    
    func testStorageHistoryCalculations() {
        let service = StorageHistoryService.shared
        XCTAssertEqual(service.totalCompressedCount, 0)
        XCTAssertEqual(service.totalBytesSaved, 0)
        XCTAssertEqual(service.averageReductionRatio, 0.0)
        
        // 模拟添加第一条压缩记录：100MB 压缩到 30MB (节省 70MB, 70%)
        let record1 = CompressionRecord(
            videoTitle: "test1.mp4",
            originalSize: 100 * 1024 * 1024,
            compressedSize: 30 * 1024 * 1024,
            duration: 15.0,
            compressionDuration: 2.5,
            resolutionBefore: "1920x1080",
            resolutionAfter: "1280x720",
            codecUsed: "HEVC"
        )
        
        let expectation = XCTestExpectation(description: "Wait for main queue updates")
        
        service.addRecord(record1)
        
        // 延迟等 DispatchQueue.main 异步更新
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(service.totalCompressedCount, 1)
            XCTAssertEqual(service.totalBytesSaved, 70 * 1024 * 1024)
            XCTAssertEqual(service.averageReductionRatio, 0.70)
            
            // 模拟添加第二条压缩记录：200MB 压缩到 20MB (节省 180MB, 复合后 300MB -> 50MB, 节省 250MB, 83.3%)
            let record2 = CompressionRecord(
                videoTitle: "test2.mp4",
                originalSize: 200 * 1024 * 1024,
                compressedSize: 20 * 1024 * 1024,
                duration: 45.0,
                compressionDuration: 5.0,
                resolutionBefore: "3840x2160",
                resolutionAfter: "1920x1080",
                codecUsed: "HEVC"
            )
            
            service.addRecord(record2)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                XCTAssertEqual(service.totalCompressedCount, 2)
                XCTAssertEqual(service.totalBytesSaved, 250 * 1024 * 1024)
                XCTAssertEqual(service.totalOriginalBytes, 300 * 1024 * 1024)
                XCTAssertEqual(service.totalCompressedBytes, 50 * 1024 * 1024)
                XCTAssertEqual(String(format: "%.3f", service.averageReductionRatio), "0.833") // 250/300 = 83.33%
                
                // 测试删除某条记录
                service.deleteRecord(id: record1.id)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    XCTAssertEqual(service.totalCompressedCount, 1)
                    XCTAssertEqual(service.totalBytesSaved, 180 * 1024 * 1024)
                    XCTAssertEqual(service.averageReductionRatio, 0.90) // 180/200 = 90%
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - 3. 比特率体积预测器准确性及边界值测试
    
    func testOutputSizeEstimator() {
        // 场景 A: 空数据边界情况检验
        let zeroEstimate = VideoCompressor.estimateOutputSize(
            originalSize: 0,
            settings: .settings(for: .standard),
            originalDuration: 0,
            originalWidth: 0,
            originalHeight: 0,
            originalFPS: 0
        )
        XCTAssertEqual(zeroEstimate, 0)
        
        // 场景 B: 标准平衡预设 (HEVC, Scale 0.75, Original Size 100MB, 30s 视频)
        let originalSize: Int64 = 100 * 1024 * 1024 // 100MB
        let settings = CompressionSettings.settings(for: .standard)
        
        let estimate = VideoCompressor.estimateOutputSize(
            originalSize: originalSize,
            settings: settings,
            originalDuration: 30.0,
            originalWidth: 1920,
            originalHeight: 1080,
            originalFPS: 30.0
        )
        
        // 校验预测值应该显著小于原视频大小，但受到安全下限保护（最低不低于 5%）
        XCTAssertTrue(estimate < originalSize)
        XCTAssertTrue(estimate > Int64(Double(originalSize) * 0.05))
        
        // 场景 C: 极限安全值上边界校验
        // 如果自定义设置了极高的码率比率 (例如 Multiplier = 2.0x, Scale = 1.0, 保持 H.264 无损)
        let crazySettings = CompressionSettings(
            preset: .custom,
            codec: .h264,
            resolutionScale: 1.0,
            frameRate: 0,
            compressAudio: true,
            audioBitrate: 192_000,
            customVideoBitrateMultiplier: 2.0
        )
        
        let giantEstimate = VideoCompressor.estimateOutputSize(
            originalSize: originalSize,
            settings: crazySettings,
            originalDuration: 10.0,
            originalWidth: 1920,
            originalHeight: 1080,
            originalFPS: 30.0
        )
        
        // 验证安全上限保护触发：无论用户怎么拖滑块，估算体积绝不能超过原始大小的 90%
        XCTAssertEqual(giantEstimate, Int64(Double(originalSize) * 0.90))
    }
    
    // MARK: - 4. 照片压缩预设检验测试
    
    func testPhotoPresetSettings() {
        // 验证照片标准平衡预设
        let standardSettings = PhotoCompressionSettings.settings(for: .standard)
        XCTAssertEqual(standardSettings.preset, .standard)
        XCTAssertEqual(standardSettings.format, .heic)
        XCTAssertEqual(standardSettings.resolutionScale, 0.8)
        XCTAssertEqual(standardSettings.compressionQuality, 0.75)
        XCTAssertTrue(standardSettings.keepMetadata)
        
        // 验证照片极限压缩预设
        let extremeSettings = PhotoCompressionSettings.settings(for: .extreme)
        XCTAssertEqual(extremeSettings.preset, .extreme)
        XCTAssertEqual(extremeSettings.resolutionScale, 0.5)
        XCTAssertEqual(extremeSettings.compressionQuality, 0.55)
        
        // 验证照片极致高清预设
        let highSettings = PhotoCompressionSettings.settings(for: .high)
        XCTAssertEqual(highSettings.preset, .high)
        XCTAssertEqual(highSettings.resolutionScale, 1.0)
        XCTAssertEqual(highSettings.compressionQuality, 0.88)
    }
    
    // MARK: - 5. 照片体积估算与边界检验测试
    
    @MainActor
    func testPhotoOutputSizeEstimator() {
        let viewModel = PhotoCompressionViewModel()
        viewModel.originalSize = 50 * 1024 * 1024 // 50MB
        viewModel.codecUsed = "JPEG (传统格式)"
        
        // 测试标准 HEIC 预设 (JPEG -> HEIC 应该享受额外的体积折半红利)
        viewModel.settings = PhotoCompressionSettings.settings(for: .standard)
        let standardEstimate = viewModel.estimatedSize
        
        XCTAssertTrue(standardEstimate < viewModel.originalSize)
        XCTAssertTrue(standardEstimate > Int64(Double(viewModel.originalSize) * 0.05))
        
        // 测试极限压缩预设 (下采样 0.5 + 质量 0.55 + HEIC 折半)
        viewModel.settings = PhotoCompressionSettings.settings(for: .extreme)
        let extremeEstimate = viewModel.estimatedSize
        XCTAssertTrue(extremeEstimate < standardEstimate)
    }
}

