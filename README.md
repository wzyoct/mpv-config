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
├── script-opts/uosc.conf
├── scripts/
│   ├── uosc/             # uosc 5.13.0 的 Lua 文件
│   ├── stats.lua         # mpv-stats
│   └── cache-display.lua # 本仓库自有脚本
└── fonts/
    ├── LXGWWenKai-Regular.ttf
    ├── uosc_icons.otf
    └── uosc_textures.ttf
```

本配置保留 UOSC 的播放界面、快捷键、统计页和字体，但不再分发 Ziggy Windows 辅助程序。因此 UOSC 的字幕搜索/下载功能不可用；基本界面、播放控制、音轨和本地字幕加载不受影响。

配置要求 Windows 10/11（64 位）和 MPV 0.41 或更高版本。播放器目录中的 `mpv.exe`、`ffmpeg.exe` 和 `yt-dlp.exe` 属于运行环境，不放入本配置仓库。

## 配置说明

- `mpv.conf`：渲染、硬件解码、HDR、窗口、字幕、音轨优先级、网络播放、截图和脚本选项。
- `profiles.conf`：按机器性能和视频条件切换 `powerful`、`lite`、`default`、`HDR-direct` 等 profile。
- `input.conf`：快捷键。UOSC 的菜单操作由 UOSC 自己管理。
- `script-opts/uosc.conf`：UOSC 的外观和行为配置。
- `scripts/stats.lua`：统计页，通过 `Shift+I` 显示或隐藏。
- `scripts/cache-display.lua`：计算缓存可观看时长和网速，并显示在 UOSC 顶栏。
- `fonts/`：UOSC 图标、纹理和中文字幕字体。

网络缓存是本配置的固定策略：

```text
demuxer-max-bytes=2048MiB
demuxer-max-back-bytes=256MiB
cache-pause=no
```

该策略针对网络较差、主机性能较高的环境，普通整理或审查时不要擅自调整。

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
| `` ` `` | 打开 MPV 控制台 |
| `Shift+I` | 打开/关闭统计页 |

## 修改边界

播放基础行为改 `mpv.conf`，性能档位改 `profiles.conf`，快捷键改 `input.conf`，UOSC 外观和菜单改 `script-opts/uosc.conf`，顶栏缓存信息改 `scripts/cache-display.lua`。除非确实是在维护第三方组件，不要直接改 UOSC 内部 Lua。

## 许可

本仓库自有配置、`cache-display.lua` 和文档使用 [MIT License](LICENSE)。第三方内容及其完整许可文本见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) 和 `LICENSES/`：

- uosc 5.13.0、UOSC 图标/纹理字体：LGPL-2.1。
- mpv-stats：LGPL-2.1。
- 霞鹜文楷 `LXGWWenKai-Regular.ttf`：SIL Open Font License 1.1。
