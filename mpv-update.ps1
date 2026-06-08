[CmdletBinding()]
param(
    [ValidateSet("daily", "weekly")]
    [string]$Channel = "",
    [ValidateSet("i686", "x86_64", "x86_64-v3")]
    [string]$Arch = "",
    [switch]$SkipMpv,
    [switch]$SkipFFmpeg,
    [switch]$SkipYtplugin,
    [switch]$SkipConfig
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# ============================================================
# Configuration
# ============================================================
$Script:ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
Set-Location $Script:ScriptRoot

$Script:UserAgent = "mpv-win-updater"
$Script:Fallback7z = Join-Path $Script:ScriptRoot "7z\7zr.exe"
$Script:SettingsFile = Join-Path $Script:ScriptRoot "settings.xml"

$Script:ConfigRepo = "wzyoct/mpv-config"
$Script:ConfigBranch = "master"
$Script:ConfigDir = "portable_config"
$Script:ConfigVersionFile = Join-Path $Script:ScriptRoot "$Script:ConfigDir\.config-version"

$Script:GithubProxies = @(
    "https://github.com/",
    "https://gh-proxy.com/https://github.com/",
    "https://ghfast.top/https://github.com/"
)

# ============================================================
# Helper: 7z detection and extraction
# ============================================================
function Get-7z {
    $7z_command = Get-Command -CommandType Application -ErrorAction Ignore 7z.exe | Select-Object -Last 1
    if ($7z_command) { return $7z_command.Source }
    $7zdir = Get-ItemPropertyValue -ErrorAction Ignore "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\7-Zip" "InstallLocation"
    if ($7zdir -and (Test-Path (Join-Path $7zdir "7z.exe"))) { return Join-Path $7zdir "7z.exe" }
    if (Test-Path $Script:Fallback7z) { return $Script:Fallback7z }
    return $null
}

function Initialize-7z {
    if (-not (Get-7z)) {
        $null = New-Item -ItemType Directory -Force (Split-Path $Script:Fallback7z)
        Write-Host "  Downloading 7zr.exe..." -ForegroundColor Gray
        try {
            Invoke-WebRequest -Uri "https://www.7-zip.org/a/7zr.exe" -UserAgent $Script:UserAgent -OutFile $Script:Fallback7z
            Write-Host "  7zr.exe ready." -ForegroundColor Green
        } catch {
            Write-Host "  WARN: Could not download 7zr.exe" -ForegroundColor DarkYellow
        }
    }
}

function Expand-Archive7z {
    param([string]$File)
    $7z = Get-7z
    if (-not $7z) { throw "7z not available; cannot extract $File" }
    Write-Host "  Extracting $File ..." -ForegroundColor Gray
    & $7z x -y $File | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "7z extraction failed for $File" }
}

