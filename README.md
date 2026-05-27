<p align="center">
  <img src="icons/圆-黑.png" width="128" height="128" alt="SlimVdo Logo">
</p>

<h1 align="center">SlimVdo</h1>

<p align="center">
  <strong>完全离线 ・ 绝对隐私 ・ 极致高效的 iOS 视频 & 照片双引擎硬件加速压缩工具</strong>
</p>

<p align="center">
  <a href="https://github.com/gvomonk/slimVdo/releases"><img src="https://img.shields.io/github/v/release/gvomonk/slimVdo?color=emeraldGreen&label=Release" alt="Release"></a>
  <img src="https://img.shields.io/badge/iOS-16.0+-blue?logo=apple" alt="iOS Support">
  <img src="https://img.shields.io/badge/Compile-iOS%2026.5-purple" alt="Base SDK">
  <img src="https://img.shields.io/badge/License-GPL%20v3-red" alt="License">
</p>

---

## 🌟 核心设计优势

SlimVdo 专为拒绝向商业云端上传私人媒体、且追求极致操作体验的 iOS 用户而生。

*   **🔒 绝对离线与隐私保护**
    本 App 没有任何网络模块，**不包含任何第三方联网追踪 SDK**。所有提取、拷贝、像素下采样和硬件编码过程 100% 运行在您本地手机的安全沙盒内。

*   **⚡️ GPU 级硬件加速双引擎**
    *   **视频引擎**：直连苹果 `AVFoundation` 编码内核，使用现代 **HEVC (H.265) / H.264** 硬件流式压制，帧率、码率、音频通道自由配置，并支持原片元数据无缝承袭。
    *   **照片引擎**：运用苹果官方推荐的 **ImageIO 硬件下采样 (Downsampling)** 最佳防闪退实践，直接在解码阶段输出目标大小，完美规避大图带来的内存崩溃，轻巧流畅。

*   **📸 截图一键压缩 (全新特色功能)**
    智能筛选设备相册里的所有 `截屏` (Screenshot) 媒体。自带**动态滑杆阈值**过滤逻辑，能够根据文件大小（如 `≥ 300.0 KB`）**实时自动勾选**匹配的截图，支持弹性阻尼交互，一键压缩释放海量手机体积。

*   **🧹 0 垃圾零存储浪费**
    每次用户从压缩页面返回首页（Dashboard），App 会自动扫描清空所有 `/tmp` 沙盒中遗留的源文件拷贝及压缩大文件，绝不让缓存占用您的手机存储。

*   **💎 干净高档的命名**
    所有压缩完毕的图片和视频均遵循统一的 `[原文件名]_slimvdo.[后缀]` 格式命名保存，没有恶心的乱码和随机前缀。

---

## 📲 脱离 App Store 自主安装指南

在 iOS 生态中，您不需要受制于 App Store，可以使用我们打包好的 `SlimVdo.ipa` 安装包进行**自主签名安装 (Sideloading)**。

以下是主流的安装安装方式：

### 方案 1：使用 AltStore / SideStore 安装（个人免越狱推荐 ⭐️）
这是最主流、最安全的个人自主签名方案，完全免费，且不需要设备越狱。

1.  在您的电脑（Mac/Windows）上下载并安装 [AltStore](https://altstore.io/)。
2.  用数据线将 iPhone 连接至电脑，通过电脑端将 AltStore 助手安装到您的手机上。
3.  在手机端登录您的个人 Apple ID（用于给 App 签名，密码仅直接发送给苹果服务器鉴权）。
4.  在手机浏览器中前往此仓库的 [Releases](https://github.com/gvomonk/slimVdo/releases) 页面，下载最新的 `SlimVdo.ipa` 包。
5.  在手机 AltStore App 内点击 `+`，选择刚刚下载的 `SlimVdo.ipa`，即可在 1 分钟内完成自主安装！
    > 💡 **小贴士**：免费的 Apple ID 签名有效期为 7 天。AltStore 会在您连接家庭 Wi-Fi 时在后台自动静默刷新签名，免去过期担忧。

---

### 方案 2：使用 TrollStore 安装（永久免重签极佳体验 ⚡️）
如果您的 iOS 系统版本支持 **TrollStore (巨魔)**，这绝对是体验最完美的安装方式。

*   **支持版本**：iOS 14.0 至 iOS 16.6.1（以及特定 17.0 版本）。
*   **安装步骤**：
    1.  如果您的手机已安装 TrollStore，直接用手机浏览器下载 `SlimVdo.ipa`。
    2.  下载完成后，选择用 TrollStore 打开（或点击 Share -> TrollStore）。
    3.  TrollStore 会利用系统 `CoreTrust` 证书漏洞对其进行永久签名安装。
    4.  **体验优势**：安装只需 2 秒，永久生效，永不过期，不需要每周重新签名。

---

### 方案 3：使用 Xcode 进行开发者部署（极客与开发者推荐 💻）
如果您有一台 Mac 电脑，可以通过开发者通道直接编译运行：

1.  克隆本仓库到本地：`git clone https://github.com/gvomonk/slimVdo.git`
2.  使用 Xcode 打开 `SlimVdo.xcodeproj`。
3.  在 `Signing & Capabilities` 页面中，选择您自己的 Personal Team (个人免签账号)。
4.  将 iPhone 通过数据线或无线连接到 Mac，并在 Xcode 顶部选择该设备。
5.  点击 **Run (cmd + R)** 按钮，Xcode 会自动将项目编译并安装运行到您的真机上（签名有效期同样为 7 天）。

---

## 🛡️ 开源协议

本项目遵循 **GNU GPL v3** 开源授权协议。
*   允许任何人随时审查源码，保证您的绝对隐私安全。
*   **严禁任何未经授权的商业用途、二次打包上架或收费行为**。

---

## 🤝 参与贡献与支持

有任何想法、漏洞反馈或优化提议，欢迎随时提交 **Issue** 或 **Pull Request**！
我们一同致力于打造最轻量、最纯粹的手机本地瘦身工具。
