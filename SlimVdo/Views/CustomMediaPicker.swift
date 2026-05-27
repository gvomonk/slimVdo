//
//  CustomMediaPicker.swift
//  SlimVdo
//
//  Created by Antigravity on 2026/5/26.
//

import SwiftUI
import Photos

@available(iOS 16.0, *)
struct CustomMediaPicker: View {
    let mediaType: PHAssetMediaType
    let maxSelection: Int
    let onSelect: ([PHAsset]) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    // 媒体资源列表与状态
    @State private var assets: [PHAsset] = []
    @State private var selectedAssets: [PHAsset] = []
    @State private var sizeCache: [String: Int64] = [:]
    @State private var isLoading = true
    
    // 筛选与排序选项
    enum SortOption: String, CaseIterable, Identifiable {
        case sizeDesc = "大小 ⬇️"
        case dateDesc = "日期 ⬇️"
        case dateAsc = "日期 ⬆️"
        
        var id: String { self.rawValue }
    }
    
    @State private var selectedSort: SortOption = .sizeDesc
    @State private var sizeFilterEnabled = false // 过滤开关
    
    private var filteredAndSortedAssets: [PHAsset] {
        var result = assets
        
        // 1. 体积过滤逻辑 (图片 > 5MB, 视频 > 200MB)
        if sizeFilterEnabled {
            result = result.filter { asset in
                let size = sizeCache[asset.localIdentifier] ?? 0
                if mediaType == .image {
                    return size > 5 * 1024 * 1024
                } else {
                    return size > 200 * 1024 * 1024
                }
            }
        }
        
        // 2. 排序逻辑
        switch selectedSort {
        case .dateDesc:
            result.sort { ($0.creationDate ?? Date.distantPast) > ($1.creationDate ?? Date.distantPast) }
        case .dateAsc:
            result.sort { ($0.creationDate ?? Date.distantPast) < ($1.creationDate ?? Date.distantPast) }
        case .sizeDesc:
            result.sort {
                let s1 = sizeCache[$0.localIdentifier] ?? 0
                let s2 = sizeCache[$1.localIdentifier] ?? 0
                return s1 > s2
            }
        }
        
        return result
    }
    