# ============================================================
# Helper: Download with GitHub fallback (direct + 2 proxies)
# ============================================================
function Invoke-GitHubDownload {
    param(
        [string]$DirectUrl,
        [string]$OutFile,
        [string]$Description = "file",
        [int]$TimeoutSec = 60
    )
    $urls = @($DirectUrl)
    foreach ($proxy in $Script:GithubProxies) {
        if ($proxy -eq $Script:GithubProxies[0]) { continue }
        $wrapped = $DirectUrl -replace '^https://github\.com/', $proxy
        if ($wrapped -ne $DirectUrl) { $urls += $wrapped }
    }
    $labels = @("Direct", "gh-proxy", "ghfast")
    for ($i = 0; $i -lt $urls.Count -and $i -lt $labels.Count; $i++) {
        $url = $urls[$i]
        $label = $labels[$i]
        Write-Host "  [$label] $url" -ForegroundColor Gray
        try {
            if (Test-Path $OutFile) { Remove-Item -Force $OutFile }
            Invoke-WebRequest -Uri $url -OutFile $OutFile -UserAgent $Script:UserAgent `
                -UseBasicParsing -TimeoutSec $TimeoutSec
            if (Test-Path $OutFile) {
                $bytes = (Get-Item $OutFile).Length
                if ($bytes -gt 100) {
                    Write-Host "  OK  $bytes bytes" -ForegroundColor Green
                    return $true
                }
            }
            Write-Host "  WARN  File too small, trying next..." -ForegroundColor DarkYellow
        } catch {
            Write-Host "  FAIL  $($_.Exception.Message)" -ForegroundColor DarkYellow
        }
        Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
    }
    return $false
}

# ============================================================
# Helper: Admin check
# ============================================================
function Test-Admin {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

# ============================================================
# Settings management (channel, arch, autodelete, getffmpeg)
# ============================================================
function Initialize-Settings {
    if (-not (Test-Path $Script:SettingsFile)) {
        $xml = @"
<settings>
  <channel>unset</channel>
  <arch>unset</arch>
  <autodelete>unset</autodelete>
  <getffmpeg>unset</getffmpeg>
</settings>
"@
        $xml | Set-Content $Script:SettingsFile -Encoding UTF8
    }
}

function Get-Setting {
    param([string]$Key)
    Initialize-Settings
    [xml]$doc = Get-Content $Script:SettingsFile
    return $doc.settings.$Key
}

function Set-Setting {
    param([string]$Key, [string]$Value)
    Initialize-Settings
    [xml]$doc = Get-Content $Script:SettingsFile
    $doc.settings.$Key = $Value
    $doc.Save($Script:SettingsFile)
}

# ============================================================
# Architecture detection
# ============================================================
function Get-MpvArch {
    $mpvPath = Join-Path $Script:ScriptRoot "mpv.exe"
    if (-not (Test-Path $mpvPath)) { return $null }
    [int32]$MACHINE_OFFSET = 4
    [int32]$PE_POINTER_OFFSET = 60
    [byte[]]$data = New-Object -TypeName System.Byte[] -ArgumentList 4096
    $stream = New-Object -TypeName System.IO.FileStream -ArgumentList ($mpvPath, 'Open', 'Read')
    $stream.Read($data, 0, 4096) | Out-Null
    [int32]$PE_HEADER_ADDR = [System.BitConverter]::ToInt32($data, $PE_POINTER_OFFSET)
    [int32]$machineUint = [System.BitConverter]::ToUInt16($data, $PE_HEADER_ADDR + $MACHINE_OFFSET)
    $stream.Close()
    switch ($machineUint) {
        0x014c { return 'i686' }
        0x8664 { return 'x86_64' }
        default { return $null }
    }
}

function Get-SystemArch {
    if (Test-Path (Join-Path $env:windir "SysWow64")) { return "x86_64" }
    return "i686"
}

function Resolve-MpvArch {
    param([string]$OverrideArch)
    if ($OverrideArch) { return $OverrideArch }
    $saved = Get-Setting "arch"
    if ($saved -ne "unset") { return $saved }
    $detected = Get-MpvArch
    if ($detected) {
        if ($detected -eq "x86_64") {
            Write-Host "Detected mpv arch: x86_64" -ForegroundColor Gray
            $choice = Read-Choice "x86_64 or x86_64-v3? [1=x86_64 / 2=x86_64-v3]" @("D1","D2") "D1" 9
            $arch = if ($choice -eq "D1") { "x86_64" } else { "x86_64-v3" }
            Set-Setting "arch" $arch
            return $arch
        }
        Set-Setting "arch" $detected
        return $detected
    }
    $sysArch = Get-SystemArch
    if ($sysArch -eq "x86_64") {
        $choice = Read-Choice "Choose arch [1=x86_64 / 2=x86_64-v3]" @("D1","D2") "D1" 9
        $arch = if ($choice -eq "D1") { "x86_64" } else { "x86_64-v3" }
        Set-Setting "arch" $arch
        return $arch
    }
    Set-Setting "arch" "i686"
    return "i686"
}

# ============================================================
# Interactive helpers
# ============================================================
function Read-Choice {
    param([string]$Prompt, [string[]]$ValidKeys, [string]$DefaultKey, [int]$TimeoutSec = 9)
    Write-Host "$Prompt (default=$($DefaultKey[-1])) " -ForegroundColor Green -NoNewline
    $startTime = Get-Date
    $timeOut = New-TimeSpan -Seconds $TimeoutSec
    [Console]::CursorLeft = 0
    [Console]::Write("[")
    [Console]::CursorLeft = $TimeoutSec + 2
    [Console]::Write("]")
    [Console]::CursorLeft = 1
    while (-not [System.Console]::KeyAvailable) {
        Start-Sleep -Seconds 1
        Write-Host "#" -ForegroundColor Green -NoNewline
        if ((Get-Date) -gt $startTime + $timeOut) { break }
    }
    Write-Host ""
    if ([System.Console]::KeyAvailable) {
        $response = [System.Console]::ReadKey($true).Key.ToString()
    } else {
        $response = $DefaultKey
    }
    return $response
}

function Read-YesNo {
    param([string]$Prompt, [string]$Default = "N")
    $choice = Read-Choice "$Prompt [Y/n]" @("Y","N") $Default 9
    return ($choice -eq "Y")
}

# ============================================================
# Component: mpv
# ============================================================
function Get-Latest-Mpv {
    param([string]$Arch, [string]$Channel)
    $filename = ""
    $download_link = ""
    switch -wildcard ($Channel) {
        "daily" {
            $apiUrl = "https://api.github.com/repos/shinchiro/mpv-winbuild-cmake/releases/latest"
            $json = $null
            $apiUrls = @($apiUrl)
            foreach ($proxy in $Script:GithubProxies) {
                if ($proxy -eq $Script:GithubProxies[0]) { continue }
                $wrapped = $apiUrl -replace '^https://api\.github\.com/', $proxy -replace 'github\.com/', $proxy
                if ($wrapped -ne $apiUrl) { $apiUrls += $wrapped }
            }
            foreach ($url in $apiUrls) {
                try {
                    $json = Invoke-WebRequest $url -MaximumRedirection 0 -ErrorAction Ignore -UseBasicParsing | ConvertFrom-Json
                    if ($json -and $json.assets) { break }
                } catch { }
            }
            if ($json -and $json.assets) {
                $filename = $json.assets | Where-Object { $_.name -Match "mpv-$Arch" } | Select-Object -ExpandProperty name
                $download_link = $json.assets | Where-Object { $_.name -Match "mpv-$Arch" } | Select-Object -ExpandProperty browser_download_url
            }
        }
        "weekly" {
            $rssMap = @{
                "i686"      = "https://sourceforge.net/projects/mpv-player-windows/rss?path=/32bit"
                "x86_64"    = "https://sourceforge.net/projects/mpv-player-windows/rss?path=/64bit"
                "x86_64-v3" = "https://sourceforge.net/projects/mpv-player-windows/rss?path=/64bit-v3"
            }
            $rssLink = $rssMap[$Arch]
            if (-not $rssLink) { return $null, $null }
            try {
                $result = [xml](New-Object System.Net.WebClient).DownloadString($rssLink)
                $latest = $result.rss.channel.item.link[0]
                $tempname = $latest.split("/")[-2]
                $filename = [System.Uri]::UnescapeDataString($tempname)
                $download_link = "https://download.sourceforge.net/mpv-player-windows/" + $filename
            } catch {
                Write-Host "  WARN: Failed to fetch SourceForge RSS" -ForegroundColor DarkYellow
                return $null, $null
            }
        }
    }
    if ($filename -is [array]) { return $filename[0], $download_link[0] }
    return $filename, $download_link
}

function Get-InstalledMpvInfo {
    $mpvPath = Join-Path $Script:ScriptRoot "mpv.exe"
    if (-not (Test-Path $mpvPath)) { return $null }
    $info = @{}
    try {
        $output = & $mpvPath --no-config --version 2>&1 | Out-String
        if ($output -match "mpv ([0-9.]+)") {
            $info.Version = $matches[1]
        }
        if ($output -match "-g([a-z0-9-]{7})") {
            $info.GitCommit = $matches[1]
        }
    } catch { }
    $info.FileDate = (Get-Item $mpvPath).LastWriteTimeUtc.ToString("yyyyMMdd")
    $info.Arch = Get-MpvArch
    return $info
}

function Test-MpvUpdateNeeded {
    param([string]$Arch, [string]$Channel)
    $result = [PSCustomObject]@{
        Component = "mpv"
        Status = "NOT_INSTALLED"
        CurrentVersion = "-"
        LatestVersion = "-"
        RemoteName = ""
        DownloadUrl = ""
        Channel = $Channel
        Arch = $Arch
    }
    $installed = Get-InstalledMpvInfo
    $remoteName, $downloadUrl = Get-Latest-Mpv $Arch $Channel
    if (-not $remoteName) {
        $result.Status = "ERROR"
        $result.LatestVersion = "(fetch failed)"
        return $result
    }
    $result.RemoteName = $remoteName
    $result.DownloadUrl = $downloadUrl
    $result.LatestVersion = $remoteName
    if (-not $installed) {
        $result.Status = "NOT_INSTALLED"
        return $result
    }
    $result.CurrentVersion = "$($installed.FileDate) g$($installed.GitCommit)"
    $remoteGit = ""
    if ($remoteName -match "-git-([a-z0-9-]{7})") { $remoteGit = $matches[1] }
    $remoteDate = ""
    if ($remoteName -match "mpv-[xi864_].*-([0-9]{8})-git-") { $remoteDate = $matches[1] }
    if ($installed.GitCommit -and $remoteGit -and ($installed.GitCommit -eq $remoteGit)) {
        if ($installed.FileDate -eq $remoteDate) {
            $result.Status = "LATEST"
        } else {
            $result.Status = "UPDATE"
        }
    } else {
        $result.Status = "UPDATE"
    }
    return $result
}

function Update-Mpv {
    param([PSCustomObject]$Info)
    if ($Info.Channel -eq "weekly") {
        Write-Host "  Downloading $($Info.RemoteName) from SourceForge..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri $Info.DownloadUrl -UserAgent $Script:UserAgent -OutFile $Info.RemoteName
        } catch {
            Write-Host "  ERROR: Download failed" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "  Downloading $($Info.RemoteName)..." -ForegroundColor Yellow
        if (-not (Invoke-GitHubDownload $Info.DownloadUrl $Info.RemoteName "mpv archive")) {
            Write-Host "  ERROR: All download sources failed" -ForegroundColor Red
            return $false
        }
    }
    Initialize-7z
    Expand-Archive7z $Info.RemoteName
    Cleanup-Archive $Info.RemoteName
    return $true
}

# ============================================================
# Component: ffmpeg
# ============================================================
function Get-Latest-FFmpeg {
    param([string]$Arch)
    $apiUrl = "https://api.github.com/repos/shinchiro/mpv-winbuild-cmake/releases/latest"
    $json = $null
    $apiUrls = @($apiUrl)
    foreach ($proxy in $Script:GithubProxies) {
        if ($proxy -eq $Script:GithubProxies[0]) { continue }
        $wrapped = $apiUrl -replace '^https://api\.github\.com/', $proxy -replace 'github\.com/', $proxy
        if ($wrapped -ne $apiUrl) { $apiUrls += $wrapped }
    }
    foreach ($url in $apiUrls) {
        try {
            $json = Invoke-WebRequest $url -MaximumRedirection 0 -ErrorAction Ignore -UseBasicParsing | ConvertFrom-Json
            if ($json -and $json.assets) { break }
        } catch { }
    }
    if (-not $json -or -not $json.assets) { return $null, $null }
    $filename = $json.assets | Where-Object { $_.name -Match "ffmpeg-$Arch" } | Select-Object -ExpandProperty name
    $download_link = $json.assets | Where-Object { $_.name -Match "ffmpeg-$Arch" } | Select-Object -ExpandProperty browser_download_url
    if ($filename -is [array]) { return $filename[0], $download_link[0] }
    return $filename, $download_link
}

function Test-FFmpegUpdateNeeded {
    param([string]$Arch)
    $result = [PSCustomObject]@{
        Component = "ffmpeg"
        Status = "NOT_INSTALLED"
        CurrentVersion = "-"
        LatestVersion = "-"
        RemoteName = ""
        DownloadUrl = ""
        Arch = $Arch
    }
    $getFfmpeg = Get-Setting "getffmpeg"
    if ($getFfmpeg -eq "false") {
        $result.Status = "SKIPPED"
        return $result
    }
    $remoteName, $downloadUrl = Get-Latest-FFmpeg $Arch
    if (-not $remoteName) {
        $result.Status = "ERROR"
        $result.LatestVersion = "(fetch failed)"
        return $result
    }
    $result.RemoteName = $remoteName
    $result.DownloadUrl = $downloadUrl
    $result.LatestVersion = $remoteName
    $ffmpegPath = Join-Path $Script:ScriptRoot "ffmpeg.exe"
    if (-not (Test-Path $ffmpegPath)) {
        if ($getFfmpeg -eq "unset") {
            Write-Host ""
            $want = Read-YesNo "FFmpeg not found. Download it?" "Y"
            Set-Setting "getffmpeg" $(if ($want) { "true" } else { "false" })
            if (-not $want) { $result.Status = "SKIPPED"; return $result }
        }
        $result.Status = "NOT_INSTALLED"
        return $result
    }
    try {
        $ffmpegVer = & $ffmpegPath -version 2>&1 | Select-String "ffmpeg" | Select-Object -First 1
        $localPattern = "git-[0-9]{4}-[0-9]{2}-[0-9]{2}-(?<commit>[a-z0-9]+)|N-\d+-g(?<commit>[a-z0-9]+)"
        $remotePattern = "git-([a-z0-9]+)"
        $localMatch = [Regex]::Matches($ffmpegVer, $localPattern)
        $remoteMatch = [Regex]::Matches($remoteName, $remotePattern)
        if ($localMatch.Count -gt 0 -and $remoteMatch.Count -gt 0) {
            $localCommit = $localMatch[0].Groups['commit'].Value
            $remoteCommit = $remoteMatch[0].Groups[1].Value
            $result.CurrentVersion = "git-$localCommit"
            if ($localCommit -match $remoteCommit) {
                $result.Status = "LATEST"
            } else {
                $result.Status = "UPDATE"
            }
        } else {
            $result.CurrentVersion = "(unknown)"
            $result.Status = "UPDATE"
        }
    } catch {
        $result.CurrentVersion = "(error)"
        $result.Status = "UPDATE"
    }
    return $result
}

function Update-FFmpeg {
    param([PSCustomObject]$Info)
    Write-Host "  Downloading $($Info.RemoteName)..." -ForegroundColor Yellow
    if (-not (Invoke-GitHubDownload $Info.DownloadUrl $Info.RemoteName "ffmpeg archive")) {
        Write-Host "  ERROR: All download sources failed" -ForegroundColor Red
        return $false
    }
    Initialize-7z
    Expand-Archive7z $Info.RemoteName
    Cleanup-Archive $Info.RemoteName
    return $true
}

# ============================================================
# Component: yt-dlp / youtube-dl
# ============================================================
function Get-Latest-Ytplugin {
    param([string]$Plugin)
    switch -wildcard ($Plugin) {
        "yt-dlp*" {
            $apiUrl = "https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest"
            $json = $null
            $apiUrls = @($apiUrl)
            foreach ($proxy in $Script:GithubProxies) {
                if ($proxy -eq $Script:GithubProxies[0]) { continue }
                $wrapped = $apiUrl -replace '^https://api\.github\.com/', $proxy -replace 'github\.com/', $proxy
                if ($wrapped -ne $apiUrl) { $apiUrls += $wrapped }
            }
            foreach ($url in $apiUrls) {
                try {
                    $json = Invoke-WebRequest $url -MaximumRedirection 0 -ErrorAction Ignore -UseBasicParsing | ConvertFrom-Json
                    if ($json -and $json.tag_name) { break }
                } catch { }
            }
            if ($json -and $json.tag_name) { return $json.tag_name }
            return $null
        }
        "youtube-dl" {
            try {
                $resp = Invoke-WebRequest "https://yt-dl.org/downloads/latest/youtube-dl.exe" `
                    -MaximumRedirection 0 -ErrorAction Ignore -UseBasicParsing
                return $resp.Headers.Location.split("/")[4]
            } catch { return $null }
        }
    }
    return $null
}

