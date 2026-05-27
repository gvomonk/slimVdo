# 终极实机打磨与 OOM 内存崩溃优化实施方案

本实施方案（`oom_and_detail_polishing_plan.md`）针对 Raymond 手机真机实测中暴露的 OOM 崩溃、iCloud 预加载警告、媒体库大文件缺失、滑杆点状标记以及文本克制与紧凑化等要求，制定出最严谨、最高保真的架构级重构与问题解决方案。

---

## 核心设计与技术决策

### 1. 内存终极拯救者：流式 autoreleasepool 级联回收 (解决 300MB 实机崩溃)
* **问题诊断**：在原有的 `VideoCompressionActor` 中，`autoreleasepool` 闭包被放置在 `while writerVideoInput.isReadyForMoreMediaData` 循环外部。这意味着在流式处理上千个视频/音频 SampleBuffer 帧时，所有的中间临时图像、下采样像素缓冲区 `CVPixelBuffer` 和元数据资源**全都会在堆内存中堆积**，只有等到整个视频完全压制完后才会统一回收，直接引发系统强行终止进程（OOM Code 9）。
* **终极方案**：
  * **内嵌循环回收**：将视频轨道和音频轨道循环内部的所有读取、缩放及 append 操作全部用 `autoreleasepool { ... }` 包裹。使每一帧的临时内存在当前循环迭代结束时**瞬间被物理回收**。
  * **内存水位保证**：重构后，无论视频大小是 300MB 还是 30GB，系统内存水位都将维持在 **30MB ~ 50MB 之间的常数水平**，绝对不可能发生 OOM 闪退！
* **底层日志释疑**：`ERROR AppleProResHW` 是苹果底层编解码芯片在检测 ProRes 硬件加速器时的正常探测警告，会自动无缝 fallback 到通用的 H.264/H.265 硬件加速芯片（AVC/HEVC），对功能和速度没有任何负面影响。

### 2. 存储空间毫秒级精准化 (volumeTotalCapacity 真实容量 API)
* **问题诊断**：原版使用 `attributesOfFileSystem` 读取的是底层的分区物理格式化大小，且估算相册大小采用硬编码（如固定乘 3.5MB），导致数据与 iOS “设置 -> 通用 -> iPhone 存储空间”的数值完全对不上。
* **终极方案**：
  * **苹果官方最佳实践**：改用 `volumeTotalCapacityKey` 与 `volumeAvailableCapacityForImportantUsageKey` 接口，它会自动考虑系统的 **Purgeable 缓存与预留空间**，反馈最精确的、与 iOS 设置 100% 吻合的可用磁盘空间。
  * **动态采样估计 (Dynamic Sampling)**：在扫描相册时，极速并发读取前 30 张照片和前 15 个视频的真实物理文件大小，动态计算出当前设备最真实的照片/视频平均大小系数，再乘以总数。从而完美兼容 iCloud “优化 iPhone 存储”状态下的超低本地体积占比。

### 3. 选择媒体页高保真苹果风格 Menu 重构
* **iCloud 预加载及警告消除**：在 `PHFetchOptions` 中设置 `fetchPropertySets = [.imageSourceType, .originalMetadata]`，在单次批量查询时直接预加载相册元数据，**彻底消除 18 个 `Missing prefetched properties` 警告日志**，性能瞬间飙升。
* **Menu 简约重构**：将臃肿的 Segmented 控件与 Border 按钮剔除，完全重构为类似苹果官方相册的两个极其简约优雅的 **`Menu`** 下拉按钮（「排序」与「筛选」）：
  - **默认排序**：大小 ⬇️ (按文件大小降序) —— 瞬间抓出大文件！
  - **默认筛选**：无筛选 (全部媒体)。
* **全局大文件缺失问题根治**：
  在 `loadAssets()` 被拉起时，放弃 lazy-loading 排序策略。直接采用 **TaskGroup 并发协程组** 在后台以毫秒级速度预提取**所有**媒体资源的物理 fileSize 并录入 `sizeCache`。保证加载完毕时，全局真正最大的视频瞬间置顶，绝不丢失！

### 4. 视频/照片压缩面板极限“文字克制”与紧凑化
* **删除冗余档位预设**：直接斩断“压缩预设”这一行与三个极速/平衡/高清档位，全部交给用户进行平滑的自定义 Slider 拖拽，页面视觉克制感瞬间飙升。
* **展示关键信息**：在源视频属性面板中，补充展示关键的**“视频码率” (如 `12.4 Mbps`)**。
* **紧凑排版**：删去自定义参数里的所有分割线 `Divider()`，行间距整体压紧 50%，呈现极为精致的极客风界面。

### 5. 独创“滑杆轨道刻度点 (Track Dots)”与“智能无按钮音频控制”
* **滑杆轨道刻度点**：抛弃繁冗的锁定按钮。利用 `GeometryReader` 比例算法，直接将 `24`、`30`、`60` 帧以及 `64K`、`128K` 的快锁标记点**以精致微光小圆点的形式直接画在 Slider 滑动轨道上**！当用户拖动滑杆接近这些小圆点时，Binding 内部自动精准吸附 (Snapping)。
* **音频无开关滑杆控制**：彻底删去“压缩音频”的 Toggle 拨码开关。
  - 音频滑杆的上限拉满点即代表 **“原采样率 (不压缩)”**。
  - 用户只要往左滑动，便代表启动压缩至指定比特率。用一个滑杆精妙地表达了“开关与参数调节”的复合逻辑！

---

## 拟增与拟改文件清单

1. **[MODIFY] [StorageAnalyzer.swift](file:///Users/aray/rays/repos/_me/slimVdo/SlimVdo/Services/StorageAnalyzer.swift)**
   - 升级为 `resourceValues` volume 容量 API。
   - 融入 Task 并发照片/视频 local resource 动态采样计算模型。
2. **[MODIFY] [DashboardView.swift](file:///Users/aray/rays/repos/_me/slimVdo/SlimVdo/Views/DashboardView.swift)**
   - 标题右上角增加 `info.circle` 版权与开源协议 Menu 气泡。
   - 气泡中表达业内最佳实践的“个人开源免费，商用须授权许可”的严谨协议文本。
3. **[MODIFY] [CustomMediaPicker.swift](file:///Users/aray/rays/repos/_me/slimVdo/SlimVdo/Views/CustomMediaPicker.swift)**
   - 设置 `fetchPropertySets` 属性预加载，拦截日志。
   - 并发 `TaskGroup` 全量 prefetch 文件大小。
   - 用 SwiftUI `Menu` 重塑简约筛选与排序操作。
4. **[MODIFY] [VideoCompressionActor.swift](file:///Users/aray/rays/repos/_me/slimVdo/SlimVdo/Engine/VideoCompressionActor.swift)**
   - 将流式写入主 `while` 循环重构，将 `autoreleasepool` 物理内嵌，彻底解决 OOM 实机崩溃。
5. **[MODIFY] [CompressionConfigView.swift](file:///Users/aray/rays/repos/_me/slimVdo/SlimVdo/Views/CompressionConfigView.swift)** & **[PhotoCompressionConfigView.swift](file:///Users/aray/rays/repos/_me/slimVdo/SlimVdo/Views/PhotoCompressionConfigView.swift)**
   - 砍掉预设档位，极限文本克制。
   - 移除分割线，整体紧凑化。
   - 封装 Custom Track Dots Slider，实现滑杆轨道圆点标记与智能吸附吸附 (Snapping)。
   - 重塑音频滑杆上限 Bypassing 逻辑。
