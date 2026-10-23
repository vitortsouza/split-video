@echo off
setlocal

if "%~1"=="" (
    echo Uso: arraste um arquivo de video para este Run.bat
    echo Ou execute: Run.bat "C:\caminho\video.mp4" [tamanho_maximo_MB]
    pause
    exit /b 1
)

set "INPUT=%~1"
set "MAXSIZE=%~2"

if "%MAXSIZE%"=="" set "MAXSIZE=195"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Split-Video.ps1" -InputFile "%INPUT%" -MaxSizeMB %MAXSIZE%

set "EXITCODE=%ERRORLEVEL%"

echo.
if not "%EXITCODE%"=="0" (
    echo Falha ao dividir o video.
)

pause
exit /b %EXITCODE%
