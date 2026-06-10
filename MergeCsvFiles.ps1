<#
.SYNOPSIS
    递归合并指定目录下所有 .csv 文件，基于“IP”和“端口”列去重（自动识别常见列名变体），保留首次出现的完整行。
.DESCRIPTION
    默认弹出文件夹选择对话框，让用户手动选择要处理的根目录（对话框默认打开脚本所在目录）。
    也可使用 -AutoMode 参数，直接使用脚本所在目录（无弹窗）。
    扫描目录及子目录下所有 .csv 文件，自动识别 IP 列和端口列（支持 IP地址、IP、ip、端口、端口号、Port 等）。
    基于 IP+端口 组合去重（不区分大小写），输出合并后的 CSV 文件。
.PARAMETER AutoMode
    静默模式：不弹出对话框，直接使用脚本所在目录作为源目录。
.PARAMETER SourcePath
    直接指定源目录（优先级最高，此时不会弹出对话框）。
.PARAMETER OutputFile
    输出文件的完整路径。若不提供，默认在脚本所在目录生成 merged_output.csv。
.PARAMETER Encoding
    读写文件使用的编码，默认 UTF8。若中文乱码请尝试 Default（系统 ANSI/GBK）。
.EXAMPLE
    .\MergeCsvFiles.ps1                       # 弹出文件夹选择对话框，手动选择目录
    .\MergeCsvFiles.ps1 -AutoMode             # 使用脚本所在目录，无对话框
    .\MergeCsvFiles.ps1 -SourcePath "D:\Data" # 直接指定目录
    .\MergeCsvFiles.ps1 -Encoding Default     # 处理 GBK 编码的 CSV 文件（也会弹窗）
#>

param(
    [switch]$AutoMode,
    [string]$SourcePath,
    [string]$OutputFile,
    [string]$Encoding = "UTF8"
)

# ========== 1. 确定源目录 ==========
if ($SourcePath) {
    Write-Host "使用指定目录: $SourcePath" -ForegroundColor Cyan
}
elseif ($AutoMode) {
    $SourcePath = $PSScriptRoot
    if (-not $SourcePath) { $SourcePath = Get-Location }
    Write-Host "自动模式，使用目录: $SourcePath" -ForegroundColor Cyan
}
else {
    # 默认：弹出文件夹选择对话框（手动选择）
    Add-Type -AssemblyName System.Windows.Forms
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "请选择包含 .csv 文件的根目录"
    $folderBrowser.ShowNewFolderButton = $false
    # 设置默认打开路径为脚本所在目录（如果存在）
    if ($PSScriptRoot -and (Test-Path $PSScriptRoot)) {
        $folderBrowser.SelectedPath = $PSScriptRoot
    }
    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $SourcePath = $folderBrowser.SelectedPath
        Write-Host "手动选择目录: $SourcePath" -ForegroundColor Cyan
    }
    else {
        Write-Error "未选择任何目录，脚本退出。"
        exit 1
    }
}

if (-not (Test-Path -Path $SourcePath -PathType Container)) {
    Write-Error "源目录不存在: $SourcePath"
    exit 1
}

# ========== 2. 确定输出文件路径 ==========
if (-not $OutputFile) {
    $OutputFile = Join-Path -Path $PSScriptRoot -ChildPath "merged_output.csv"
}

# ========== 3. 查找所有 .csv 文件 ==========
$csvFiles = Get-ChildItem -Path $SourcePath -Recurse -Filter "*.csv" -File -ErrorAction SilentlyContinue
if ($csvFiles.Count -eq 0) {
    Write-Warning "在目录 $SourcePath 及其子目录中没有找到任何 .csv 文件。"
    exit 0
}

Write-Host "找到 $($csvFiles.Count) 个 .csv 文件，开始处理..." -ForegroundColor Cyan

# ========== 4. 去重逻辑（自动识别IP列和端口列） ==========
$keyComparer = [System.StringComparer]::OrdinalIgnoreCase
$seenKeys = [System.Collections.Generic.HashSet[string]]::new($keyComparer)
$resultRows = New-Object System.Collections.Generic.List[PSObject]

$header = $null
$ipColName = $null
$portColName = $null

# 定义可能的列名模式（不区分大小写）
$ipPatterns = @("IP地址", "IP", "Ip", "ip", "IPADDRESS", "ipaddress")
$portPatterns = @("端口", "端口号", "Port", "port", "PORT")

foreach ($file in $csvFiles) {
    Write-Host "  正在处理: $($file.FullName)" -ForegroundColor Yellow
    try {
        $data = Import-Csv -Path $file.FullName -Encoding $Encoding -ErrorAction Stop
        if ($data.Count -eq 0) { continue }

        # 第一个文件：解析表头，自动匹配IP和端口列
        if ($null -eq $header) {
            $header = $data[0].PSObject.Properties.Name
            # 查找IP列：精确匹配模式列表
            $ipColName = $header | Where-Object { $ipPatterns -contains $_ } | Select-Object -First 1
            if (-not $ipColName) {
                # 模糊匹配：包含 ip 或 地址
                $ipColName = $header | Where-Object { $_ -like "*ip*" -or $_ -like "*地址*" } | Select-Object -First 1
            }
            # 查找端口列
            $portColName = $header | Where-Object { $portPatterns -contains $_ } | Select-Object -First 1
            if (-not $portColName) {
                $portColName = $header | Where-Object { $_ -like "*port*" -or $_ -like "*端口*" } | Select-Object -First 1
            }
            
            if (-not $ipColName -or -not $portColName) {
                Write-Error "文件 $($file.Name) 中未能自动识别 IP 列和/或端口列。请确保列名包含 'IP'/'IP地址' 等关键词，以及 '端口'/'Port' 等关键词。跳过该文件。"
                continue
            }
            Write-Host "    自动识别: IP列 = '$ipColName', 端口列 = '$portColName'" -ForegroundColor Gray
        }
        else {
            # 后续文件：检查是否存在已识别的列名
            $firstRow = $data[0]
            if ($null -eq $firstRow.$ipColName -or $null -eq $firstRow.$portColName) {
                Write-Warning "文件 $($file.Name) 缺少已识别的列 ('$ipColName' 或 '$portColName')，跳过该文件。"
                continue
            }
        }

        foreach ($row in $data) {
            $ipValue = $row.$ipColName
            $portValue = $row.$portColName
            $key = "$($ipValue -as [string])|$($portValue -as [string])"
            if ($seenKeys.Add($key)) {
                $resultRows.Add($row)
            }
        }
    }
    catch {
        Write-Warning "读取文件失败，已跳过: $($file.FullName) - $_"
    }
}

# ========== 5. 输出结果 ==========
if ($resultRows.Count -eq 0) {
    Write-Warning "没有读取到任何有效数据行，未生成输出文件。"
    exit 0
}

$outputDir = Split-Path -Path $OutputFile -Parent
if (-not (Test-Path -Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
}

try {
    $resultRows | Export-Csv -Path $OutputFile -Encoding $Encoding -NoTypeInformation
    Write-Host "`n去重完成！共保留 $($resultRows.Count) 行（基于自动识别的 IP 列和端口列组合，不区分大小写）。" -ForegroundColor Green
    Write-Host "输出文件位置: $OutputFile" -ForegroundColor Green
}
catch {
    Write-Error "写入输出文件失败: $_"
}