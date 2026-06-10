@echo off
setlocal
cd /d "%~dp0"

:: Use PowerShell 7 (pwsh) if available, fallback to PowerShell 5
:: -NoExit keeps window open so you can see errors
where pwsh >nul 2>&1
if %errorLevel% equ 0 (
    pwsh -NoProfile -NoExit -ExecutionPolicy Bypass -File "%~dp0MergeCsvFiles.ps1"
) else (
    powershell -NoProfile -NoExit -ExecutionPolicy Bypass -File "%~dp0MergeCsvFiles.ps1"
)

endlocal
pause
