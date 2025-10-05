# AI Plugins 应用图标

## 图标设计

应用图标采用现代简约设计风格，灵感来自 SF Symbols：

### 设计元素
- **拼图块 (Puzzle Piece)**: 代表"插件"的概念
- **闪光效果 (Sparkles)**: 代表 AI 智能特性
- **渐变背景**: 紫蓝渐变色 (#667EEA → #764BA2)
- **圆角方形**: 符合 macOS 应用图标规范

### 配色方案
- 主背景：紫蓝渐变
- 图标：纯白色带半透明效果
- 阴影：柔和投影，增加立体感

## 文件说明

- `create_icon.py` - 图标生成脚本
- `Sources/ai_plugins/Resources/AppIcon.icns` - macOS 图标文件

## 重新生成图标

如果需要修改图标设计，编辑 `create_icon.py` 中的 SVG 内容，然后运行：

```bash
python3 create_icon.py
```

图标会自动生成所有需要的尺寸（16x16 到 1024x1024）并打包成 .icns 文件。

## 应用图标

安装应用后，图标会自动显示：

```bash
make install
```

如果图标没有立即显示，重启 Dock：

```bash
killall Dock
```

## 图标尺寸

生成的 .icns 文件包含以下尺寸：
- 16x16 (标准 + @2x)
- 32x32 (标准 + @2x)
- 128x128 (标准 + @2x)
- 256x256 (标准 + @2x)
- 512x512 (标准 + @2x)

这确保了图标在所有显示环境下都清晰锐利。
