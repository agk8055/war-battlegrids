@echo off
REM Windows batch wrapper for build_windows.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_windows.ps1" %*
