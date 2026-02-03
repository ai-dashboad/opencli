# 系统托盘图标资源

## 📁 需要的图标文件

为了跨平台系统托盘功能正常工作，需要以下图标文件：

### macOS (菜单栏)
- **文件**: `tray_icon_macos_template.png`
- **尺寸**: 22x22 像素 @1x, 44x44 像素 @2x
- **格式**: PNG (透明背景)
- **要求**:
  - 黑色前景，透明背景
  - 使用 Template Image (macOS 会自动适配深色/浅色模式)
  - 简单的单色图标设计
- **建议设计**: 字母 "O" 或 CLI 符号

### Windows (系统托盘)
- **文件**: `tray_icon_windows.ico`
- **尺寸**: 16x16, 32x32, 48x48 像素 (多尺寸 ICO)
- **格式**: ICO
- **要求**:
  - 彩色图标
  - 包含多个尺寸以适应不同 DPI
  - 可以有简单的阴影效果
- **建议设计**: OpenCLI logo 彩色版本

### Linux (系统托盘)
- **文件**: `tray_icon_linux.png`
- **尺寸**: 22x22 像素 (符合 freedesktop.org 规范)
- **格式**: PNG (透明背景)
- **要求**:
  - 彩色或单色均可
  - 透明背景
  - 适应深色和浅色主题
- **建议设计**: 与 macOS 类似，但可以是彩色

## 🎨 设计指南

### 推荐的图标设计

#### 方案 1: 简约字母 "O"
```
  ╭───╮
  │ O │  <- 圆形的 "O"，代表 OpenCLI
  ╰───╯
```

#### 方案 2: 命令行符号
```
  > _    <- 命令提示符
```

#### 方案 3: CLI 图标
```
  [  ]   <- 方括号代表命令行界面
  >_
```

### 颜色方案
- **macOS**: 纯黑色 (#000000)，macOS 系统会自动调整
- **Windows**:
  - 主色: `#007ACC` (蓝色)
  - 辅色: `#FFFFFF` (白色)
- **Linux**:
  - 深色主题: 白色 (#FFFFFF) 或浅灰 (#E0E0E0)
  - 浅色主题: 深色 (#333333) 或中灰 (#666666)

## 🛠️ 创建图标的方法

### 选项 1: 使用在线工具
1. **macOS PNG**:
   - 访问 https://www.canva.com 或 https://www.figma.com
   - 创建 22x22 和 44x44 像素的黑色图标
   - 导出为 PNG (透明背景)

2. **Windows ICO**:
   - 使用 https://convertico.com
   - 上传 PNG 图标
   - 转换为多尺寸 ICO

3. **Linux PNG**:
   - 与 macOS 类似，但可以使用彩色

### 选项 2: 使用设计软件
- **Adobe Illustrator / Inkscape**: 矢量设计
- **Photoshop / GIMP**: 位图编辑
- **Sketch / Figma**: UI 设计工具

### 选项 3: 使用代码生成
```python
# Python + PIL 生成简单图标
from PIL import Image, ImageDraw

# 创建 22x22 像素的图标
img = Image.new('RGBA', (22, 22), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# 绘制圆形 "O"
draw.ellipse([4, 4, 18, 18], outline='black', width=2)

# 保存
img.save('tray_icon_macos_template.png')
```

## 📋 当前状态

### ⚠️  临时方案
当前代码会尝试加载这些图标，如果失败会使用默认图标（可能显示为空白或系统默认）。

### ✅ 后续步骤
1. 创建上述三个图标文件
2. 放置在 `opencli_app/assets/` 目录
3. 在 `pubspec.yaml` 中声明资源
4. 重新编译应用

## 🔗 参考资源

- [macOS Human Interface Guidelines - Menu Bar Icons](https://developer.apple.com/design/human-interface-guidelines/macos/icons-and-images/system-icons/)
- [Windows App Icon Guidelines](https://docs.microsoft.com/en-us/windows/apps/design/style/iconography/app-icon-design)
- [freedesktop.org Icon Theme Specification](https://specifications.freedesktop.org/icon-theme-spec/icon-theme-spec-latest.html)

---

**创建时间**: 2026-02-03
**作者**: Claude Code
**用途**: OpenCLI 跨平台系统托盘图标
