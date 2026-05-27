# 极致细节打磨与国际化演进实施方案 - SlimVdo

本方案是针对 SlimVdo 真机实测反馈的终极开发方案。我们将在本项目中对空间看板、文字克制、自定义参数滑块、比对播放器等核心细节进行全方位的打磨。此外，为了顺应上架多国 App Store 的国际化（Localization）需求，本方案在底层架构、系统权限提示和 UI 布局弹性三个维度为国际化预留最佳技术实践路径。

---

## 核心设计与技术决策

### 1. 极致性能：0拷贝 Direct AVAsset 管道 (解决加载卡顿)
* **问题诊断**：原版使用 `loadTransferable` 会强行让系统将大视频完整转码并物理复制到沙盒 `/tmp`，导致耗时过长且大小翻倍。
* **解决方案**：放弃 system copying，利用 `PHImageManager.default().requestAVAsset` 异步且直连地获取 Photos 库中视频的 `AVAsset` 对象。直接提取物理 `AVURLAsset` 指向的路径进行硬编压制，免去一切前期拷贝，实现**毫秒级瞬间加载**！
* **退出机制**：在 ProgressLoading 界面添加醒目的「返回」按钮，允许用户随时安全中断提取或压缩，退回主屏幕。

### 2. 独家最佳实践：完全本地定制化「智能媒体拾取器」 (Custom Media Picker)
* **问题诊断**：系统原生的 `PhotosPicker` 运行在独立系统进程中，宿主 App **绝对无法**在其中添加自定义排序、大小过滤或展示文件体积。
* **解决方案**：采用苹果 `Photos` 框架，在 App 内实现一个极其精美、流线感十足的自定义 **`CustomMediaPicker`** 组件：
  - **精细化三键排序**：支持三个独立的快速排序切换按钮：
    1. **「日期 ⬇️」**（按拍摄日期降序，最新排在最前）
    2. **「日期 ⬆️」**（按拍摄日期升序，最旧排在最前）
    3. **「大小 ⬇️」**（按文件大小降序，体积最大排在最前，一眼抓出大文件）
  - **智能体积筛选**：提供快速过滤器（照片可选「大于 5MB」，视频可选「大于 200MB」），实现精准缩水。
  - **体积智能微标签**：每个媒体网格右下角均以高精度浅色小字展示其真实物理大小；若**照片大于 5MB** 或**视频大于 200MB**，自动渲染为浅红色以示警示。
  - **高性能惰性加载**：大小数据均由异步后台任务在 Cell 的 `.task` 中惰性读取并缓存，保证千张照片极速滑动时 0 卡顿。

### 3. iCloud 联网控制与系统网络询问彻底隐匿机制
* **问题诊断**：当应用通过系统底层的 `AVPlayer` 去播放一个存储在 iCloud 且本地尚未完全缓存的高清原片时，系统底层检测到文件不在本地，从而自动触发了 Photos 系统服务从 iCloud 服务器下载原片的高清网络请求，进而诱发了 iOS 的“允许 App 联网吗”的安全提示。
* **解决方案**：我们在获取 `AVAsset` 与图像 `Data` 时，默认将 `PHVideoRequestOptions` / `PHImageRequestOptions` 中的 **`isNetworkAccessAllowed` 显式设置为 `false`**！
* **效果**：当 App 尝试访问 iCloud 上的未下载媒体时，由于我们禁止了网络访问，Photos 框架会直接返回一个本地未下载的错误，**彻底阻断任何后台静默联网行为，因而绝不会触发系统的联网权限弹窗**！
* **绝对本地化提示文案**：
  在触发错误时，我们会在界面中弹出一个极其友好、符合安全策略的本地提示：
  > **“本app被禁止联网\n请放心使用\n（若您正操作的文件在iCloud云端\n请先下载到本地）”**
  这既完美契合了“完全本地离线”的招牌隐私承诺，又彻底隐匿了任何静默网络请求的发生。

### 4. 国际化 (Localization) 演进路线规划
上架多国 App Store 对文字、排版和系统权限有着极其苛刻的要求，我们将采用如下最佳实践保障国际化演进：
1. **字符国际化支持**：
   - 所有的界面显示字符（包括滑块、卡片、操作按钮等）均使用标准 SwiftUI 的 `Text(LocalizedStringKey("..."))` 进行布局。
   - 所有文本提取自静态 `strings` 结构，为后续建立 `Localizable.strings`（英语、日语、韩语等）奠定基础。
2. **系统权限多语言说明 (`InfoPlist.strings`)**：
   - 为相册读写权限 `NSPhotoLibraryUsageDescription` 预留多语言翻译配置文件。确保审核时系统弹出权限申请框时，提示文案（如“获取相册大小并提取原片...”）能根据用户的手机系统语言自动完美翻译。
3. **弹性 UI 布局 (Flexible UI Layout)**：
   - 为防止单词长度翻倍（如德语、法语等单词通常比中文和英文长一倍）造成排版爆框或被截断成 `...`，UI 容器一律移除硬编码的静态宽度（`.frame(width: 80)`），全部过渡为自适应排版。使用 `HStack`、`VStack` 的弹性间距和 `minimumScaleFactor(0.5)`，确保在任意长单词语言下都能完美优雅地显示。

### 5. 自定义参数面板滑块化 (Sliders & Snap Points)
为了给专业用户提供最精细的控制，我们将自定义抽屉彻底重塑为滑杆模式：
* **视频码率 (Bitrate)**：
  - 滑杆范围：`0.4 Mbps` $\rightarrow$ `原始码率` 之间。
  - 标签展示：实时显示具体码率值（如 `4.2 Mbps`），而非模糊的倍率。