    // 瀑布流布局列
    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 8)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(isDarkMode ? Color(red: 0.05, green: 0.05, blue: 0.08) : Color(red: 0.96, green: 0.96, blue: 0.98))
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 1. 顶部控制栏 (排序与筛选按钮，极致简约苹果相册风格)
                    HStack(spacing: 16) {
                        // 1. 排序 Menu 下拉按钮
                        Menu {
                            Picker("排序", selection: $selectedSort) {
                                ForEach(SortOption.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("排序: \(selectedSort.rawValue)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.05))
                            .cornerRadius(12)
                        }
                        
                        Spacer()
                        
                        // 2. 筛选 Menu 下拉按钮
                        Menu {
                            Button(action: {
                                sizeFilterEnabled = false
                            }) {
                                HStack {
                                    Text("全部显示")
                                    if !sizeFilterEnabled {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            
                            Button(action: {
                                sizeFilterEnabled = true
                            }) {
                                HStack {
                                    Text(mediaType == .image ? "仅显示大文件 (>5MB)" : "仅显示大文件 (>200MB)")
                                    if sizeFilterEnabled {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(sizeFilterEnabled ? "筛选: 大文件" : "筛选: 全部")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Image(systemName: "line.3.horizontal.decrease.circle" + (sizeFilterEnabled ? ".fill" : ""))
                                    .font(.subheadline)
                            }
                            .foregroundColor(sizeFilterEnabled ? (mediaType == .image ? .blue : .purple) : (isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8)))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(sizeFilterEnabled ? (mediaType == .image ? Color.blue.opacity(0.12) : Color.purple.opacity(0.12)) : (isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.05)))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: mediaType == .image ? .blue : .purple))
                                .scaleEffect(1.3)
                            Text("正在快速读取设备媒体库...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxHeight: .infinity)
                    } else if filteredAndSortedAssets.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("未发现符合筛选条件的媒体")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        // 2. 媒体图片网格瀑布流
                        ScrollView(.vertical, showsIndicators: true) {
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(filteredAndSortedAssets, id: \.localIdentifier) { asset in
                                    MediaCell(
                                        asset: asset,
                                        mediaType: mediaType,
                                        isSelected: selectedAssets.contains(asset),
                                        size: sizeCache[asset.localIdentifier] ?? 0,
                                        isDarkMode: isDarkMode,
                                        onTap: {
                                            toggleSelection(asset)
                                        }
                                    )
                                    .task {
                                        // 惰性加载：只有当网格单元显示在屏幕上时，才异步提取文件大小并加入缓存
                                        if sizeCache[asset.localIdentifier] == nil {
                                            let size = await fetchAssetSize(asset)
                                            DispatchQueue.main.async {
                                                sizeCache[asset.localIdentifier] = size
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle(mediaType == .image ? "选择照片" : "选择视频")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(selectedAssets.isEmpty ? "确定" : "确定(\(selectedAssets.count))") {
                        onSelect(selectedAssets)
                        dismiss()
                    }
                    .foregroundColor(mediaType == .image ? .blue : .purple)
                    .fontWeight(.bold)
                    .disabled(selectedAssets.isEmpty)
                }
            }
            .task {
                await loadAssets()
            }
        }
    }
    
    // MARK: - 逻辑与提取方法
    
    private func loadAssets() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            await MainActor.run {
                isLoading = false
            }
            return
        }
        
        // 1. 获取资源列表
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let fetchResult = PHAsset.fetchAssets(with: self.mediaType, options: options)
        var list: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            list.append(asset)
        }
        
        await MainActor.run {
            self.assets = list
        }
        
        // 2. 利用 TaskGroup 开启多协程物理文件体积并发预加载，实现毫秒级瞬间获取
        let allAssets = list
        let sizes = await withTaskGroup(of: (String, Int64).self, returning: [String: Int64].self) { group in
            for asset in allAssets {
                group.addTask {
                    let resources = PHAssetResource.assetResources(for: asset)
                    let size = (resources.first?.value(forKey: "fileSize") as? NSNumber)?.int64Value ?? 0
                    return (asset.localIdentifier, size)
                }
            }
            
            var dict: [String: Int64] = [:]
            for await (identifier, size) in group {
                dict[identifier] = size
            }
            return dict
        }
        
        await MainActor.run {
            self.sizeCache = sizes
            self.isLoading = false
        }
    }
    
    private func toggleSelection(_ asset: PHAsset) {
        if let idx = selectedAssets.firstIndex(of: asset) {
            selectedAssets.remove(at: idx)
        } else {
            if selectedAssets.count < maxSelection {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    selectedAssets.append(asset)
                }
            }
        }
    }
    
    /// 高效异步提取 PHAsset 文件真实体积 (毫秒级直读)
    private func fetchAssetSize(_ asset: PHAsset) async -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        if let first = resources.first {
            let size = (first.value(forKey: "fileSize") as? NSNumber)?.int64Value ?? 0
            return size
        }
        return 0
    }
}

// MARK: - 媒体网格单项 Cell

@available(iOS 16.0, *)
struct MediaCell: View {
    let asset: PHAsset
    let mediaType: PHAssetMediaType
    let isSelected: Bool
    let size: Int64
    var isDarkMode: Bool
    let onTap: () -> Void
    
    @State private var thumbnail: UIImage?
    
    private var sizeString: String {
        guard size > 0 else { return "-- MB" }
        let doubleBytes = Double(size)
        if doubleBytes >= 1024 * 1024 * 1024 {
            return String(format: "%.1f GB", doubleBytes / (1024 * 1024 * 1024))
        } else if doubleBytes >= 1024 * 1024 {
            return String(format: "%.1f MB", doubleBytes / (1024 * 1024))
        } else {
            return String(format: "%.1f KB", doubleBytes / 1024)
        }
    }
    
    private var durationString: String {
        let totalSeconds = Int(asset.duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private var sizeColor: Color {
        if size == 0 {
            return .gray.opacity(0.8)
        }
        if mediaType == .image {
            return size > 5 * 1024 * 1024 ? Color(red: 1.0, green: 0.4, blue: 0.4) : Color.white.opacity(0.8)
        } else {
            return size > 200 * 1024 * 1024 ? Color(red: 1.0, green: 0.4, blue: 0.4) : Color.white.opacity(0.8)
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomTrailing) {
                // 1. 照片缩略图
                if let img = thumbnail {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 106, height: 106)
                        .clipped()
                        .cornerRadius(12)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isDarkMode ? Color.white.opacity(0.04) : Color.black.opacity(0.04))
                        .frame(width: 106, height: 106)
                }
                
                // 2. 勾选状态遮罩与 Checkmark
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .fill((mediaType == .image ? Color.blue : Color.purple).opacity(0.3))
                        .frame(width: 106, height: 106)
                    
                    VStack {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                                .shadow(radius: 4)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(6)
                }
                
                // 3. 右下角物理大小与时长标签 (如果是视频，双指标融合展示，效果优雅和谐)
                HStack(spacing: 4) {
                    if mediaType == .video && asset.duration > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 6.5, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                            Text(durationString)
                                .font(.system(size: 8.5, weight: .black, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    
                    Text(sizeString)
                        .font(.system(size: 8.5, weight: .black, design: .rounded))
                        .foregroundColor(sizeColor)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3.5)
                .background(Color.black.opacity(0.65))
                .cornerRadius(6)
                .padding(6)
            }
        }
        .task {
            // 异步从 PHCachingImageManager 中低开销读取缩略图
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.isSynchronous = false
            
            manager.requestImage(
                for: asset,
                targetSize: CGSize(width: 150, height: 150),
                contentMode: .aspectFill,
                options: options
            ) { img, _ in
                DispatchQueue.main.async {
                    self.thumbnail = img
                }
            }
        }
    }
}
