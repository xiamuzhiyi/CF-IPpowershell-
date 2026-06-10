<#
.SYNOPSIS
    递归合并指定目录下所有 .txt 文件，去除重复行（不区分大小写）。
.DESCRIPTION
    默认弹出手动选择文件夹的对话框，也可通过参数使用脚本所在目录或自定义路径。
.PARAMETER AutoMode
    静默模式：不弹出对话框，直接使用脚本所在目录作为源目录。
.PARAMETER SourcePath
    直接指定源目录（优先级最高，此时不会弹出对话框）。
.PARAMETER OutputFile
    输出文件的完整路径。若不提供，默认在脚本所在目录生成 merged_output.txt。
.PARAMETER Encoding
    读写文件使用的编码，默认 UTF8。若中文乱码请尝试 Default。
.EXAMPLE
    .\MergeTxtFiles.ps1                       # 弹出手动选择文件夹对话框
    .\MergeTxtFiles.ps1 -AutoMode             # 使用脚本所在目录，无对话框
    .\MergeTxtFiles.ps1 -SourcePath "D:\Data" # 直接指定目录
#>

param(
    [switch]$AutoMode,
    [string]$SourcePath,
    [string]$OutputFile,
    [string]$Encoding = "UTF8"
)

# 确定源目录（优先级：-SourcePath > -AutoMode > 手动选择）
if ($SourcePath) {
    # 已通过参数指定目录
    Write-Host "使用指定目录: $SourcePath" -ForegroundColor Cyan
}
elseif ($AutoMode) {
    # 静默模式，使用脚本所在目录
    $SourcePath = $PSScriptRoot
    if (-not $SourcePath) { $SourcePath = Get-Location }
    Write-Host "自动模式，使用目录: $SourcePath" -ForegroundColor Cyan
}
else {
    # 默认：弹出文件夹选择对话框，让用户手动选择
    Add-Type -AssemblyName System.Windows.Forms
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "请选择包含 .txt 文件的根目录"
    $folderBrowser.ShowNewFolderButton = $false
    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $SourcePath = $folderBrowser.SelectedPath
        Write-Host "手动选择目录: $SourcePath" -ForegroundColor Cyan
    }
    else {
        Write-Error "未选择任何目录，脚本退出。"
        exit 1
    }
}

# 验证源目录是否存在
if (-not (Test-Path -Path $SourcePath -PathType Container)) {
    Write-Error "源目录不存在: $SourcePath"
    exit 1
}

# 确定输出文件路径
if (-not $OutputFile) {
    $OutputFile = Join-Path -Path $PSScriptRoot -ChildPath "merged_output.txt"
}

# 递归获取所有 .txt 文件
$txtFiles = Get-ChildItem -Path $SourcePath -Recurse -Filter "*.txt" -File -ErrorAction SilentlyContinue
if ($txtFiles.Count -eq 0) {
    Write-Warning "在目录 $SourcePath 及其子目录中没有找到任何 .txt 文件。"
    exit 0
}

Write-Host "找到 $($txtFiles.Count) 个 .txt 文件，开始处理..." -ForegroundColor Cyan

# 不区分大小写的去重集合
$seenLines = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$resultLines = New-Object System.Collections.Generic.List[string]

foreach ($file in $txtFiles) {
    Write-Host "  正在处理: $($file.FullName)" -ForegroundColor Yellow
    try {
        $lines = Get-Content -Path $file.FullName -Encoding $Encoding -ErrorAction Stop
        foreach ($line in $lines) {
            if ($seenLines.Add($line)) {
                $resultLines.Add($line)
            }
        }
    }
    catch {
        Write-Warning "读取文件失败，已跳过: $($file.FullName) - $_"
    }
}

# 写入输出文件
$outputDir = Split-Path -Path $OutputFile -Parent
if (-not (Test-Path -Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
}
try {
    $resultLines -join "`r`n" | Set-Content -Path $OutputFile -Encoding $Encoding -NoNewline
    Write-Host "`n去重完成！共保留 $($resultLines.Count) 行（不区分大小写去重）。" -ForegroundColor Green
    Write-Host "输出文件位置: $OutputFile" -ForegroundColor Green
}
catch {
    Write-Error "写入输出文件失败: $_"
}