function Get-InstalledYtplugin {
    $ytdlp = Get-ChildItem (Join-Path $Script:ScriptRoot "yt-dlp*.exe") -ErrorAction Ignore
    $ytdl = Get-ChildItem (Join-Path $Script:ScriptRoot "youtube-dl.exe") -ErrorAction Ignore
    if ($ytdlp) { return $ytdlp.Name }
    if ($ytdl) { return $ytdl.Name }
    return $null
}

function Test-YtpluginInSystemPath {
    $ytp = Get-Command -CommandType Application -ErrorAction Ignore yt-dlp.exe | Select-Object -Last 1
    if (-not $ytp) { $ytp = Get-Command -CommandType Application -ErrorAction Ignore youtube-dl.exe | Select-Object -Last 1 }
    return [bool]($ytp -and ((Split-Path $ytp.Source) -ne $Script:ScriptRoot))
}

function Test-YtpluginUpdateNeeded {
    $result = [PSCustomObject]@{
        Component = "yt-dlp/youtube-dl"
        Status = "NOT_INSTALLED"
        CurrentVersion = "-"
        LatestVersion = "-"
        PluginName = ""
    }
    if (Test-YtpluginInSystemPath) {
        $result.Status = "SKIPPED"
        $result.CurrentVersion = "(in system PATH)"
        return $result
    }
    $plugin = Get-InstalledYtplugin
    if (-not $plugin) {
        $result.Status = "NOT_INSTALLED"
        return $result
    }
    $result.PluginName = $plugin
    $baseName = (Get-Item (Join-Path $Script:ScriptRoot $plugin)).BaseName
    try {
        $installedVer = & (Join-Path $Script:ScriptRoot $plugin) --version 2>&1 | Out-String
        $installedVer = $installedVer.Trim()
        $result.CurrentVersion = $installedVer
    } catch {
        $result.CurrentVersion = "(unknown)"
    }
    $latestVer = Get-Latest-Ytplugin $baseName
    if (-not $latestVer) {
        $result.Status = "ERROR"
        $result.LatestVersion = "(fetch failed)"
        return $result
    }
    $result.LatestVersion = $latestVer
    if ($result.CurrentVersion -match $latestVer) {
        $result.Status = "LATEST"
    } else {
        $result.Status = "UPDATE"
    }
    return $result
}

