[CmdletBinding()]
param(
    [string]$Remote = 'origin',
    [string]$Destination = 'Z:\downloads\mpv'
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$tempRoot = $null

function Invoke-GitText {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $output = @(& git @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        $details = $output -join [Environment]::NewLine
        throw "git $($Arguments -join ' ') failed:`n$details"
    }

    return ($output -join [Environment]::NewLine)
}

Push-Location -LiteralPath $repoRoot
try {
    $branch = (Invoke-GitText -Arguments @('symbolic-ref', '--quiet', '--short', 'HEAD')).Trim()
    if ([string]::IsNullOrWhiteSpace($branch)) {
        throw '当前 HEAD 不是分支，无法推送。'
    }

    $status = @(& git status --porcelain=v1 --untracked-files=all 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "无法读取 Git 工作区状态:`n$($status -join [Environment]::NewLine)"
    }
    if ($status.Count -gt 0) {
        throw "工作区不干净，请先提交所有修改:`n$($status -join [Environment]::NewLine)"
    }

    if (-not (Test-Path -LiteralPath $Destination -PathType Container)) {
        throw "备份目录不可访问或不是目录：$Destination"
    }

    $commit = (Invoke-GitText -Arguments @('rev-parse', '--verify', 'HEAD')).Trim()
    $shortCommit = (Invoke-GitText -Arguments @('rev-parse', '--short=12', 'HEAD')).Trim()
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $archiveName = "mpv-config-$timestamp-$shortCommit.zip"
    $targetPath = Join-Path $Destination $archiveName

    if (Test-Path -LiteralPath $targetPath) {
        throw "备份文件已经存在，不覆盖已有备份：$targetPath"
    }

    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('mpv-config-backup-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    $archivePath = Join-Path $tempRoot $archiveName
    $prefix = "mpv-config-$shortCommit/"

    Invoke-GitText -Arguments @('archive', '--format=zip', "--prefix=$prefix", "--output=$archivePath", $commit) | Out-Null
    if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
        throw "Git 未生成备份文件：$archivePath"
    }

    Invoke-GitText -Arguments @('push', $Remote, "HEAD:refs/heads/$branch") | Out-Null

    $remoteLine = (Invoke-GitText -Arguments @('ls-remote', '--heads', $Remote, "refs/heads/$branch")).Trim()
    $remoteCommit = ($remoteLine -split '\s+')[0]
    if ($remoteCommit -ne $commit) {
        throw "远程提交号不匹配：本地 $commit，远程 $remoteCommit"
    }

    Copy-Item -LiteralPath $archivePath -Destination $targetPath -ErrorAction Stop
    $sourceLength = (Get-Item -LiteralPath $archivePath).Length
    $targetLength = (Get-Item -LiteralPath $targetPath).Length
    if ($sourceLength -ne $targetLength -or $targetLength -le 0) {
        throw "备份文件校验失败：$targetPath"
    }

    Write-Output "GitHub 推送完成：$Remote/$branch@$commit"
    Write-Output "备份完成：$targetPath ($targetLength bytes)"
}
finally {
    Pop-Location
    if ($null -ne $tempRoot -and (Test-Path -LiteralPath $tempRoot)) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
