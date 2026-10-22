# mpv-config

这是我的 Windows 便携版 MPV 配置仓库。仓库保存 `portable_config/` 内需要跨设备同步的配置、脚本、字体、许可证和文档；不保存 MPV 主程序、媒体文件或本机运行时数据。

## 先看这里：源码还是发行版

本仓库的 GitHub 源码是配置的唯一事实来源。Git 提交会记录每次配置变化，适合恢复新电脑和同步最新配置。

GitHub Releases 是某个时间点的打包快照，不会随着后续源码提交自动更新。只有在需要固定使用某个已经验证过的版本时，才使用发行版；普通情况下，新电脑应直接从源码仓库恢复。

推荐选择：

- 新电脑恢复或获取最新配置：使用 `git clone`，或者下载 GitHub 仓库当前分支的 ZIP。
- 需要复现某个明确版本：下载对应的 Release ZIP，并以发行版说明为准。
- 只想快速安装且不关心最新提交：可以使用最新 Release，但先确认其发布日期和内容没有落后于源码。

## 新电脑安装

1. 从 [MPV 官方安装页](https://mpv.io/installation/) 下载 Windows MPV，解压或安装到目标目录，并确认其中存在 `mpv.exe`。
2. 在 MPV 程序目录中准备 `yt-dlp.exe`。网络视频解析功能依赖它。
3. 将本仓库恢复为 MPV 程序目录下的 `portable_config/`。
4. 可选：从 [Jellyfin MPV Player Releases](https://github.com/wzyoct/jellyfin-mpv-player/releases) 下载播放器，并按其 README 配置 MPV 的完整路径。

使用 Git 恢复时：

```powershell
cd <MPV 程序目录>
git clone https://github.com/wzyoct/mpv-config.git portable_config
```

如果不使用 Git，也可以在 GitHub 仓库页面选择 `Code` -> `Download ZIP`，解压后将仓库目录重命名为 `portable_config`，放到 `mpv.exe` 旁边。不要产生 `portable_config/portable_config/` 嵌套目录。

最终目录关系应为：

```text
mpv/
├─ mpv.exe
├─ yt-dlp.exe
└─ portable_config/
```

`mpv.conf` 会从 `portable_config/` 的上一级查找 `yt-dlp.exe`。如果移动 `portable_config/`，请保持这个相对位置。

## 已有配置的恢复

如果目标电脑已经有配置，先备份以下本机运行数据，再同步仓库文件：

- `cache/`
- `watch_later/`
- `screenshots/`
- `subtitles/`

这些目录属于本机运行数据，不参与 GitHub 同步。配置文件、脚本、字体、许可证和文档则以 GitHub 源码仓库为准。

推荐使用 Codex 执行恢复时使用以下要求：

```text
请把当前目录恢复为 GitHub 仓库 https://github.com/wzyoct/mpv-config.git 的最新 master 内容，并以 GitHub 源码为唯一配置源。

请先检查：
1. 当前目录确实是 portable_config，不要创建 portable_config/portable_config 嵌套目录。
2. 读取当前目录的 AGENTS.md 和 README.md，并遵守其中的规则。
3. 获取远程 master 的最新提交和文件清单。

同步要求：
- 完整同步 GitHub 中已跟踪的配置、脚本、字体、许可证和文档。
- 清理仓库管理范围内已经从 GitHub 删除的旧文件。
- 不要删除 mpv.exe、ffmpeg.exe、yt-dlp.exe 或其他播放器程序。
- 保留 cache/、watch_later/、screenshots/、subtitles/ 等本地运行时目录及其中内容。
- 不要修改或推送 GitHub，除非我另外明确要求。

完成后报告：远程提交号、实际同步的文件范围、保留的本地运行时内容、MPV 版本、UOSC 是否加载，以及最小启动验证结果。若发现错误，保留错误信息并停止，不要用默认值掩盖问题。
```

## 文件结构

```text
portable_config/
├── mpv.conf
├── input.conf
├── profiles.conf
├── tools/
│   ├── push-and-backup.ps1  # 推送 GitHub 并保存版本备份
│   ├── subtitle-layout.ps1 # 字幕提取、缓存和续播轨号修正
│   ├── SubtitleLayout.cs   # 字体测量、断行和双语间距
│   └── test-subtitle-layout.py # 开发环境自检
├── script-opts/uosc.conf
├── scripts/
│   ├── uosc/             # uosc 5.13.0 的 Lua 文件
│   ├── stats.lua         # mpv-stats
│   ├── cache-display.lua # 本仓库自有脚本
│   └── subtitle-layout.lua # 双语中文缩放与文字/图片字幕独立倍率
└── fonts/
    ├── LXGWWenKai-Regular.ttf
    ├── uosc_icons.otf
    └── uosc_textures.ttf
```

本配置保留 UOSC 的播放界面、快捷键、统计页和字体，但不再分发 Ziggy Windows 辅助程序。因此 UOSC 的字幕搜索/下载功能不可用；基本界面、播放控制、音轨和本地字幕加载不受影响。

配置要求 Windows 10/11（64 位）和 MPV 0.41 或更高版本。播放器目录中的 `mpv.exe`、`ffmpeg.exe` 和 `yt-dlp.exe` 属于运行环境，不放入本配置仓库。

## 配置说明

- `mpv.conf`：渲染、硬件解码、HDR、窗口、字幕、音轨默认选择、网络播放、截图和脚本选项。
- `profiles.conf`：按机器性能切换 `powerful`、`lite` 和 `default` profile；HDR 输出由 `mpv.conf` 根据 Windows 当前显示状态自动选择。
- `tools/push-and-backup.ps1`：将当前分支推送到 GitHub，并把对应提交打包备份到 `Z:\downloads\mpv`。
- `input.conf`：快捷键。UOSC 的菜单操作由 UOSC 自己管理。
- `script-opts/uosc.conf`：UOSC 的外观和行为配置。
- `scripts/stats.lua`：统计页，通过 `Shift+I` 显示或隐藏。
- `scripts/cache-display.lua`：计算缓存可观看时长和网速，并显示在 UOSC 顶栏。
- `scripts/subtitle-layout.lua`、`tools/subtitle-layout.ps1` 和 `tools/SubtitleLayout.cs`：生成 ASS/双语 SRT 播放副本、计算换行和双语间距，管理文字/图片字幕倍率。依赖 Windows 自带的 Windows PowerShell 5.1/.NET，以及播放器旁的 `ffmpeg.exe`；不安装字体或修改系统配置。
- `fonts/`：UOSC 图标、纹理和中文字幕字体。

### 字幕与音轨选择

- 字幕使用 `slang`，简体中文语言标签优先于繁体中文和未细分的中文标签。
- 文字字幕默认倍率为 `1.5`，`Alt+[` / `Alt+]` 继续调整大小。识别为中日或中英双语时，只调整中文；外语保持原始 `1.0` 倍，包括字号、描边、阴影和字间距，暂时单独出现时也不变。单语 ASS/SRT 仍可整体缩放，单语 SRT 保留原生渲染。
- ASS 保留原字体和样式，字体可来自系统、`fonts/` 或媒体附件；指定字体不可用时，libass 首先回退到 `sub-font` 指定的霞鹜文楷，缺失字形再由字体提供器补充。不会强制把所有 ASS 字体换成霞鹜文楷。
- 本地内嵌、外挂 ASS 的普通居中对白会生成播放副本。按画布、字体、倍率和边距计算硬换行，保留显式换行；普通对白中的 `\q2` 不再阻止断行。能够识别的中日、中英双语分别计算高度再安排间距；独立 ASS 事件保持中文在上、外语在下，多行对白向上扩展，顶部对白则向下扩展。同一事件按行区分的双语拆成语言块，保留原有行序和基本格式。
- 双语 SRT 经 FFmpeg 转为 ASS 播放副本，以当前 mpv 的 SRT 默认字号、字体、颜色、描边、阴影及边距作为 `1.0` 倍基准；中文使用用户倍率，外语使用 `1.0` 倍。保留时间轴、语言行序和已支持的基本格式，窗口比例变化时重新排版；含不支持的定位、字号或特效标签时明确报错，继续使用当前字幕，避免转换后破坏排版。
- 定位、移动、绘图、旋转、卡拉 OK、复杂行内字号/字体切换等特殊行保留原样，不参加普通对白重排。只处理 ASS V4+、显式声明画布且事件 `Text` 列在最后的文件；不支持的格式会报错。先分析整份字幕，优先参考明确的中文/日文/英文样式，再结合假名、汉字、拉丁文字及稳定行位判断。不能可靠区分的单行混排、无标签纯汉字等疑似双语事件保持原始 `1.0` 倍，并通过屏幕提示和控制台报告；不会猜测拆分斜杠、括号或人名。
- 生成文件和字体测量缓存位于 `subtitles/layout/`，不参与 Git 或备份，不修改视频和原字幕。首次提取内嵌 ASS 可能需要等待，处理期间继续显示当前字幕；调节倍率后后台重新排版，过期任务不会切回旧字幕。失败时显示提示、记录控制台错误并保留当前字幕。菜单中原字幕轨仍在，播放副本标为 `[自动排版]`。缓存包含 SRT 基准样式，处理代码和基准样式变化会自动使用新缓存。
- PGS 等图片字幕不能换行，首次默认倍率为 `1.0`，仍可手动放大。同次播放中文字和图片分别记住倍率，切轨不会互相覆盖；已有续播倍率仍适用于开始选择的字幕类型。保存续播后退出时，会将临时播放副本的轨号还原为原字幕轨号，保留位置、倍率和延迟。
- 字体测量使用 GDI 并校准 libass 的字号定义，宽度留有余量，但不能保证任意字体和复杂排版都精确一致。若整组普通对白超过画布高度，本次重排明确失败，需降低倍率；PGS 手动放得过大仍可能越界，特殊 ASS 行也不保证完整放入屏幕。两个独立字幕轨组成的双语、网络字幕处理、OCR 和字幕下载不在本脚本范围内。
- 未设置 `alang`，音轨完全使用 MPV 默认选择：优先采用媒体文件标记的 `default` 音轨，没有明确标记时按容器顺序选择。
- 播放过程中需要切换音轨时，使用 UOSC 的音轨菜单；配置不会根据影片国家或文件名猜测语言。

网络缓存配置：

```text
cache=yes
cache-pause=no
```

前向与后向缓存容量使用 mpv 默认值，不显式设置上限。当前安装版本的默认值分别为 150 MiB 和 50 MiB，具体值可能随 mpv 版本变化。普通整理或审查时不要擅自调整缓存策略。

## 常用快捷键

| 按键 | 行为 |
| --- | --- |
| `Space` | 暂停/继续 |
| `Enter`、双击鼠标左键 | 切换全屏 |
| `Esc` | 退出全屏 |
| 鼠标右键 | 打开 UOSC 主菜单 |
| `Ctrl+V` | 从剪贴板加载链接或路径播放 |
| `Up` / `Down` | 音量增加/减少 5 |
| `[` / `]` | 循环调整播放速度 |
| `Left` / `Right` | 后退/前进 5 秒 |
| `Alt+[` / `Alt+]` | 字幕缩小/放大 |
| `Alt+7` / `Alt+8` / `Alt+9` | 画面亮度减 1 / 加 1 / 复位为 0（仅当前进程，不保存到续播状态） |
| `` ` `` | 打开 MPV 控制台 |
| `Shift+I` | 打开/关闭统计页 |

## 修改边界

播放基础行为改 `mpv.conf`，性能档位改 `profiles.conf`，快捷键改 `input.conf`，UOSC 外观和菜单改 `script-opts/uosc.conf`，顶栏缓存信息改 `scripts/cache-display.lua`，GitHub 推送和版本备份改 `tools/push-and-backup.ps1`。除非确实是在维护第三方组件，不要直接改 UOSC 内部 Lua。

字幕逻辑修改后可运行 `python tools/test-subtitle-layout.py` 自检；添加 `--real` 会读取本次问题中的《迷宫饭》和《胜者即是正义》第一集路径，验证实际轨道、窗口/全屏及续播。测试需要开发环境中的 Python，运行播放器本身不需要 Python。测试素材、日志、隔离续播记录和截图均留在 `subtitles/layout-selftest/`。

## GitHub 推送与备份

每次完成修改、验证并提交后，在仓库根目录执行：

```powershell
.\tools\push-and-backup.ps1
```

脚本会推送当前分支到 `origin`，确认远程提交号一致后，将当前提交保存为类似 `mpv-config-20260921-120000-<commit>.zip` 的文件。备份目录是 `Z:\downloads\mpv`，其远程对应路径为 `/data/pool/downloads/mpv`；OpenList 地址为 [http://192.168.124.2:5244/N100/downloads/mpv](http://192.168.124.2:5244/N100/downloads/mpv)。

## 许可

本仓库自有配置、`cache-display.lua` 和文档使用 [MIT License](LICENSE)。第三方内容及其完整许可文本见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) 和 `LICENSES/`：

- uosc 5.13.0、UOSC 图标/纹理字体：LGPL-2.1。
- mpv-stats：LGPL-2.1。
- 霞鹜文楷 `LXGWWenKai-Regular.ttf`：SIL Open Font License 1.1。