function Update-Ytplugin {
    param([PSCustomObject]$Info)
    $plugin = Get-InstalledYtplugin
    if ($plugin) {
        Write-Host "  Updating $plugin via --update..." -ForegroundColor Yellow
        try {
            $exePath = Join-Path $Script:ScriptRoot $plugin
            & $exePath --update 2>&1 | Out-Host
            return $true
        } catch {
            Write-Host "  ERROR: Update failed" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host ""
        $choice = Read-Choice "Download yt-dlp or youtube-dl? [1=yt-dlp / 2=youtube-dl]" @("D1","D2") "D1" 9
        $pluginName = if ($choice -eq "D1") { "yt-dlp" } else { "youtube-dl" }
        $version = Get-Latest-Ytplugin $pluginName
        if (-not $version) {
            Write-Host "  ERROR: Could not determine latest version" -ForegroundColor Red
            return $false
        }
        if ($pluginName -eq "yt-dlp") {
            $suffix = ""
            if (-not (Test-Path (Join-Path $env:windir "SysWow64"))) { $suffix = "_x86" }
            $fileName = "yt-dlp$suffix.exe"
            $directUrl = "https://github.com/yt-dlp/yt-dlp/releases/download/$version/$fileName"
            Write-Host "  Downloading yt-dlp $version ..." -ForegroundColor Yellow
            $dlFile = Join-Path $Script:ScriptRoot "yt-dlp.exe"
            if (-not (Invoke-GitHubDownload $directUrl $dlFile "yt-dlp")) {
                Write-Host "  ERROR: All download sources failed" -ForegroundColor Red
                return $false
            }
        } else {
            $dlFile = Join-Path $Script:ScriptRoot "youtube-dl.exe"
            $dlUrl = "https://yt-dl.org/downloads/$version/youtube-dl.exe"
            Write-Host "  Downloading youtube-dl $version ..." -ForegroundColor Yellow
            try {
                Invoke-WebRequest -Uri $dlUrl -UserAgent $Script:UserAgent -OutFile $dlFile
            } catch {
                Write-Host "  ERROR: Download failed" -ForegroundColor Red
                return $false
            }
        }
        return $true
    }
}

# ============================================================
# Component: portable_config
# ============================================================
function Get-Latest-ConfigCommit {
    $apiUrl = "https://api.github.com/repos/$Script:ConfigRepo/commits/$Script:ConfigBranch"
    $apiUrls = @($apiUrl)
    foreach ($proxy in $Script:GithubProxies) {
        if ($proxy -eq $Script:GithubProxies[0]) { continue }
        $wrapped = $apiUrl -replace '^https://api\.github\.com/', $proxy -replace 'github\.com/', $proxy
        if ($wrapped -ne $apiUrl) { $apiUrls += $wrapped }
    }
    foreach ($url in $apiUrls) {
        try {
            $json = Invoke-WebRequest $url -MaximumRedirection 0 -ErrorAction Ignore -UseBasicParsing | ConvertFrom-Json
            if ($json -and $json.sha) { return $json.sha.Substring(0, 7) }
        } catch { }
    }
    return $null
}

function Get-InstalledConfigVersion {
    if (Test-Path $Script:ConfigVersionFile) {
        return (Get-Content $Script:ConfigVersionFile -Raw).Trim()
    }
    $configPath = Join-Path $Script:ScriptRoot $Script:ConfigDir
    if (Test-Path $configPath) { return "(no version file)" }
    return $null
}

function Test-ConfigUpdateNeeded {
    $result = [PSCustomObject]@{
        Component = "portable_config"
        Status = "NOT_INSTALLED"
        CurrentVersion = "-"
        LatestVersion = "-"
    }
    $configPath = Join-Path $Script:ScriptRoot $Script:ConfigDir
    $local = Get-InstalledConfigVersion
    $remote = Get-Latest-ConfigCommit
    if (-not $remote) {
        $result.Status = "ERROR"
        $result.LatestVersion = "(fetch failed)"
        if ($local) { $result.CurrentVersion = $local; $result.Status = "UNKNOWN" }
        return $result
    }
    $result.LatestVersion = $remote
    if (-not $local) {
        if (Test-Path $configPath) {
            $result.Status = "UPDATE"
            $result.CurrentVersion = "(no version file)"
        } else {
            $result.Status = "NOT_INSTALLED"
        }
        return $result
    }
    $result.CurrentVersion = $local
    if ($local -eq $remote) {
        $result.Status = "LATEST"
    } else {
        $result.Status = "UPDATE"
    }
    return $result
}

function Update-Config {
    param([PSCustomObject]$Info)
    $directUrl = "https://github.com/$Script:ConfigRepo/archive/refs/heads/$Script:ConfigBranch.zip"
    $zipFile = Join-Path $Script:ScriptRoot "mpv-config-update.zip"
    Write-Host "  Downloading config archive..." -ForegroundColor Yellow
    if (-not (Invoke-GitHubDownload $directUrl $zipFile "config archive" 60)) {
        Write-Host "  ERROR: All download sources failed" -ForegroundColor Red
        return $false
    }
    # Verify ZIP
    $bytes = [System.IO.File]::ReadAllBytes($zipFile)
    if ($bytes.Length -le 100 -or $bytes[0] -ne 0x50 -or $bytes[1] -ne 0x4B) {
        Write-Host "  ERROR: Downloaded file is not a valid ZIP" -ForegroundColor Red
        Remove-Item $zipFile -Force -ErrorAction SilentlyContinue
        return $false
    }
    # Backup existing config
    $configPath = Join-Path $Script:ScriptRoot $Script:ConfigDir
    if (Test-Path $configPath) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupDir = "$Script:ConfigDir.backup.$timestamp"
        $backupPath = Join-Path $Script:ScriptRoot $backupDir
        Write-Host "  Backing up to: $backupDir" -ForegroundColor Gray
        if (Test-Path $backupPath) { Remove-Item -Recurse -Force $backupPath }
        Move-Item $configPath $backupPath
        Write-Host "  Backup saved." -ForegroundColor Green
    }
    # Extract
    $tempDir = Join-Path $Script:ScriptRoot "mpv-config-temp"
    if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
    try {
        Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force
        $innerDir = Get-ChildItem -Path $tempDir -Directory | Select-Object -First 1
        if (-not $innerDir) { $innerDir = Get-Item $tempDir }
        New-Item -ItemType Directory -Force -Path $configPath | Out-Null
        Get-ChildItem -Path $innerDir.FullName | ForEach-Object {
            Move-Item -Path $_.FullName -Destination (Join-Path $configPath $_.Name) -Force
        }
    } finally {
        Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
        Remove-Item -Force $zipFile -ErrorAction SilentlyContinue
    }
    # Save version
    $Info.LatestVersion | Set-Content $Script:ConfigVersionFile -NoNewline
    $fileCount = (Get-ChildItem -Path $configPath -Recurse -File | Measure-Object).Count
    Write-Host "  Config extracted: $fileCount files" -ForegroundColor Green
    return $true
}

