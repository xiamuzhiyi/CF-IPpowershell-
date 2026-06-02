param(
    # IP 列表文件路径（每行一个IP，默认为脚本同目录下的 IP.txt）
    [string]$InputFile = "$PSScriptRoot\IP.txt",
    # 输出端口号
    [int]$Port = 443,
    # 自定义后缀
    [string]$Suffix = "CF优选",
    # 输出文件路径（默认与输入同目录，文件名为 输入文件名_formatted.txt）
    [string]$OutputFile = ""
)

# ============================================
# 全局设置
# ============================================
$ErrorActionPreference = "Continue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 检查输入文件
if (-not (Test-Path $InputFile)) {
    Write-Host "错误: 文件不存在 - $InputFile" -ForegroundColor Red
    Read-Host "按任意键退出"
    exit 1
}

# 确定输出路径
if (-not $OutputFile) {
    $inputDir  = Split-Path $InputFile -Parent
    $inputName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    $OutputFile = Join-Path $inputDir "$($inputName)_formatted.txt"
}

# ============================================
# 国旗 Emoji 生成函数
# ============================================
function Get-FlagEmoji {
    param([string]$CountryCode)
    if (-not $CountryCode -or $CountryCode.Length -ne 2 -or $CountryCode -notmatch '^[A-Za-z]{2}$') {
        return ''
    }
    $result = ""
    foreach ($c in $CountryCode.ToUpper().ToCharArray()) {
        $result += [char]::ConvertFromUtf32(127397 + [int][char]$c)
    }
    return $result
}

# ============================================
# IP 地理信息查询（多API降级）
# ============================================
function Get-IPGeoInfo {
    param([string]$IP)

    # 剥离可能混入的端口号
    if ($IP -match '^(.+):\d+$') { $IP = $Matches[1] }

    $apis = @(
        @{
            Name    = "ip-api.com"
            Url     = "http://ip-api.com/json/$IP`?fields=countryCode,city&lang=en"
            Headers = @{}
            Parser  = { param($d) if ($d.countryCode) { return @{ Country = $d.countryCode; City = $d.city } } return $null }
        },
        @{
            Name    = "ipapi.co"
            Url     = "https://ipapi.co/$IP/json/"
            Headers = @{}
            Parser  = { param($d) if ($d.country_code) { return @{ Country = $d.country_code; City = $d.city } } return $null }
        },
        @{
            Name    = "ip.sb"
            Url     = "https://api.ip.sb/geoip/$IP"
            Headers = @{ 'User-Agent' = 'Mozilla/5.0' }
            Parser  = { param($d) if ($d.country_code) { return @{ Country = $d.country_code; City = $d.city } } return $null }
        },
        @{
            Name    = "ipinfo.io"
            Url     = "https://ipinfo.io/$IP/json"
            Headers = @{}
            Parser  = { param($d) if ($d.country) { return @{ Country = $d.country; City = $d.city } } return $null }
        },
        @{
            Name    = "freeipapi.com"
            Url     = "https://freeipapi.com/api/json/$IP"
            Headers = @{}
            Parser  = { param($d) if ($d.countryCode) { return @{ Country = $d.countryCode; City = $d.cityName } } return $null }
        }
    )

    foreach ($api in $apis) {
        try {
            $response = Invoke-RestMethod -Uri $api.Url -Headers $api.Headers -TimeoutSec 3 -ErrorAction Stop
            if ($response) {
                $result = & $api.Parser $response
                if ($result -and $result.Country) {
                    return $result
                }
            }
        } catch {
            continue
        }
    }

    return @{ Country = "未知国家"; City = "未知城市" }
}

# ============================================
# 格式化单行输出
# ============================================
function Format-IPLine {
    param(
        [string]$IP,
        [int]$Port,
        [string]$CountryCode,
        [string]$City,
        [string]$Suffix
    )
    # 防御：剥离可能混入的端口号
    if ($IP -match '^(.+):(\d+)$') { $IP = $Matches[1] }
    $flag = Get-FlagEmoji -CountryCode $CountryCode
    $parts = @()
    if ($flag)   { $parts += $flag }
    if ($City)   { $parts += $City }
    if ($Suffix) { $parts += $Suffix }
    $remark = ($parts | Where-Object { $_ }) -join " | "
    return "$($IP):$($Port)#$remark"
}

# ============================================
# 主流程
# ============================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  IP 地理信息格式化工具" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  输入文件: $InputFile" -ForegroundColor Gray
Write-Host "  输出文件: $OutputFile" -ForegroundColor Gray
Write-Host "  端口: $Port | 后缀: $Suffix" -ForegroundColor Gray
Write-Host ""

# 读取 IP 列表
$rawLines = Get-Content $InputFile -Encoding UTF8
$ipList = @()
foreach ($line in $rawLines) {
    $trimmed = $line.Trim()
    if ([string]::IsNullOrEmpty($trimmed)) { continue }
    # 跳过注释行（# 开头）
    if ($trimmed.StartsWith('#')) { continue }
    $ipList += $trimmed
}

if ($ipList.Count -eq 0) {
    Write-Host "错误: 文件中没有有效的 IP 地址。" -ForegroundColor Red
    Read-Host "按任意键退出"
    exit 1
}

Write-Host "  共 $($ipList.Count) 个IP，开始查询地理信息..." -ForegroundColor Yellow
Write-Host ""

$finalLines = @()
$index = 1

foreach ($rawIP in $ipList) {
    $cleanIP = $rawIP
    $usePort = $Port
    if ($cleanIP -match '^(.+):(\d+)$') {
        $cleanIP = $Matches[1]
        $usePort = [int]$Matches[2]
    }

    Write-Host "  [$index/$($ipList.Count)] 查询 $cleanIP ... " -NoNewline -ForegroundColor Gray

    $geoInfo = Get-IPGeoInfo -IP $cleanIP
    $countryCode = $geoInfo.Country
    $city        = $geoInfo.City

    $line = Format-IPLine -IP $cleanIP -Port $usePort -CountryCode $countryCode -City $city -Suffix $Suffix
    $finalLines += $line

    $flag = Get-FlagEmoji -CountryCode $countryCode
    Write-Host "$flag $countryCode | $city" -ForegroundColor Green
    Write-Host "    -> $line" -ForegroundColor Cyan

    $index++

    # 频率控制: ip-api.com 免费版限制 45次/分钟
    if ($index -le $ipList.Count) {
        Start-Sleep -Milliseconds 1500
    }
}

# 保存结果
$finalLines | Out-File -FilePath $OutputFile -Encoding UTF8 -Force

# 复制到剪贴板
try {
    $finalLines -join "`r`n" | Set-Clipboard
    Write-Host ""
    Write-Host "  结果已复制到剪贴板！" -ForegroundColor Magenta
} catch { }

# 输出汇总
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  格式化完成！($($finalLines.Count) 条)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  输出文件: $OutputFile" -ForegroundColor Green
Write-Host "  格式: IP:端口#国旗Emoji | 城市名称 | 自定义后缀" -ForegroundColor Cyan
Write-Host ""
foreach ($line in $finalLines) {
    Write-Host "  $line" -ForegroundColor White
}
Write-Host ""

Write-Host "  按任意键退出..." -ForegroundColor Gray
$null = Read-Host
