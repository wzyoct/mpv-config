# mpv-config

mpv Windows 便携版配置文件，搭配 [uosc](https://github.com/tomasklaen/uosc) 现代 UI 脚本。

## 文件结构

```
portable_config/
├── mpv.conf            # 主配置（渲染、色彩、窗口、字幕、音轨、网络缓冲）
├── input.conf          # 快捷键绑定（禁用默认键位，仅此处定义的生效）
├── profiles.conf       # 条件 profile（性能分级 + 文件类型自动切换）
├── script-opts/
│   └── uosc.conf       # uosc 脚本 UI 参数
├── scripts/
│   ├── uosc/           # uosc 现代 UI（main.lua + elements/ + lib/ + intl/）
│   ├── stats.lua       # 内置统计页（Shift+I）
│   └── cache-display.lua  # 缓冲进度显示
└── fonts/              # uosc 图标字体（需手动下载，见下方说明）
```

## 安装

```bash
# 克隆到 mpv 便携版目录
cd mpv/
git clone git@github.com:wzyoct/mpv-config.git portable_config
```

如果已有本地仓库，直接 `git pull` 更新：

```bash
cd mpv/portable_config/
git pull
```

## 字体

首次 clone 后需手动下载 uosc 图标字体，否则 UI 图标显示为方块：

1. 从 [uosc releases](https://github.com/tomasklaen/uosc/releases/latest) 下载 `uosc.zip`
2. 解压其中的 `fonts/` 目录到 `portable_config/fonts/`
3. 启动 mpv 确认 UI 图标正常显示

## 配置说明

### mpv.conf

| 类别 | 配置 | 说明 |
|------|------|------|
| 渲染 | `vo=gpu-next` `gpu-api=d3d11` | D3D11 渲染，HDR 直通最稳定 |
| 硬解 | `hwdec=d3d11va` `hwdec-codecs=all` | 所有编码格式启用硬解 |
| HDR | `target-colorspace-hint=yes` | 向系统声明色彩空间，触发 OS 级 HDR 直通 |
| | `tone-mapping=clip` | 超出范围截断，不做软件色调映射 |
| | `gamut-mapping-mode=clip` | 色域截断，原始信号直出 |
| | `hdr-compute-peak=no` | 关闭逐帧峰值计算，避免 AV1/HDR 全屏紫屏 |
| 窗口 | `border=no` | 无边框 |
| | `autofit-larger=50%x50%` | 初始不超过屏幕 50% |
| | `geometry=50%:50%` | 启动居中 |
| | `keep-open=yes` | 播放结束不退出 |
| 字幕 | `sub-auto=fuzzy` | 模糊匹配同名字幕 |
| | `slang=chs,sc,zh-Hans,...,zh` | 语言优先级：简中 > 繁中 > 其他 |
| 音轨 | `alang=japanese,...,en` | 日语优先，英语次之 |
| 网络 | `demuxer-max-bytes=2048MiB` | 前向缓冲 2GB |
| | `demuxer-max-back-bytes=256MiB` | 后向缓冲 256MB |
| | `cache-pause=no` | 缓冲期间不暂停 |
| 输入 | `no-input-default-bindings` | 禁用所有默认快捷键 |

### input.conf

> 所有快捷键配合 uosc 刷新对应 UI 元素。

| 按键 | 功能 |
|------|------|
| `Space` | 暂停 / 继续 |
| `Enter` | 切换全屏 |
| `鼠标左键双击` | 切换全屏 |
| `Esc` | 退出全屏（不会退出 mpv） |
| `鼠标右键` | 打开 uosc 模糊主菜单 |
| `↑` / `↓` | 音量 ±5 |
| `←` / `→` | 快退 / 快进 5 秒 |
| `[` / `]` | 播放速度循环（1× → 1.25× → 1.5× → 1.75× → 2× → 2.5× → 3×） |
| `Alt+[` / `Alt+]` | 字幕缩放 ±0.1 |
| `Ctrl+V` | 从剪贴板加载链接播放 |
| `Shift+I` | 切换统计信息页面 |
| `` ` `` | 打开控制台 |

### profiles.conf

#### 性能分级（手动切换）

| Profile | 缩放算法 | 适用 |
|---------|---------|------|
| `powerful`（默认） | ewa_lanczossharp + mitchell + 线性光 | 高配机 |
| `lite` | bilinear + fast 内置 profile | 低配机 |

> 低配机用户：编辑 `profiles.conf` 末尾 `[default]`，将 `profile=powerful` 改为 `profile=lite`。

#### 自动触发

| Profile | 条件 | 效果 |
|---------|------|------|
| `stream` | 播放 .m3u / .m3u8 直播流 | 缓冲降为 5MB |
| `16k-downscale` | 视频分辨率超过 8K（8640×4320） | 限制到 16K 以内 |
| `8k-downscale` | 视频分辨率超过 4K（8192×4320） | 限制到 8K 以内 |

### uosc.conf

- 时间线：条形样式，展开 40px
- 进度条：窗口模式始终显示
- 控制栏：播放/暂停、速度、音量、全屏、菜单等
- 菜单语言：优先跟随字幕语言，回退简中
- 章节高亮：片头片尾（透明绿）、广告（透明红）
- 字幕下载：保存到 `~~/subtitles`

## 系统要求

- mpv ≥ 0.37.0
- Windows 10 / 11（64 位）
- uosc 最新 release 版本
