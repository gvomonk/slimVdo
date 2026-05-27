# 终极实施方案 - SlimVdo 极致细节打磨与国际化演进

本实施方案（`final_polish_and_i18n_plan.md`）是在真机实测反馈、排序控制及 iCloud 本地化绝对离线策略基础之上，融合多国 App Store 国际化（Localization）需求所制定的终极设计与落地实施方案。

---

## 核心设计与技术决策

### 1. 极致性能与 0 拷贝 Direct AVAsset 管道
* **现状诊断**：原版使用 `loadTransferable` 会强行让系统在后台将视频转码并拷贝到沙盒 `/tmp`，导致大视频加载时出现好几秒甚至更长的转圈阻塞。
* **终极方案**：放弃 system copying，利用 `PHImageManager.default().requestAVAsset` 异步且直连地获取 Photos 库中视频的 `AVAsset` 对象。对于本地存在的高清原片，直接提取物理 `AVURLAsset` 指向的路径进行硬编压制，免去一切前期拷贝，实现**毫秒级瞬间加载**！
* **强制退出机制**：在所有的 ProgressLoading 界面添加醒目的「返回」按钮，允许用户随时安全中断提取或压缩，退回主屏幕。

### 2. 完全本地定制化「智能媒体拾取器」 (Custom Media Picker)
* **现状诊断**：系统原生的 `PhotosPicker` 是完全运行在独立系统进程中的沙盒视图，我们作为宿主 App **绝对无法**在其中插入任何自定义的“按大小排序”、“按大小筛选”或在图标右下角显示文件体积的功能。
* **终极方案**：采用苹果 `Photos` 框架，在 App 内实现一个极其精美、流线感十足的自定义 **`CustomMediaPicker`** 组件：
  - **精细化三键排序**：支持三个独立的快速排序切换按钮：
    1. **「日期 ⬇️」**（按拍摄日期降序，最新排在最前）
    2. **「日期 ⬆️」**（按拍摄日期升序，最旧排在最前）
    3. **「大小 ⬇️」**（按文件大小降序，体积最大排在最前，一眼抓出大文件）
  - **智能体积筛选**：提供快速过滤器（照片可选「大于 5MB」，视频可选「大于 200MB」），实现精准缩水。
  - **体积智能微标签**：每个媒体网格右下角均以高精度浅色小字展示其真实物理大小；若**照片大于 5MB** 或**视频大于 200MB**，自动渲染为浅红色以示警示。
  - **高性能惰性加载**：大小数据由异步后台任务在 Cell 级别惰性读取并缓存，保证千张照片极速滑动时 0 卡顿。

### 3. iCloud 联网控制与系统网络询问彻底隐匿机制
* **联网提示来源分析**：当应用通过系统底层的 `AVPlayer` 去播放一个存储在 iCloud 且本地尚未完全缓存的高清原片时，`AVPlayer` 底层会自动建立远程网络连接下载流媒体。这会被 iOS 系统识别，从而强制弹出联网权限授权窗口。
* **彻底隐匿与防护机制**：
  - 在获取 `AVAsset` 与图像 `Data` 时，默认将 `PHVideoRequestOptions` / `PHImageRequestOptions` 中的 **`isNetworkAccessAllowed` 显式设置为 `false`**！
  - **效果**：当 App 尝试访问 iCloud 上的未下载媒体时，由于我们禁止了网络访问，Photos 框架会直接返回一个本地未下载的错误，**彻底阻断任何后台静默联网行为，因而绝不会触发系统的联网权限弹窗**！
  - **极致本地体验的绝对离线提示文案**：
    在发生未下载到本地的错误时，系统会弹出如下精确的友好本地化气泡：
    > **“本app被禁止联网\n请放心使用\n（若您正操作的文件在iCloud云端\n请先下载到本地）”**

### 4. 国际化 (Localization) 演进路线规划
为了保障 App 顺利上架多国 App Store，我们在代码中奠定以下最规范的技术设计：
* **多语言资源提取**：所有面向用户的文案及按钮标签均采用标准 SwiftUI 架构中的 `LocalizedStringKey`，为后续本地化 `Localizable.strings` 做好无缝提取准备。
* **弹性 UI 布局 (Flexible UI Layout)**：所有文字容器均不使用硬编码的静态宽度（禁止写死 `.frame(width: 80)`），全部过渡为自适应排版。使用 `HStack`、`VStack` 的弹性间距和 `.minimumScaleFactor(0.5)`，确保在任意长单词语言（如德语、法语等）下都能完美优雅地显示。
* **系统权限提示多语言化**：在 `Info.plist` 的相册读写权限 `NSPhotoLibraryUsageDescription` 中，预留标准的多语言翻译占位，确保权限询问气泡随系统语言自动适配。

