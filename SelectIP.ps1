param(
    # 默认测试 IP 数量
    [int]$DN_COUNT = 10,
    # 优先选择区域: 香港(HKG)|新加坡(SIN)|日本(NRT)|韩国(ICN)|台湾(TPE)
    [string]$CFCOLO = "HKG,SIN,NRT,ICN,TPE",
    # 工作目录
    [string]$BaseDir = "D:\CF优选IP",
    # 输出端口号
    [int]$Port = 443,
    # 自定义后缀名称
    [string]$CustomSuffix = "CF优选"
)

# ============================================
# 全局错误处理
# ============================================
$ErrorActionPreference = "Continue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 安全退出函数：确保在显示错误信息后暂停，不会闪退
function Exit-Script {
    param([string]$Message, [int]$Code = 1)
    if ($Message) { Write-Host $Message -ForegroundColor Red }
    Write-Host "`n按任意键退出..." -ForegroundColor Gray
    $null = Read-Host
    exit $Code
}

# ============================================
# 定义路径
# ============================================
$CFSPEED_EXEC       = Join-Path $BaseDir "CloudflareSpeedtest.exe"
$CLOUDFLARE_IP_FILE = Join-Path $BaseDir "Cloudflare.txt"
$RESULT_FILE        = Join-Path $BaseDir "result.csv"
$FILTERED_FILE      = Join-Path $BaseDir "filtered_result.csv"
$PURE_FILE          = Join-Path $BaseDir "pure_result.csv"
$FINAL_OUTPUT       = Join-Path $BaseDir "result_formatted.txt"

# 确保目录存在
if (-Not (Test-Path $BaseDir)) {
    New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Cloudflare 优选 IP 完整工具" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================
# 步骤1: 检查/下载 CloudflareSpeedTest
# ============================================
Write-Host "[1/6] 检查 CloudflareSpeedTest..." -ForegroundColor Yellow

if (-Not (Test-Path $CFSPEED_EXEC)) {
    Write-Host "  CloudflareSpeedTest 不存在，开始下载..." -ForegroundColor Gray
    $ARCH_TYPE = if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) { (Get-CimInstance -Class Win32_Processor).AddressWidth } else { (Get-WmiObject -Class Win32_Processor).AddressWidth }
    if ($ARCH_TYPE -eq 64) {
        $DOWNLOAD_URL = "https://github.com/ShadowObj/CloudflareSpeedTest/releases/download/v2.2.6/CloudflareSpeedtest_win_amd64.exe"
    } else {
        $DOWNLOAD_URL = "https://github.com/ShadowObj/CloudflareSpeedTest/releases/download/v2.2.6/CloudflareSpeedtest_win_arm64.exe"
    }
    try {
        Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $CFSPEED_EXEC -UseBasicParsing -ErrorAction Stop
        Write-Host "  下载完成: $CFSPEED_EXEC" -ForegroundColor Green
    } catch {
        Write-Host "  下载失败: $_" -ForegroundColor Red
        Exit-Script "CloudflareSpeedTest 下载失败，无法继续。"
    }
} else {
    Write-Host "  已存在: $CFSPEED_EXEC" -ForegroundColor Green
}

# ============================================
# 步骤2: 检查/下载 Cloudflare IP 列表
# ============================================
Write-Host "[2/6] 检查 Cloudflare IP 列表..." -ForegroundColor Yellow

if (-Not (Test-Path $CLOUDFLARE_IP_FILE)) {
    Write-Host "  本地未找到，开始下载..." -ForegroundColor Gray
    try {
        Invoke-WebRequest -Uri "https://www.cloudflare.com/ips-v4/" -OutFile $CLOUDFLARE_IP_FILE -UseBasicParsing -ErrorAction Stop
        Write-Host "  下载完成: $CLOUDFLARE_IP_FILE" -ForegroundColor Green
    } catch {
        Write-Host "  下载失败: $_" -ForegroundColor Red
        Exit-Script "Cloudflare IP 列表下载失败，无法继续。"
    }
} else {
    Write-Host "  已存在: $CLOUDFLARE_IP_FILE" -ForegroundColor Green
}

