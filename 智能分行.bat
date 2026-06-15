@echo off

:: 设置输入输出文件名（与 bat 同目录）
set "input_name=input.txt"
set "output_name=output.txt"
set "delim=,"

:: 获取当前目录（即 bat 所在目录）
set "bat_dir=%~dp0"
set "input_file=%bat_dir%%input_name%"
set "output_file=%bat_dir%%output_name%"

:: 检查输入文件
if not exist "%input_file%" (
    echo 错误：找不到 "%input_file%"
    pause
    exit /b 1
)

echo 输入文件：%input_file%
echo 输出文件：%output_file%
echo 分隔符：%delim%
echo 开始处理...

:: 调用 PowerShell，并将所有输出（包括错误）保存到日志文件
powershell -Command "$ErrorActionPreference='Stop'; $c=Get-Content -Path '%input_file%' -Raw -Encoding UTF8; $parts=$c -split [regex]::Escape('%delim%'); $parts=($parts|ForEach-Object{$_.Trim()}|Where-Object{$_ -ne ''}); $parts -join \"`r`n\" | Out-File -FilePath '%output_file%' -Encoding UTF8; Write-Host '处理完成'" > "%bat_dir%ps_log.txt" 2>&1

if %errorlevel% equ 0 (
    echo 拆分成功，结果已保存到 %output_file%
) else (
    echo 拆分失败，请查看日志文件：%bat_dir%ps_log.txt
)

pause