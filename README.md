# mpv-config

这是我的 Windows 便携版 MPV 配置仓库，用 GitHub 保存一套可复现、可跨设备恢复的播放环境配置。仓库包含完整的 UOSC 播放界面、UOSC 字体、字幕辅助程序、快捷键、统计页、网络缓存设置和自定义脚本。

目标是：在其他设备准备好 MPV 后，从本仓库恢复 `portable_config/`，即可使用与主设备一致的配置。仓库不包含 MPV 主程序、媒体文件或设备运行缓存。

## 下载与安装

1. 先从 [MPV 官方安装页](https://mpv.io/installation/) 下载 Windows MPV，解压或安装到你选择的目录，并确认其中存在 `mpv.exe`。
2. 从本仓库的 [Releases 页面](https://github.com/wzyoct/mpv-config/releases) 下载 `mpv-portable-config-v1.0.0.zip`。
3. 将 ZIP 解压到 `mpv.exe` 所在目录。压缩包顶层固定为 `portable_config/`，完成后目录结构应为：

   ```text
   mpv/
   ├─ mpv.exe
   └─ portable_config/
   ```

4. 从 [Jellyfin MPV Player Releases](https://github.com/wzyoct/jellyfin-mpv-player/releases) 下载播放器，按播放器 README 配置 MPV 的完整路径。

便携目录需要保持以下相对位置：

```text
mpv/
├─ yt-dlp.exe
└─ portable_config/
```

`mpv.conf` 会从配置目录的上一级查找 `yt-dlp.exe`。如果单独移动 `portable_config/`，请同时保持这个相对位置，否则网络视频解析功能可能无法使用。

也可以直接使用 HTTPS 克隆配置仓库：

```powershell
git clone https://github.com/wzyoct/mpv-config.git portable_config
```

## 跨设备完整恢复

推荐流程如下：

1. 下载并解压 Windows MPV，确认存在 `mpv.exe`。
2. 在 MPV 程序所在目录准备 `yt-dlp.exe`（网络视频功能需要）。
3. 打开或创建 MPV 程序目录下的 `portable_config/`。
4. 将下面的提示词完整交给 Codex。
5. 等 Codex 报告远程提交号、文件校验和启动验证结果后，再打开 MPV。

不要把仓库克隆成 `portable_config/portable_config/`。如果当前 `portable_config/` 已有本地配置，Codex 应先识别并保留运行时数据，再用 GitHub 内容替换配置文件。

可直接交给 Codex 的恢复提示词：

```text
请把当前目录恢复为 GitHub 仓库 https://github.com/wzyoct/mpv-config.git 的最新 master 内容，并以 GitHub 为唯一配置源，直到这套 MPV 配置可以正常使用。

请先执行以下检查：
1. 确认当前目录就是 portable_config 配置目录，不要在里面再创建 portable_config/portable_config 嵌套目录。
2. 读取当前目录的 AGENTS.md 和 README.md，遵守其中的项目规则。
3. 在临时目录通过 HTTPS 克隆或获取上述仓库，核对远程 master 的提交和文件清单，再执行替换。

替换要求：
- 完整同步 GitHub 中已跟踪的配置、脚本、字体、许可证和文档，不要只复制 mpv.conf 或 UOSC 的部分文件。
- 以远程仓库为准，清理仓库管理范围内已经被远程删除的旧配置文件；但不要删除 mpv.exe、ffmpeg.exe、yt-dlp.exe 或其他播放器程序。
- 保留 cache/、watch_later/、screenshots/、subtitles/ 等本地运行时目录及其中内容。
- 确认 scripts/uosc/bin/ziggy-windows.exe 已从 GitHub 恢复，并校验 SHA256；如果缺失或校验不一致，明确报告，不要假装完整。
- 不要修改或推送 GitHub，除非我另外明确要求。

完成后请报告：远程提交号、实际替换的文件范围、保留的本地运行时内容、MPV 版本、UOSC 是否加载、ziggy-windows.exe 的存在性和 SHA256，以及最小启动验证结果。若发现错误，保留错误信息并停止，不要用默认值掩盖问题。
```

恢复完成后，配置仓库中已跟踪的文件应与 GitHub 一致。`cache/`、`watch_later/`、`screenshots/` 和 `subtitles/` 仍属于本机运行数据，不参与跨设备同步。

## 文件结构

```text
portable_config/
├── mpv.conf
├── input.conf
├── profiles.conf
├── script-opts/uosc.conf
├── scripts/
│   ├── uosc/             # uosc 5.13.0
│   ├── stats.lua         # mpv-stats
│   └── cache-display.lua # 本仓库自有脚本
└── fonts/
    ├── LXGWWenKai-Regular.ttf
    ├── uosc_icons.otf
    └── uosc_textures.ttf
```

仓库包含 UOSC 的完整 Lua 文件、字体和 Windows 版 `scripts/uosc/bin/ziggy-windows.exe`。后者用于字幕搜索和下载，是本项目 Windows 配置的一部分。

配置要求 Windows 10/11（64 位）和 MPV 0.41 或更高版本。`mpv.conf` 中的大容量网络缓存是针对网络较差、主机性能较高的环境设置的；如需调整，请先理解对应 MPV 选项的影响。
播放器目录中的 `mpv.exe`、`ffmpeg.exe` 和 `yt-dlp.exe` 属于运行环境，不需要放进这个配置仓库。
`watch_later/`、`cache/`、`screenshots/` 和 `subtitles/` 是运行时数据，已由 `.gitignore` 排除。

## 项目组成

这个项目不只是三份配置文件，而是一套可运行的 MPV 便携配置。各部分的职责如下：

### 1. 配置

- `mpv.conf` 是主入口，负责渲染、硬件解码、HDR 直通、窗口、字幕、音轨优先级、网络播放、截图和脚本选项。
- `profiles.conf` 由 `mpv.conf` 最后 `include`，负责按机器性能和视频条件切换参数：
  - `powerful`：高质量缩放，适合性能较强的机器。
  - `lite`：双线性缩放并继承 MPV 的 `fast` profile，适合低配机器。
  - `default`：当前默认启用 `powerful`；换机器时可改成 `lite`。
  - `HDR-direct`：检测到 PQ HDR 视频时启用 HDR 直通，并将峰值设为 10000，尽量交由显示器处理。
- `mpv.conf` 关闭 MPV 内置 OSC 和 OSD 进度条，由 UOSC 接管界面；同时关闭默认快捷键，只保留 `input.conf` 中明确声明的按键。
- 网络缓存是本配置的固定策略：`demuxer-max-bytes=2048MiB`、`demuxer-max-back-bytes=256MiB`、`cache-pause=no`。它针对网络较差且主机性能较高的环境，不应在普通整理或审查中擅自调整。

### 2. 快捷键

快捷键集中在 `input.conf`。音量、速度和跳转操作都通过 `script-message-to uosc flash-elements ...` 同步刷新 UOSC 的提示动画。

| 按键 | 行为 |
| --- | --- |
| `Space` | 暂停/继续，并触发 UOSC 暂停动画 |
| `Enter`、双击鼠标左键 | 切换全屏 |
| `Esc` | 退出全屏 |
| 鼠标右键 | 打开带背景模糊的 UOSC 主菜单 |
| `Ctrl+V` | 从剪贴板加载链接或路径播放 |
| `Up` / `Down` | 音量增加/减少 5 |
| `[` / `]` | 在 `1x`、`1.25x`、`1.5x`、`1.75x`、`2x`、`2.5x`、`3x` 之间减速/加速循环 |
| `Left` / `Right` | 后退/前进 5 秒 |
| `Alt+[` / `Alt+]` | 字幕缩小/放大 0.1 |
| `` ` `` | 打开 MPV 控制台 |
| `Shift+I` | 打开/关闭统计页 |

UOSC 菜单内部还提供文件、播放列表、音轨、字幕、章节、流媒体质量和音频设备等操作；这些属于 UOSC 的菜单快捷键，不在 `input.conf` 中重复维护。

### 3. UOSC 播放界面

- `scripts/uosc/` 是随仓库分发的 UOSC 5.13.0 完整脚本，MPV 会自动加载 `scripts/` 下的 Lua 脚本。
- `script-opts/uosc.conf` 是 UOSC 的本地外观和行为配置：时间线、控制栏、音量条、速度步长、菜单、顶部标题栏、文件类型、字幕目录和章节标记等都在这里集中定义。
- 当前控制栏包含菜单、字幕、音频、视频、版本/章节相关控件、流媒体质量、速度、上一项、播放列表、下一项和全屏；可见控件会根据当前媒体能力动态显示。
- UOSC 顶栏副标题读取 `${user-data/cache-display/info}`，因此会显示 `cache-display.lua` 提供的北京时间、按倍速折算后的可观看缓存时长和当前网速。
- `fonts/uosc_icons.otf` 和 `fonts/uosc_textures.ttf` 提供 UOSC 图标与纹理；`fonts/LXGWWenKai-Regular.ttf` 用于中文字幕。
- `scripts/uosc/bin/ziggy-windows.exe` 是 Windows 字幕搜索/下载辅助程序。缺失或 SHA256 不一致时，字幕下载功能不能视为完整恢复。

### 4. 辅助脚本与运行依赖

- `scripts/stats.lua` 提供统计页，按 `1`、`2`、`3`、`0` 切换普通信息、帧时序、缓存统计和性能信息；通过 `Shift+I` 显示或隐藏。
- `scripts/cache-display.lua` 每 0.5 秒计算缓存可观看时长和网速，并将结果交给 UOSC 顶栏显示。
- `yt-dlp.exe` 不在仓库内，由 `mpv.conf` 从 `portable_config/` 的上一级目录查找，用于网络视频解析。
- `mpv.exe` 和 `ffmpeg.exe` 同样属于 MPV 运行环境，不属于本配置仓库。

### 5. 运行时数据与许可

- `cache/`、`watch_later/`、`screenshots/` 和 `subtitles/` 是本机运行数据，不应作为跨设备配置同步；恢复配置时应保留它们，但不要求从 GitHub 下载。
- UOSC、mpv-stats、UOSC 字体和霞鹜文楷的许可证与来源见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) 及 `LICENSES/`。本仓库自己的配置、`cache-display.lua` 和文档使用 MIT License。

## 启动后的工作关系

MPV 启动时先读取 `mpv.conf`，再加载 `profiles.conf` 中的 profile 和 `script-opts/uosc.conf`。随后自动加载 UOSC、统计脚本和缓存信息脚本：

```text
mpv.conf
├─ include profiles.conf
├─ 关闭内置 OSC，启用硬件解码/HDR/字幕/缓存等基础策略
├─ 加载 scripts/uosc + script-opts/uosc.conf
├─ 加载 scripts/stats.lua
└─ 加载 scripts/cache-display.lua
   └─ user-data/cache-display/info -> UOSC 顶栏副标题
```

修改时通常按这个边界处理：播放基础行为改 `mpv.conf`，性能档位改 `profiles.conf`，按键改 `input.conf`，界面外观和菜单改 `script-opts/uosc.conf`，顶栏缓存信息改 `scripts/cache-display.lua`。不要直接改 UOSC 内部 Lua，除非确实是在维护第三方组件。

## 许可

本仓库自有配置、`cache-display.lua` 和文档使用 [MIT License](LICENSE)。仓库同时分发的第三方内容及其完整许可文本见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) 和 `LICENSES/`：

- uosc 5.13.0、uosc 图标/纹理字体：LGPL-2.1。
- mpv-stats：LGPL-2.1。
- 霞鹜文楷 `LXGWWenKai-Regular.ttf`：SIL Open Font License 1.1。