* **视频帧率 (FPS)**：
  - 滑杆范围：`2 FPS` $\rightarrow$ `原始帧率`。
  - **快锁关键点 (Snap Points)**：若 `24`、`30`、`60` 帧存在于范围内且不处于边缘，将在滑杆下方绘制微光按钮，点击即可瞬间将帧率精确锁定在该关键点。
* **音频采样率 (Audio)**：
  - 滑杆范围：`48 kbps` $\rightarrow$ `原始音频码率` (最高 256k)。
  - **快锁关键点**：`64 kbps` 与 `128 kbps` 快捷点。

### 6. 视频播放器自适应比例与比对视图优化
* **防尺寸死框**：根据源视频的 `width/height` 动态换算 `aspectRatio`。无论是横屏电影还是竖屏抖音视频，均能获得最大的无缝填充，并限制最大高度为 `350`。
* **按钮与布局重构**：
  - 界面去掉 "大小对比" 字样，将 `-68%` 小角标直接挂载在 `arrow.right` 上方。
  - 对比内容不仅包含 Size，还列出 `1920x1080 -> 1280x720` 等物理分辨率的前后对比。
  - 切换按钮文本规范命名为「原视频 / 压缩视频」、「原图 / 压缩图」。
  - 保存按钮图标与文字并列（HStack），替换按钮补充图标。

---

## 拟增与拟改文件清单

### [NEW] [CustomMediaPicker.swift](file:///Users/aray/rays/repos/_me/slimVdo/SlimVdo/Views/CustomMediaPicker.swift)
- 包含顶层三键（日期升/降、大小降）筛选控制器、瀑布流 LazyVGrid 滚动板、PHAsset 图像缓存提取器。
- 支持按大小降序排序、按大小阈值强过滤，并在每个媒体图内右下角用浅色（或浅红色）字标出大小。

### [MODIFY] [DashboardView.swift](file:///Users/aray/rays/repos/_me/slimVdo/SlimVdo/Views/DashboardView.swift)
- 抛弃原先 rigidity 的 `PhotosPicker` 组件，改为点击直接拉起我们自定义的 `.sheet` 展示 `CustomMediaPicker`。
- 接管 `selectedAssets` 返回值，传递给对应的 ViewModel 进行解析。

### [MODIFY] [CompressionViewModel.swift](file:///Users/aray/rays/repos/_me/slimVdo/SlimVdo/ViewModels/CompressionViewModel.swift)
- 添加 `selectVideosFromAssets(_ assets: [PHAsset])` 新型高性能 Direct 加载函数，直接通过 `PHImageManager` 提取 `AVAsset` 及其物理路径，规避 `/tmp` 文件复制，性能大幅提升。
- 采用 `isNetworkAccessAllowed = false` 严格保障本地属性，拦截云端提示。
- 提取并保存原始视频的视频码率、音频码率等数据用以限制 Slider 范围。
- 支持在 Temp 盘输出中以 `[原名]_1.mp4` 进行命名。

### [MODIFY] [PhotoCompressionViewModel.swift](file:///Users/aray/rays/repos/_me/slimVdo/SlimVdo/ViewModels/PhotoCompressionViewModel.swift)
- 添加 `selectPhotosFromAssets(_ assets: [PHAsset])` 提取原图 `Data`，通过 `requestImageDataAndOrientation` 解析，准确识别 HEIC 并避免系统自动 JPEG 转换。
- 支持在 Temp 盘输出中以 `[原名]_1.heic` 进行命名。

### [MODIFY] [PhotoCompressor.swift](file:///Users/aray/rays/repos/_me/slimVdo/SlimVdo/Engine/PhotoCompressor.swift)
- 彻底解决元数据无法被清除的问题：如果 settings 中 `keepMetadata` 为 false，不仅清空传递的字典，还将 explicit 在 `CGImageDestination` 中将 GPS、Exif、TIFF 键清零写入 `NSNull()`，强制限制 GPS 物理写入。

### [MODIFY] [CompressionConfigView.swift](file:///Users/aray/rays/repos/_me/slimVdo/SlimVdo/Views/CompressionConfigView.swift)
- 顶部卡片左侧增加 `@State private var videoThumbnail: UIImage?`，使用 `AVAssetImageGenerator` 异步读取帧实现与照片一致的视频封面展示。
- 将分辨率显示格式修正为 `(1920x1080) 80%`。
- 将码率、帧率、音频面板均重构为 Slider 滑杆模式，配以 snap 锁定点及 Mbps 具体数值展示。

### [MODIFY] [PhotoCompressionConfigView.swift](file:///Users/aray/rays/repos/_me/slimVdo/SlimVdo/Views/PhotoCompressionConfigView.swift)
- 分辨率显示格式修改为 `(1920x1080) 80%`。

### [MODIFY] [CompressionResultView.swift](file:///Users/aray/rays/repos/_me/slimVdo/SlimVdo/Views/CompressionResultView.swift) & [PhotoCompressionResultView.swift](file:///Users/aray/rays/repos/_me/slimVdo/SlimVdo/Views/PhotoCompressionResultView.swift)
- **文字与大小对比优化**：去掉 "大小对比" 字样，将 `-68%` 小角标直接挂载在 `arrow.right` 上方。
- **参数对比扩展**：对比内容不仅包含 Size，还列出 `1920x1080 -> 1280x720` 等物理分辨率的前后对比。
- **比对标签重构**：删除 "画质对比" 和 "当前画面" 废话，右下角标切换按钮文本规范命名为「原视频 / 压缩视频」、「原图 / 压缩图」。
- **自适应播放框**：动态计算 Aspect Ratio 喂给 VideoPlayer，支持横竖屏。
- **按钮样式整顿**：保存按钮图标与文字并列（HStack），替换按钮补充图标。
