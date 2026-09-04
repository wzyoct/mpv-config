# mpv-config

面向 Windows 便携版 MPV 的独立配置包，包含 uosc 播放界面、统计页、网络缓存和字体。它不包含 MPV 程序，也不属于 [Jellyfin MPV Player](https://github.com/wzyoct/jellyfin-mpv-player) 的源码依赖。

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

也可以使用 HTTPS 克隆源码进行开发：

```powershell
git clone https://github.com/wzyoct/mpv-config.git portable_config
```

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

配置要求 Windows 10/11（64 位）和 MPV 0.41 或更高版本。`mpv.conf` 中的大容量网络缓存是针对网络较差、主机性能较高的环境设置的；如需调整，请先理解对应 MPV 选项的影响。
播放器目录中的 `mpv.exe`、`ffmpeg.exe` 和 `yt-dlp.exe` 属于运行环境，不需要放进这个配置仓库。
`watch_later/`、`cache/`、`screenshots/` 和 `subtitles/` 是运行时数据，已由 `.gitignore` 排除。

## 许可

本仓库自有配置、`cache-display.lua` 和文档使用 [MIT License](LICENSE)。仓库同时分发的第三方内容及其完整许可文本见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) 和 `LICENSES/`：

- uosc 5.13.0、uosc 图标/纹理字体：LGPL-2.1。
- mpv-stats：LGPL-2.1。
- 霞鹜文楷 `LXGWWenKai-Regular.ttf`：SIL Open Font License 1.1。