# ============================================================
# Archive cleanup (respect autodelete setting)
# ============================================================
function Cleanup-Archive {
    param([string]$File)
    $autodelete = Get-Setting "autodelete"
    if ($autodelete -eq "unset") {
        $choice = Read-Choice "Delete archive after extract? [Y/n]" @("Y","N") "Y" 9
        Set-Setting "autodelete" $(if ($choice -eq "Y") { "true" } else { "false" })
    }
    if ((Get-Setting "autodelete") -eq "true") {
        if (Test-Path $File) {
            Remove-Item -Force $File
            Write-Host "  Archive deleted." -ForegroundColor Gray
        }
    }
}

# ============================================================
# Channel selection
# ============================================================
function Resolve-MpvChannel {
    param([string]$OverrideChannel)
    if ($OverrideChannel) { return $OverrideChannel }
    $saved = Get-Setting "channel"
    if ($saved -ne "unset") { return $saved }
    $choice = Read-Choice "Choose mpv update channel [1=weekly / 2=daily]" @("D1","D2") "D1" 9
    $channel = if ($choice -eq "D1") { "weekly" } else { "daily" }
    Set-Setting "channel" $channel
    return $channel
}

# ============================================================
# Status formatting
# ============================================================
function Write-StatusLine {
    param([PSCustomObject]$Item)
    $color = switch ($Item.Status) {
        "LATEST" { "Green" }
        "UPDATE" { "Yellow" }
        "NOT_INSTALLED" { "Cyan" }
        "SKIPPED" { "DarkGray" }
        "ERROR" { "Red" }
        "UNKNOWN" { "DarkYellow" }
        default { "White" }
    }
    $icon = switch ($Item.Status) {
        "LATEST" { "[OK]" }
        "UPDATE" { "[UP]" }
        "NOT_INSTALLED" { "[+] " }
        "SKIPPED" { "[--]" }
        "ERROR" { "[!!]" }
        "UNKNOWN" { "[??]" }
        default { "[  ]" }
    }
    $name = $Item.Component.PadRight(22)
    $status = $Item.Status.PadRight(14)
    $current = $Item.CurrentVersion.PadRight(24)
    $latest = $Item.LatestVersion
    Write-Host "  $icon  " -NoNewline
    Write-Host $name -NoNewline
    Write-Host $status -ForegroundColor $color -NoNewline
    Write-Host $current -NoNewline
    Write-Host $latest
}

