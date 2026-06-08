# mpv Windows 便携版全家桶

一键更新 mpv 播放器 + ffmpeg + yt-dlp + portable_config 配置。

## 文件结构

```
mpv/
├── mpv.exe, mpv.com          # mpv 主程序
├── ffmpeg.exe                # ffmpeg（可选）
├── yt-dlp.exe                # yt-dlp / youtube-dl（可选）
├── d3dcompiler_43.dll        # Direct3D 运行时
├── settings.xml              # 更新器设置（自动生成）
│
├── mpv-update.ps1            # ★ 统一更新脚本
├── updater.bat               # ★ 双击启动更新
│
├── installer/
│   ├── mpv-install.bat       # 安装到系统（注册文件关联等）
│   ├── mpv-uninstall.bat     # 卸载
│   └── updater.ps1           # 旧版更新脚本（保留备份）
│
├── portable_config/          # mpv 配置文件
│   ├── mpv.conf
│   ├── input.conf
│   ├── profiles.conf
│   ├── scripts/              # Lua 脚本
│   ├── script-opts/          # 脚本配置
│   └── fonts/                # UI 字体
│
└── doc/                      # 文档
```

## 更新

### 双击更新（推荐）

双击根目录的 **`updater.bat`**，自动检测并更新全部组件。

### 命令行

```powershell
# 默认更新全部
.\mpv-update.ps1

# 指定更新频道和架构
.\mpv-update.ps1 -Channel daily -Arch x86_64-v3

# 跳过某些组件
.\mpv-update.ps1 -SkipFFmpeg -SkipConfig

# 查看帮助
Get-Help .\mpv-update.ps1
```

### 参数说明

| 参数 | 说明 | 可选值 |
|---|---|---|
| `-Channel` | mpv 更新频道 | `daily`（每日构建）、`weekly`（每周稳定） |
| `-Arch` | 架构 | `x86_64`、`x86_64-v3`（需 AVX2）、`i686` |
| `-SkipMpv` | 跳过 mpv 检测 | — |
| `-SkipFFmpeg` | 跳过 ffmpeg 检测 | — |
| `-SkipYtplugin` | 跳过 yt-dlp/youtube-dl 检测 | — |
| `-SkipConfig` | 跳过 portable_config 检测 | — |

### 更新流程

1. 检测所有组件版本（本地 vs 远程最新）
2. 展示汇总表格
3. 确认后逐一更新
4. Config 更新前自动备份到 `portable_config.backup.时间戳`

### 更新源

| 组件 | 来源 |
|---|---|
| mpv | `shinchiro/mpv-winbuild-cmake`（daily）/ SourceForge mpv-player-windows（weekly） |
| ffmpeg | `shinchiro/mpv-winbuild-cmake` releases |
| yt-dlp | `yt-dlp/yt-dlp` GitHub releases |
| youtube-dl | yt-dl.org |
| portable_config | `wzyoct/mpv-config` GitHub |


### 首次运行设置

首次运行会询问并保存以下偏好（存储在 `settings.xml`）：

- 更新频道（weekly / daily），默认 weekly
- 架构（x86_64 / x86_64-v3），默认自动检测
- 是否安装 ffmpeg
- 更新后是否删除压缩包

之后运行不再询问，直接检测更新。

## 安装 / 卸载

以管理员身份运行：

```
installer\mpv-install.bat      # 注册文件关联、添加到系统
installer\mpv-uninstall.bat    # 移除所有注册项
```

## 配置

配置文件在 `portable_config/` 目录下，可通过更新器自动同步最新配置，也可手动修改：

- `mpv.conf` — 主配置
- `input.conf` — 快捷键
- `profiles.conf` — 条件配置
- `scripts/` — Lua 扩展脚本

## 系统要求

- Windows 7+（64 位 / 32 位）
- PowerShell 3.0+

## 许可

mpv 及其组件遵循各自的开源许可。更新脚本为公共领域。

