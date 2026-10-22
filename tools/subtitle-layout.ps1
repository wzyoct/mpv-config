[CmdletBinding()]
param([string]$Request, [string]$CacheRoot,
    [string]$ResumeMedia, [string]$ResumeDirectory, [switch]$IgnorePath,
    [string]$SidMap, [string]$BaseOverride = 'scale',
    [string]$BaseMargins = 'no', [string]$BaseWindowScale = 'no')

$ErrorActionPreference = 'Stop'
try {
    # A launcher may inherit PowerShell 7's module paths; use this host's modules.
    Import-Module (Join-Path $PSHOME 'Modules\Microsoft.PowerShell.Utility')
    Import-Module (Join-Path $PSHOME 'Modules\Microsoft.PowerShell.Management')
    [Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
    [Console]::SetError([IO.StreamWriter]::new([Console]::OpenStandardError(), [Text.UTF8Encoding]::new($false)))
    if ($CacheRoot) { [IO.Directory]::CreateDirectory($CacheRoot) | Out-Null; exit 0 }
    if ($ResumeMedia) {
        $resumeName = $ResumeMedia
        if ($IgnorePath) { $resumeName = [IO.Path]::GetFileName($resumeName) }
        $md5 = [Security.Cryptography.MD5]::Create()
        try { $name = -join ($md5.ComputeHash([Text.Encoding]::UTF8.GetBytes($resumeName)) | ForEach-Object { $_.ToString('X2') }) }
        finally { $md5.Dispose() }
        $resumePath = Join-Path $ResumeDirectory $name
        $data = @{}
        if (Test-Path -LiteralPath $resumePath) {
            $text = [IO.File]::ReadAllText($resumePath)
            if ($text -match '(?m)^sub-scale=([0-9.]+)\r?$') { $data.scale = [double]::Parse($Matches[1], [Globalization.CultureInfo]::InvariantCulture) }
            $mapping = @{}
            foreach ($pair in ($SidMap -split ',')) {
                if ($pair -match '^(\d+):(\d+)$') { $mapping[$Matches[1]] = $Matches[2] }
            }
            if ($text -match '(?m)^sid=(\d+)\r?$' -and $mapping.ContainsKey($Matches[1])) {
                $generatedSid = $Matches[1]
                $originalSid = $mapping[$generatedSid]
                $stamp = [IO.File]::GetLastWriteTimeUtc($resumePath)
                $text = [regex]::Replace($text, "(?m)^sid=$generatedSid(?=\r?$)", "sid=$originalSid")
                $text = [regex]::Replace($text, '(?m)^sub-ass-override=yes(?=\r?$)', "sub-ass-override=$BaseOverride")
                $text = [regex]::Replace($text, '(?m)^sub-ass-force-margins=yes(?=\r?$)', "sub-ass-force-margins=$BaseMargins")
                $text = [regex]::Replace($text, '(?m)^sub-ass-scale-with-window=yes(?=\r?$)', "sub-ass-scale-with-window=$BaseWindowScale")
                $temp = "$resumePath.$([Guid]::NewGuid().ToString('N')).tmp"
                [IO.File]::WriteAllText($temp, $text, [Text.UTF8Encoding]::new($false))
                [IO.File]::Replace($temp, $resumePath, [NullString]::Value)
                [IO.File]::SetLastWriteTimeUtc($resumePath, $stamp)
            }
        }
        [Console]::Out.WriteLine(($data | ConvertTo-Json -Compress))
        exit 0
    }
    if (-not $Request) { throw '缺少字幕处理请求文件。' }
    $job = Get-Content -LiteralPath $Request -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($job.scale -lt 0.1 -or $job.scale -gt 10) { throw '字幕倍率必须介于 0.1 和 10。' }
    if (-not (Test-Path -LiteralPath $job.source -PathType Leaf)) { throw '字幕来源不是本地文件。' }
    $source = Get-Item -LiteralPath $job.source
    $plainIdentity = @($job.plain.PSObject.Properties | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value | ConvertTo-Json -Compress)" }) -join "`n"
    $identity = @($source.FullName, $source.Length, $source.LastWriteTimeUtc.Ticks,
        $job.stream, $job.scale, $job.font, $job.fonts, $job.srt,
        $plainIdentity,
        (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash,
        (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'SubtitleLayout.cs') -Algorithm SHA256).Hash)
    if ($job.media) {
        $media = Get-Item -LiteralPath $job.media
        $identity += @($media.FullName, $media.Length, $media.LastWriteTimeUtc.Ticks)
    }
    # Font changes must invalidate measurements as well as subtitle changes.
    foreach ($dir in @($job.fonts, "$env:WINDIR\Fonts", "$env:LOCALAPPDATA\Microsoft\Windows\Fonts")) {
        if (Test-Path -LiteralPath $dir) {
            $identity += Get-ChildItem -LiteralPath $dir -File | ForEach-Object { "$($_.Name):$($_.Length):$($_.LastWriteTimeUtc.Ticks)" }
        }
    }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $key = -join ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($identity -join "`n"))) | ForEach-Object { $_.ToString('x2') }) }
    finally { $sha.Dispose() }
    $root = Join-Path $job.cache $key
    $output = Join-Path $root 'layout.ass'
    $report = Join-Path $root 'report.json'
    if (Test-Path -LiteralPath $report) {
        $cached = Get-Content -LiteralPath $report -Raw -Encoding UTF8
        if (($cached | ConvertFrom-Json).native -or (Test-Path -LiteralPath $output)) {
            [Console]::Out.WriteLine($cached)
            exit 0
        }
    }
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    $build = Join-Path $root ('build-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $build | Out-Null
    $inputAss = $job.source
    $fontDir = Join-Path $build 'fonts'
    New-Item -ItemType Directory -Path $fontDir -Force | Out-Null
    if ($job.stream -ge 0 -or $job.srt) {
        $inputAss = Join-Path $build 'source.ass'
        $map = '0:s:0'
        if ($job.stream -ge 0) { $map = "0:$($job.stream)" }
        $details = & $job.ffmpeg -nostdin -hide_banner -loglevel error -y -i $job.source -map $map -c:s ass $inputAss 2>&1
        if ($LASTEXITCODE -ne 0) { throw "提取 ASS 失败：$($details -join "`n")" }
        # Never use attachment filenames supplied by an untrusted container.
    }
    if ($job.media) {
        # Windows PowerShell represents native stderr as ErrorRecord even on success.
        $ErrorActionPreference = 'Continue'
        $probe = & $job.ffmpeg -nostdin -hide_banner -i $job.media -t 0 -f null NUL 2>&1
        $probeExit = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        if ($probeExit -ne 0) { throw "读取媒体字体信息失败：$($probe -join "`n")" }
        foreach ($line in $probe) {
            if ("$line" -match 'Stream #0:(\d+).*Attachment: (ttf|otf)') {
                $fontPath = Join-Path $fontDir ("attachment-$($Matches[1]).$($Matches[2])")
                $details = & $job.ffmpeg -nostdin -hide_banner -loglevel error -y "-dump_attachment:$($Matches[1])" $fontPath -i $job.media -t 0 -f null NUL 2>&1
                if ($LASTEXITCODE -ne 0) { throw "提取媒体字体失败：$($details -join "`n")" }
            }
        }
    }
    Add-Type -AssemblyName System.Drawing
    Add-Type -Path (Join-Path $PSScriptRoot 'SubtitleLayout.cs') -ReferencedAssemblies System.Drawing
    $plain = $null
    if ($job.srt) {
        $plain = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($property in $job.plain.PSObject.Properties) { $plain.Add($property.Name, [string]$property.Value) }
    }
    $result = [SubtitleLayout]::Process($inputAss, $output, [double]$job.scale, [string]$job.font, @([string]$job.fonts, $fontDir), $plain)
    $json = @{ path = $output; fonts = $fontDir; scale = $job.scale; changed = $result[0]; skipped = $result[1]; pairs = $result[2]; bilingual = ($result[3] -eq 1); uncertain = $result[4]; native = ($job.srt -and $result[3] -eq 0 -and $result[4] -eq 0) } | ConvertTo-Json -Compress
    $tempReport = "$report.$([Guid]::NewGuid().ToString('N')).tmp"
    [IO.File]::WriteAllText($tempReport, $json, (New-Object Text.UTF8Encoding($false)))
    if (Test-Path -LiteralPath $report) { [IO.File]::Replace($tempReport, $report, [NullString]::Value) }
    else { [IO.File]::Move($tempReport, $report) }
    [Console]::Out.WriteLine($json)
} catch {
    [Console]::Error.WriteLine($_.ToString())
    [Console]::Error.Flush()
    exit 1
}
