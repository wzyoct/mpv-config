# mpv-config

mpv Windows 便携版配置文件，搭配 [uosc](https://github.com/tomasklaen/uosc) 现代 UI。

## 文件

```
├── mpv.conf            # 主配置（解码、渲染、快捷键、OSD）
├── input.conf          # 快捷键绑定
├── profiles.conf       # 条件配置（按文件类型自动切换）
├── script-opts/
│   └── uosc.conf       # uosc UI 配置
├── scripts/
│   ├── uosc/           # uosc 现代 UI 脚本
│   ├── stats.lua       # 按 Shift+I 显示实时统计
│   └── cache-display.lua  # 显示缓冲进度
└── fonts/              # uosc 图标字体
```

## 使用

```bash
# 克隆到 mpv 便携版目录
cd mpv/
git clone https://github.com/wzyoct/mpv-config.git portable_config

# 更新配置
cd portable_config/
git pull
```

或者把本仓库放到 mpv 根目录，重命名为 `portable_config`。

## 配置说明

### mpv.conf

- 视频渲染：gpu-next 渲染器，启用 HDR 直通
- 音频：WASAPI 独占模式
- 字幕：高品质字体、中日韩语言优先级
- 截图：JPEG/PNG 高质量、含字幕

### input.conf

- `WHEEL_UP/DOWN` 调音量
- `Ctrl+WHEEL` 调播放速度
- `Ctrl+Shift+WHEEL` 调字幕大小
- `Alt+WHEEL` 逐帧前进/后退
- `Shift+RIGHT/LEFT` 调字幕延迟

### profiles.conf

- `.m3u/.m3u8` 直播流自动使用 5MB 缓冲
- 8K 视频限制 8192x4320 分辨率
- 16K 视频限制 16384x8640 分辨率

### uosc

现代化播放控制栏，支持缩略图预览、自定义菜单、播放列表、多语言。

## 系统要求

- mpv 0.37.0+
- Windows 10/11（64 位）

## 字体

首次 clone 后需要手动下载 uosc 图标字体：

1. 从 [uosc releases](https://github.com/tomasklaen/uosc/releases/latest) 下载 `uosc.zip`
2. 解压 `fonts/` 目录到 `portable_config/fonts/`
3. 运行一次 mpv 确认 UI 正常显示
