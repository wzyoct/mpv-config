# mpv-config

mpv Windows 便携版配置文件，搭配 [uosc](https://github.com/tomasklaen/uosc) 现代 UI 脚本。

## 快速开始

### 1. 下载 mpv

从 [shinchiro/mpv-winbuild-cmake/releases](https://github.com/shinchiro/mpv-winbuild-cmake/releases) 下载最新构建：

| 文件名 | 说明 |
|--------|------|
| `mpv-x86_64-*.7z` | 标准 x86_64 版本，兼容所有 64 位 CPU |
| `mpv-x86_64-v3-*.7z` | x86_64 v3 版本（需 CPU 支持 AVX2），性能更好 |

> 💡 不确定选哪个？先试 `mpv-x86_64-*.7z`，稳定通用。

### 2. 解压 mpv

将下载的 `.7z` 文件解压到任意目录，例如 `D:\mpv\`。

解压后目录结构应如下：

```
D:\mpv\
├── mpv.exe
├── ...
```

### 3. 导入本配置

在解压目录下克隆本仓库为 `portable_config`：

```bash
cd D:\mpv\
git clone https://github.com/wzyoct/mpv-config.git portable_config
```

### 4. 下载 uosc 字体（必须）

> ⚠️ **如果 UI 图标显示为英文文字（如 `play_arrow`、`pause`）而非图标，说明字体缺失。**

uosc 使用 `MaterialIconsRound-Regular` 字体渲染图标。首次 clone 后必须手动下载：

```bash
# 在 portable_config/ 目录下执行
curl -L -o uosc-fonts.zip "https://github.com/tomasklaen/uosc/releases/latest/download/uosc.zip"
unzip -j uosc-fonts.zip "uosc/fonts/*" -d fonts/ && rm uosc-fonts.zip
```

或手动操作：

1. 打开 https://github.com/tomasklaen/uosc/releases/latest
2. 下载 `uosc.zip`
3. 解压其中的 `uosc/fonts/` 目录到 `portable_config/fonts/`
4. 重启 mpv，图标应恢复正常

> 📌 **升级 uosc 脚本后，也需同步更新 fonts/ 目录**。

### 5. 启动

双击 `mpv.exe` 即可使用。

---

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
└── fonts/              # uosc 图标字体（需手动下载，见上方说明）
```

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
| \`\`\` | 打开控制台 |

### profiles.conf

#### 性能分级（手动切换）

| Profile | 缩放算法 | 适用 |
|---------|---------|------|
| `powerful`（默认） | ewa_lanczossharp + mitchell + 去色带 | 中高配机 |
| `lite` | bilinear + fast 内置 profile | 低配机 |

> 低配机用户：编辑 `profiles.conf` 末尾 `[default]`，将 `profile=powerful` 改为 `profile=lite`。

#### 自动触发

| Profile | 条件 | 效果 |
|---------|------|------|
| `stream` | 播放 .m3u / .m3u8 直播流 | 缓冲降为 5MB |
| `16k-downscale` | 视频分辨率超过 8K（8640×4320） | 限制到 16K 以内 |
| `8k-downscale` | 视频分辨率超过 4K（8192×4320） | 限制到 8K 以内 |
| `HDR-direct` | 检测到 HDR PQ 内容 | 信号直出，显示器处理色调映射 |

### uosc.conf

- 时间线：条形样式，展开 40px
- 进度条：窗口模式始终显示
- 控制栏：播放/暂停、速度、音量、全屏、菜单等
- 菜单语言：优先跟随字幕语言，回退简中
- 章节高亮：片头片尾（透明绿）、广告（透明红）
- 字幕下载：保存到 `~~/subtitles`

## 系统要求

- [shinchiro mpv-winbuild-cmake](https://github.com/shinchiro/mpv-winbuild-cmake/releases) 最新构建
- Windows 10 / 11（64 位）
- uosc 最新 release 版本

## 更新日志

### 2026-08-07

**profiles.conf**

- 修复条件 profile（`stream`、`16k-downscale`、`8k-downscale`）缺少 `profile-restore=copy`，切回普通视频后缓冲设置残留的 bug
- `powerful` profile 新增 `deband=yes` + `deband-iterations=2`，改善渐变/暗场色带
- `lite` profile 显式关闭 `deband`

**cache-display.lua**

- 轮询间隔从 0.5s 调整为 1s，减少无意义计算

**README.md**

- 新增完整安装说明（基于 shinchiro mpv-winbuild-cmake）
- 新增更新日志章节
