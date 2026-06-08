# mpv-config

mpv Windows 便携版配置 + 一键更新脚本。

## 文件

```
├── mpv-update.ps1           # 统一更新脚本
├── updater.bat              # 双击启动更新
├── settings.xml             # 更新器设置
└── portable_config/         # mpv 配置
    ├── mpv.conf
    ├── input.conf
    ├── profiles.conf
    ├── scripts/
    ├── script-opts/
    └── fonts/
```

## 使用

把本仓库 clone 到 mpv 便携版根目录（与 mpv.exe 同级），双击 `updater.bat` 即可检查和更新全部组件。

```powershell
# 双击
updater.bat

# 或命令行
.\mpv-update.ps1

# 跳过某些组件、指定参数
.\mpv-update.ps1 -Channel daily -SkipFFmpeg
```

## 更新组件

| 组件 | 来源 |
|---|---|
| mpv | shinchiro/mpv-winbuild-cmake（daily）/ SourceForge（weekly） |
| ffmpeg | shinchiro/mpv-winbuild-cmake |
| yt-dlp / youtube-dl | GitHub / yt-dl.org |
| portable_config | 本仓库最新 commit |

## 更新流程

1. 检测所有组件版本
2. 展示汇总状态表
3. 确认后逐一更新
4. Config 更新前自动备份

## 参数

| 参数 | 说明 |
|---|---|
| `-Channel` | `daily` / `weekly`（默认 weekly） |
| `-Arch` | `x86_64` / `x86_64-v3` / `i686` |
| `-SkipMpv` | 跳过 mpv |
| `-SkipFFmpeg` | 跳过 ffmpeg |
| `-SkipYtplugin` | 跳过 yt-dlp |
| `-SkipConfig` | 跳过 config |