### 5. 自定义参数面板滑块化 (Sliders & Snap Points)
为了给专业用户提供最精细的控制，自定义抽屉完全重塑为滑杆加精准锁点模式：
* **视频码率 (Bitrate)**：
  - 滑杆范围：`0.4 Mbps` $\rightarrow$ `原始码率` 之间。
  - 标签展示：实时显示具体码率值（如 `4.2 Mbps`），而非模糊的倍率。
* **视频帧率 (FPS)**：
  - 滑杆范围：`2 FPS` $\rightarrow$ `原始帧率`。
  - **快锁关键点 (Snap Points)**：若 `24`、`30`、`60` 帧存在于范围内，将在滑杆下方绘制微光按钮，点击即可瞬间将帧率精确锁定在该关键点。
* **音频采样率 (Audio)**：
  - 滑杆范围：`48 kbps` $\rightarrow$ `原始音频码率` (最高 256k)。
  - **快锁关键点**：`64 kbps` 与 `128 kbps` 快捷锁点。

### 6. 视频播放器自适应比例与比对视图优化
* **防尺寸死框**：移除死扣的 `16:9` 宽高比限制，根据源视频的 `width/height` 动态换算 `aspectRatio`。无论是横屏电影还是竖屏抖音视频，均能获得最大的无缝填充，并限制最大高度为 `350`。
* **切换与对比重构**：
  - 界面去掉 "大小对比" 字样，将 `-68%` 小角标直接挂载在 `arrow.right` 上方。
  - 对比内容不仅包含 Size，还列出 `1920x1080 -> 1280x720` 等物理分辨率的前后对比。
  - 切换按钮文本规范命名为「原视频 / 压缩视频」、「原图 / 压缩图」。
  - 保存按钮图标与文字并列（HStack），替换按钮补充图标。

---

## 拟增与拟改文件清单及现状

* **[NEW] [CustomMediaPicker.swift](file:///Users/aray/rays/repos/_me/slimVdo/SlimVdo/Views/CustomMediaPicker.swift)** - 已创建，正在进行细节调优，包含三键排序与大小过滤。
* **[MODIFY] [DashboardView.swift](file:///Users/aray/rays/repos/_me/slimVdo/SlimVdo/Views/DashboardView.swift)** - 已修改，全面接入自定义 CustomMediaPicker。
* **[MODIFY] [CompressionViewModel.swift](file:///Users/aray/rays/repos/_me/slimVdo/SlimVdo/ViewModels/CompressionViewModel.swift)** - 已修改，完成 Direct 0 拷贝管道，严格执行 `isNetworkAccessAllowed = false`。
* **[MODIFY] [PhotoCompressionViewModel.swift](file:///Users/aray/rays/repos/_me/slimVdo/SlimVdo/ViewModels/PhotoCompressionViewModel.swift)** - 已修改，完成 Direct 0 拷贝及命名 `_1` 机制。
* **[MODIFY] [PhotoCompressor.swift](file:///Users/aray/rays/repos/_me/slimVdo/SlimVdo/Engine/PhotoCompressor.swift)** - 已修改，强制 Exif/GPS 清空时写入 `NSNull()` 实现物理物理抹除。
* **[MODIFY] [PhotoCompressionConfigView.swift](file:///Users/aray/rays/repos/_me/slimVdo/SlimVdo/Views/PhotoCompressionConfigView.swift)** - 待修改，更新分辨率格式为 `(1920x1080) 80%`。
* **[MODIFY] [CompressionConfigView.swift](file:///Users/aray/rays/repos/_me/slimVdo/SlimVdo/Views/CompressionConfigView.swift)** - 待修改，重构码率、帧率、音频的 Slider 模式，配以快锁关键点，并异步生成视频第一帧封面。
* **[MODIFY] [CompressionResultView.swift](file:///Users/aray/rays/repos/_me/slimVdo/SlimVdo/Views/CompressionResultView.swift)** & **[PhotoCompressionResultView.swift](file:///Users/aray/rays/repos/_me/slimVdo/SlimVdo/Views/PhotoCompressionResultView.swift)** - 待修改，重构比对视图、百分比角标位置、剔除画质对比废话、添加图标及自适应 Aspect 播放器。

---

## 验证计划与上线流程
1. **本地静默编译**：使用 `xcodebuild` 对指定 Simulator 目标进行快速构建。
2. **多语言运行验证**：切换模拟器语言为英文和日文，确保所有自适应布局不被截断、爆框。
3. **iCloud 无网路询问验证**：在 iCloud 云端未下载文件被选中时，测试是否完美拦截网络请求，并弹出指定中文本地文案，且系统无联网询问。