if (-Not (Test-Path $CLOUDFLARE_IP_FILE) -or (Get-Item $CLOUDFLARE_IP_FILE).Length -eq 0) {
    Exit-Script "Cloudflare IP 列表不可用，无法继续。"
}

# ============================================
# 步骤3: 运行 CloudflareSpeedTest 测速
# ============================================
Write-Host "[3/6] 运行 CloudflareSpeedTest 测速..." -ForegroundColor Yellow

$ARGS = "-dn $DN_COUNT -sl 1 -tl 300 -f `"$CLOUDFLARE_IP_FILE`" -o `"$RESULT_FILE`""
if ($CFCOLO -and $CFCOLO.Trim() -ne "") {
    $ARGS += " -cfcolo $CFCOLO"
    Write-Host "  优先区域: $CFCOLO" -ForegroundColor Gray
}

Write-Host "  执行测速（请耐心等待）..." -ForegroundColor Gray
try {
    $proc = Start-Process -FilePath $CFSPEED_EXEC -ArgumentList $ARGS -Wait -PassThru -NoNewWindow
    if ($proc.ExitCode -ne 0) {
        Write-Host "  测速完成（退出码: $($proc.ExitCode)）" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  测速执行异常: $_" -ForegroundColor Red
}

if (-Not (Test-Path $RESULT_FILE)) {
    Exit-Script "测速结果文件未生成，请检查 CloudflareSpeedTest 是否正常执行。"
}
Write-Host "  测速完成，结果: $RESULT_FILE" -ForegroundColor Green

# ============================================
# 步骤4: 地区筛选 (HKG, SIN, NRT, ICN, TPE)
# ============================================
Write-Host "[4/6] 地区筛选（仅保留亚洲目标区域）..." -ForegroundColor Yellow

function Filter-IPByRegion {
    param([string]$InputFile, [string]$OutputFile)
    $targetColos = @("HKG", "SIN", "NRT", "ICN", "TPE")

    $csvContent = Get-Content $InputFile -Encoding UTF8
    if ($csvContent.Count -le 1) {
        Write-Host "  测速结果为空或仅有表头，跳过筛选" -ForegroundColor Yellow
        return @{ Success = $false }
    }

    # 统计实际出现的区域
    $allColos = @{}
    $filtered = @($csvContent[0])
    for ($i = 1; $i -lt $csvContent.Count; $i++) {
        $line = $csvContent[$i].Trim()
        if ([string]::IsNullOrEmpty($line)) { continue }
        $fields = $line -split ','
        if ($fields.Count -ge 6) {
            $coloCode = $fields[5].Trim()
            if (-not $allColos.ContainsKey($coloCode)) { $allColos[$coloCode] = 0 }
            $allColos[$coloCode]++
            if ($targetColos -contains $coloCode) {
                $filtered += $line
            }
        }
    }

    $total = $csvContent.Count - 1
    $filteredCount = $filtered.Count - 1

    # 显示实际区域分布
    Write-Host "  测到区域分布:" -ForegroundColor Gray
    foreach ($c in $allColos.Keys | Sort-Object) {
        Write-Host "    $c x$($allColos[$c])" -ForegroundColor DarkGray
    }
    Write-Host "  原始: $total 个 | 筛选后: $filteredCount 个（目标: $($targetColos -join '/')）" -ForegroundColor Gray

    # 兜底：无目标区域IP时，使用全部IP继续
    if ($filteredCount -eq 0) {
        Write-Host "  未找到目标区域IP，自动使用全部测速结果继续..." -ForegroundColor Yellow
        $filtered = $csvContent
        $filteredCount = $total
    }

    $filtered | Out-File -FilePath $OutputFile -Encoding UTF8 -Force
    return @{ Success = $true; Count = $filteredCount }
}

$regionResult = Filter-IPByRegion -InputFile $RESULT_FILE -OutputFile $FILTERED_FILE

# ============================================
# 步骤5: 纯净度筛选 (延迟 <= 200ms, 丢包率 = 0%)
# ============================================
Write-Host "[5/6] 纯净度筛选（延迟<=200ms & 丢包率=0%）..." -ForegroundColor Yellow

function Filter-IPByPurity {
    param(
        [string]$InputFile,
        [string]$OutputFile,
        [int]$MaxLatency = 200,
        [int]$MaxLoss = 0
    )

    if (-Not (Test-Path $InputFile)) {
        Write-Host "  输入文件不存在，跳过纯净度筛选" -ForegroundColor Yellow
        return @()
    }

    $csvContent = Get-Content $InputFile -Encoding UTF8
    if ($csvContent.Count -le 1) {
        Write-Host "  输入文件为空，跳过" -ForegroundColor Yellow
        return @()
    }

    $filtered = @($csvContent[0])
    $ipList = @()
    for ($i = 1; $i -lt $csvContent.Count; $i++) {
        $line = $csvContent[$i].Trim()
        if ([string]::IsNullOrEmpty($line)) { continue }
        $fields = $line -split ','
        if ($fields.Count -ge 6) {
            $ip      = $fields[0].Trim()
            $latency = try { [double]$fields[1] } catch { 999 }
            $loss    = try { [double]$fields[4] } catch { 100 }

            if ($latency -le $MaxLatency -and $loss -le $MaxLoss) {
                $filtered += $line
                $ipList += $ip
            }
        }
    }

    $filtered | Out-File -FilePath $OutputFile -Encoding UTF8 -Force
    $total = $csvContent.Count - 1
    $filteredCount = $filtered.Count - 1
    Write-Host "  原始: $total 个 | 筛选后: $filteredCount 个（纯净IP）" -ForegroundColor Gray
    return $ipList
}

$pureIPs = Filter-IPByPurity -InputFile $FILTERED_FILE -OutputFile $PURE_FILE -MaxLatency 200 -MaxLoss 0

if ($pureIPs.Count -eq 0) {
    Write-Host ""
    Write-Host "  纯净IP数为0，放宽丢包率限制重试（丢包率<=5%）..." -ForegroundColor Yellow
    $pureIPs = Filter-IPByPurity -InputFile $FILTERED_FILE -OutputFile $PURE_FILE -MaxLatency 200 -MaxLoss 5
}

if ($pureIPs.Count -eq 0) {
    Write-Host ""
    Write-Host "  筛选无结果，跳过筛选，使用全部测速IP直接输出..." -ForegroundColor Yellow
    # 从原始 result.csv 提取全部IP（跳过表头）
    $rawCsv = Get-Content $RESULT_FILE -Encoding UTF8
    $pureIPs = @()
    for ($i = 1; $i -lt $rawCsv.Count; $i++) {
        $line = $rawCsv[$i].Trim()
        if ([string]::IsNullOrEmpty($line)) { continue }
        $fields = $line -split ','
        if ($fields.Count -ge 1) {
            $pureIPs += $fields[0].Trim()
        }
    }
    Write-Host "  共提取 $($pureIPs.Count) 个IP，开始格式化..." -ForegroundColor Gray
}

# ============================================
# 步骤6: IP 地理信息查询 + 格式化输出
# ============================================
Write-Host "[6/6] 查询IP地理信息并格式化输出..." -ForegroundColor Yellow

# --- 国旗 Emoji 生成函数 (对应 _workers.js getFlagEmoji) ---
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

# --- IP 地理信息查询 (对应 _workers.js parseIPInfo 多API降级) ---
function Get-IPGeoInfo {
    param([string]$IP)

    # 剥离可能混入的端口号
    if ($IP -match '^(.+):\d+$') { $IP = $Matches[1] }

    # API 列表: 依次尝试，前一个失败则降级到下一个
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

    $lastError = ""
    foreach ($api in $apis) {
        try {
            $response = Invoke-RestMethod -Uri $api.Url -Headers $api.Headers -TimeoutSec 3 -ErrorAction Stop
            if ($response) {
                $result = & $api.Parser $response
                if ($result -and $result.Country) {
                    Write-Host "[$($api.Name)]" -NoNewline -ForegroundColor DarkGray
                    return $result
                }
            }
        } catch {
            $lastError = "$($api.Name): $($_.Exception.Message)"
            continue
        }
    }

    # 所有 API 都失败时输出最后的错误信息
    Write-Host "[ALL FAIL]" -NoNewline -ForegroundColor Red
    return @{ Country = "未知国家"; City = "未知城市"; Error = $lastError }
}

# --- 格式化单行输出 (对应 _workers.js newNodeName) ---
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
    if ($flag) { $parts += $flag }
    if ($City)  { $parts += $City }
    if ($Suffix) { $parts += $Suffix }
    $remark = ($parts | Where-Object { $_ }) -join " | "
    return "$($IP):$($Port)#$remark"
}

