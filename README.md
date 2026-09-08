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

## 许可

本仓库自有配置、`cache-display.lua` 和文档使用 [MIT License](LICENSE)。仓库同时分发的第三方内容及其完整许可文本见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) 和 `LICENSES/`：

- uosc 5.13.0、uosc 图标/纹理字体：LGPL-2.1。
- mpv-stats：LGPL-2.1。
- 霞鹜文楷 `LXGWWenKai-Regular.ttf`：SIL Open Font License 1.1。
