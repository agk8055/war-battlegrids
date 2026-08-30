# ==============================================================================
# Automated Windows Build & Installer Script for Flutter (War App)
# ==============================================================================

param (
    [switch]$Clean,
    [switch]$NoTreeShakeIcons,
    [switch]$OpenFolder
)

$ErrorActionPreference = "Stop"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Flutter Windows Build & Setup Creator  " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# 1. Detect Version from pubspec.yaml
if (-not (Test-Path "pubspec.yaml")) {
    Write-Error "pubspec.yaml not found! Make sure you run this script from the project root."
    exit 1
}

$pubspecContent = Get-Content "pubspec.yaml" -Raw
if ($pubspecContent -match 'version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
    $version = $matches[1]
    Write-Host "[OK] App version detected from pubspec.yaml: v$version" -ForegroundColor Green
} else {
    $version = "1.0.0"
    Write-Host "[!] Could not parse version, defaulting to: v$version" -ForegroundColor Yellow
}

# 2. Locate Inno Setup Compiler (ISCC.exe)
$isccCandidates = @(
    (Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe"),
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe"
)

$isccPath = $null
foreach ($path in $isccCandidates) {
    if ($path -and (Test-Path $path)) {
        $isccPath = $path
        break
    }
}

if (-not $isccPath) {
    $cmd = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue
    if ($cmd) {
        $isccPath = $cmd.Source
    }
}

if (-not $isccPath) {
    Write-Error "Inno Setup Compiler (ISCC.exe) not found. Run: winget install JRSoftware.InnoSetup"
    exit 1
}

Write-Host "[OK] Inno Setup Compiler located: $isccPath" -ForegroundColor Green

# 3. Optional Clean
if ($Clean) {
    Write-Host "`n[*] Cleaning previous build artifacts..." -ForegroundColor Yellow
    flutter clean
    flutter pub get
}

# 4. Build Flutter Windows Release
Write-Host "`n[*] Building Windows release executable with Flutter..." -ForegroundColor Yellow

$buildArgs = @("build", "windows", "--release")
if ($NoTreeShakeIcons) {
    $buildArgs += "--no-tree-shake-icons"
}

& flutter @buildArgs
if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter build failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Host "[OK] Flutter Windows build completed successfully!" -ForegroundColor Green

# 5. Compile Inno Setup Installer
Write-Host "`n[*] Compiling installer using Inno Setup..." -ForegroundColor Yellow
$issFile = "inno_setup.iss"

if (-not (Test-Path $issFile)) {
    Write-Error "Inno Setup script '$issFile' not found in workspace!"
    exit 1
}

$versionArg = "/DMyAppVersion=" + $version
& $isccPath $versionArg $issFile
if ($LASTEXITCODE -ne 0) {
    Write-Error "Inno Setup compilation failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

$outputInstaller = "build\windows\installer\War_Setup_v$version.exe"
if (Test-Path $outputInstaller) {
    $fileItem = Get-Item $outputInstaller
    $fileSizeMB = [math]::Round($fileItem.Length / 1MB, 2)
    Write-Host "`n=========================================" -ForegroundColor Green
    Write-Host " [OK] Installer successfully created!" -ForegroundColor Green
    Write-Host " File: $outputInstaller" -ForegroundColor Cyan
    Write-Host " Size: $fileSizeMB MB" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Green
    
    if ($OpenFolder) {
        $fullPath = (Resolve-Path $outputInstaller).Path
        explorer.exe "/select,$fullPath"
    }
} else {
    Write-Host "`n[OK] Installer script completed. Check build\windows\installer" -ForegroundColor Green
}