# --- 主处理循环 ---
Write-Host ""
Write-Host "  共 $($pureIPs.Count) 个纯净IP，开始查询地理信息..." -ForegroundColor Gray
Write-Host ""

$finalLines = @()
$index = 1

foreach ($ip in $pureIPs) {
    # 防御：剥离可能混入的端口号
    $cleanIP = $ip
    if ($cleanIP -match '^(.+):(\d+)$') { $cleanIP = $Matches[1] }

    Write-Host "  [$index/$($pureIPs.Count)] 查询 $cleanIP ... " -NoNewline -ForegroundColor Gray

    $geoInfo = Get-IPGeoInfo -IP $cleanIP
    $countryCode = $geoInfo.Country
    $city        = $geoInfo.City

    $line = Format-IPLine -IP $cleanIP -Port $Port -CountryCode $countryCode -City $city -Suffix $CustomSuffix
    $finalLines += $line

    $flag = Get-FlagEmoji -CountryCode $countryCode
    Write-Host "$flag $countryCode | $city" -ForegroundColor Green
    if ($geoInfo.Error) { Write-Host "    API错误: $($geoInfo.Error)" -ForegroundColor DarkYellow }
    Write-Host "    -> $line" -ForegroundColor Cyan

    $index++

    # 频率控制: ip-api.com 免费版限制 45次/分钟，间隔 1.5 秒
    if ($index -le $pureIPs.Count) {
        Start-Sleep -Milliseconds 1500
    }
}

