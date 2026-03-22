# 图片压缩小工具

一款简洁高效的 macOS 图片压缩工具，使用 SwiftUI 原生构建。

![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

![App Screenshot](screenshot.png)

## 功能特点

- 🖼️ **拖拽添加** - 直接将图片拖入应用即可添加
- ⚡ **批量处理** - 一次压缩多张图片
- 🎛️ **质量调节** - JPEG 质量可调 (1-100%)
- 📐 **尺寸限制** - 限制最大尺寸，保持宽高比
- 🔄 **格式转换** - 在 JPEG、PNG、HEIC 之间转换
- 🗑️ **去除元数据** - 可选移除 EXIF 等隐私信息
- 📊 **实时进度** - 查看压缩进度和结果
- 💾 **历史记录** - 查看过往压缩会话
- 🔒 **安全可靠** - 使用原生 ImageIO 框架，完全兼容沙盒

## 系统要求

- macOS 14.0 (Sonoma) 或更高版本
- Apple Silicon (M1/M2/M3) 或 Intel Mac

## 下载安装

### 方式一：直接下载 DMG（推荐）

1. 下载下方的 `图片压缩V3.dmg` 文件
2. 打开 DMG 文件
3. 将「图片压缩」拖拽到「应用程序」文件夹
4. 启动应用即可使用！

### 方式二：从源码构建

```bash
# 克隆仓库
git clone https://github.com/Looperswag/ImageCompressor.git
cd ImageCompressor

# 使用 Xcode 打开
open ImageCompressor.xcodeproj

# 点击运行按钮 (⌘R) 构建并运行
```

## 使用方法

### 1. 添加图片
- 将图片拖拽到应用窗口
- 或点击「选择文件」按钮

### 2. 配置设置
- 选择预设方案（高质量、网页优化、缩略图）
- 或自定义：格式、质量、最大尺寸、元数据处理

### 3. 开始压缩
- 点击「开始压缩」按钮
- 实时查看每张图片的压缩进度
- 压缩完成后自动打开输出文件夹

### 4. 查看结果
- 对比原始大小和压缩后大小
- 查看压缩比例
- 点击文件夹图标打开输出位置

## 压缩预设

| 预设方案 | 质量 | 最大尺寸 | 格式 | 适用场景 |
|---------|------|---------|------|---------|
| 高质量 | 90% | 原始 | JPEG | 打印、存档 |
| 网页优化 | 75% | 2048px | JPEG | 网站发布、分享 |
| 缩略图 | 70% | 800px | JPEG | 预览、缩略图 |
| PNG 优化 | 无损 | 原始 | PNG | 带透明度的图形 |

## 支持的输入格式

- JPEG / JPG
- PNG
- HEIC（自动转换为 JPEG）
- TIFF
- BMP
- GIF（仅第一帧）

## 快捷键

| 快捷键 | 操作 |
|-------|------|
| ⌘O | 添加图片 |
| ⌘B | 开始压缩 |
| Delete | 移除选中图片 |

## 技术细节

- **SwiftUI** - 原生 macOS 体验
- **ImageIO** - 使用系统原生框架进行图片处理
- **沙盒兼容** - 完全支持 macOS 应用沙盒
- **安全书签** - 使用 security-scoped bookmarks 访问用户文件

## 项目结构

```
ImageCompressor/
├── App/                    # 应用入口
├── Models/                 # 数据模型
├── ViewModels/             # 业务逻辑
├── Views/                  # SwiftUI 视图
│   ├── Main/              # 主界面
│   └── Components/        # 可复用组件
├── Services/              # 压缩服务
├── Utils/                 # 工具类
└── Resources/             # 资源文件
```

## 常见问题

**Q: 为什么我的 HEIC 图片被转换成了 JPEG？**

A: HEIC 格式主要用于 Apple 设备拍照，为了更好的兼容性，默认转换为 JPEG 输出。

**Q: 压缩后图片在哪里？**

A: 默认保存在桌面的「Compressed Images」文件夹中，您也可以在设置中自定义输出位置。

**Q: 如何去除照片的位置信息？**

A: 勾选「去除元数据」选项，压缩时会自动移除 EXIF 信息。

**Q: 支持批量处理吗？**

A: 完全支持！可以一次性拖入数百张图片进行批量压缩。

## 开源许可

MIT License - 自由使用和修改

## 更新日志

### V3.0 (2025-03)
- 修复沙盒环境下的压缩问题
- 改用原生 ImageIO 框架，更稳定可靠
- 添加 HEIC 格式支持
- 优化大文件处理性能

### V2.0
- 添加批量处理功能
- 新增压缩历史记录
- 支持自定义输出目录

### V1.0
- 初始版本发布

## 致谢

- 使用 macOS 内置 ImageIO 框架进行图片处理
- 图标来自 SF Symbols