function Show-Banner {
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "  MPV Unified Updater" -ForegroundColor Cyan
    Write-Host "  mpv + ffmpeg + yt-dlp + portable_config" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
}

# ============================================================
# Main
# ============================================================
try {
    if ($PSVersionTable.PSVersion.Major -le 2) {
        Write-Host "ERROR: PowerShell $($PSVersionTable.PSVersion.Major) is unsupported. Please upgrade." -ForegroundColor Red
        exit 1
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    Show-Banner

    if (Test-Admin) {
        Write-Host "Running with administrator privileges" -ForegroundColor Yellow
    } else {
        Write-Host "Running without administrator privileges" -ForegroundColor DarkYellow
    }
    Write-Host ""

    # Resolve channel and arch (may prompt on first run)
    $resolvedChannel = Resolve-MpvChannel $Channel
    $resolvedArch = Resolve-MpvArch $Arch
    Write-Host "Channel: $resolvedChannel  |  Arch: $resolvedArch" -ForegroundColor Gray
    Write-Host ""

    # ===== Phase 1: Detect all components =====
    Write-Host "Detecting component versions..." -ForegroundColor Cyan
    Write-Host ""

    $results = @()

    if (-not $SkipMpv) {
        Write-Host "  Checking mpv..." -ForegroundColor Gray
        $mpvResult = Test-MpvUpdateNeeded $resolvedArch $resolvedChannel
        $results += $mpvResult
    }

    if (-not $SkipFFmpeg) {
        Write-Host "  Checking ffmpeg..." -ForegroundColor Gray
        $ffmpegArch = if ($resolvedArch -eq "i686") { "i686" } else { $resolvedArch }
        $ffmpegResult = Test-FFmpegUpdateNeeded $ffmpegArch
        $results += $ffmpegResult
    }

    if (-not $SkipYtplugin) {
        Write-Host "  Checking yt-dlp / youtube-dl..." -ForegroundColor Gray
        $ytResult = Test-YtpluginUpdateNeeded
        $results += $ytResult
    }

    if (-not $SkipConfig) {
        Write-Host "  Checking portable_config..." -ForegroundColor Gray
        $cfgResult = Test-ConfigUpdateNeeded
        $results += $cfgResult
    }

    # ===== Phase 2: Show summary =====
    Write-Host ""
    Write-Host "Status Summary:" -ForegroundColor Cyan
    Write-Host ("-" * 78)
    Write-Host ("  {0,-4} {1,-22} {2,-14} {3,-24} {4}" -f "", "Component", "Status", "Current", "Latest")
    Write-Host ("-" * 78)
    foreach ($r in $results) {
        Write-StatusLine $r
    }
    Write-Host ("-" * 78)
    Write-Host ""

    # Check for errors
    $errors = $results | Where-Object { $_.Status -eq "ERROR" }
    if ($errors) {
        Write-Host "WARNING: Some version checks failed (network issue?)." -ForegroundColor DarkYellow
        Write-Host "Components with errors will be skipped." -ForegroundColor DarkYellow
        Write-Host ""
    }

    # ===== Phase 3: Determine what needs updating =====
    $toUpdate = $results | Where-Object { $_.Status -eq "UPDATE" -or $_.Status -eq "NOT_INSTALLED" -or $_.Status -eq "UNKNOWN" }

    if (-not $toUpdate) {
        Write-Host "All components are up to date." -ForegroundColor Green
        Write-Host ""
        Read-Host "Press Enter to exit"
        exit 0
    }

    Write-Host "Components to update:" -ForegroundColor Yellow
    foreach ($u in $toUpdate) {
        $action = if ($u.Status -eq "NOT_INSTALLED") { "(install)" } else { "(update)" }
        Write-Host "  - $($u.Component) $action" -ForegroundColor Yellow
    }
    Write-Host ""

    $confirm = Read-YesNo "Proceed with updates?" "Y"
    if (-not $confirm) {
        Write-Host "Update cancelled." -ForegroundColor Gray
        exit 0
    }

    # ===== Phase 4: Execute updates =====
    Write-Host ""
    Write-Host "Starting updates..." -ForegroundColor Cyan
    Write-Host ""

    $updated = 0
    $failed = 0

    foreach ($u in $toUpdate) {
        Write-Host "--- $($u.Component) ---" -ForegroundColor Cyan
        $ok = $false
        switch -wildcard ($u.Component) {
            "mpv" { $ok = Update-Mpv $u }
            "ffmpeg" { $ok = Update-FFmpeg $u }
            "yt-dlp*" { $ok = Update-Ytplugin $u }
            "portable_config" { $ok = Update-Config $u }
        }
        if ($ok) {
            $updated++
            Write-Host "  $($u.Component) updated successfully." -ForegroundColor Green
        } else {
            $failed++
            Write-Host "  $($u.Component) update FAILED." -ForegroundColor Red
        }
        Write-Host ""
    }

    # ===== Phase 5: Final summary =====
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "  Updated: $updated  |  Failed: $failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Yellow" })
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""

    Read-Host "Press Enter to exit"
    exit $(if ($failed -gt 0) { 1 } else { 0 })
}
catch [System.Exception] {
    Write-Host ""
    Write-Host "FATAL ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}