# ============================================
# 保存最终结果
# ============================================
$finalLines | Out-File -FilePath $FINAL_OUTPUT -Encoding UTF8 -Force

# ============================================
# 输出汇总
# ============================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  优选任务完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  原始测速数据:  $RESULT_FILE" -ForegroundColor DarkGray
Write-Host "  地区筛选结果:  $FILTERED_FILE" -ForegroundColor DarkGray
Write-Host "  纯净度筛选:    $PURE_FILE" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  *** 格式化结果 ***" -ForegroundColor Green
Write-Host "  文件: $FINAL_OUTPUT" -ForegroundColor Green
Write-Host "  格式: IP:端口#国旗Emoji | 城市名称 | 自定义后缀" -ForegroundColor Cyan
Write-Host ""
Write-Host "  优选结果 ($($finalLines.Count) 个):" -ForegroundColor Yellow
Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
foreach ($line in $finalLines) {
    Write-Host "  $line" -ForegroundColor White
}
Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
Write-Host ""

# 复制到剪贴板（可选）
try {
    $finalLines -join "`r`n" | Set-Clipboard
    Write-Host "  结果已自动复制到剪贴板！" -ForegroundColor Magenta
} catch {
    # 剪贴板操作可能失败，忽略
}

Write-Host ""
Write-Host "  按任意键退出..." -ForegroundColor Gray
$null = Read-Host
