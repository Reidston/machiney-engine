<# 
.SYNOPSIS
    Build script for the OpenClaw WSL distribution rootfs.

.DESCRIPTION
    Uses Docker to build a Debian-slim based container, then exports
    the filesystem as install.tar.gz for WSL distribution packaging.

.NOTES
    Prerequisites: Docker Desktop must be installed and running.
#>

param(
    [string]$ImageName = "openclaw-wsl",
    [string]$OutputFile = "install.tar.gz",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  OpenClaw WSL — Distribution Builder v2" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check Docker availability
try {
    docker version | Out-Null
    Write-Host "[OK] Docker is available." -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Docker is not installed or not running." -ForegroundColor Red
    Write-Host "Please install Docker Desktop and ensure it is running." -ForegroundColor Yellow
    exit 1
}

# Step 1: Build Docker image
if (-not $SkipBuild) {
    Write-Host ""
    Write-Host "[Step 1/3] Building Docker image '$ImageName'..." -ForegroundColor Yellow
    docker build -f "$ScriptDir\Dockerfile" -t $ImageName "$ScriptDir\.."
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Docker build failed." -ForegroundColor Red
        exit 1
    }
    Write-Host "[OK] Docker image built successfully." -ForegroundColor Green
}

# Step 2: Create temporary container and export filesystem
Write-Host ""
Write-Host "[Step 2/3] Exporting and compressing rootfs..." -ForegroundColor Yellow

$ContainerName = "openclaw-wsl-export-$(Get-Random)"
docker create --name $ContainerName $ImageName | Out-Null

$TarGzPath = Join-Path $ScriptDir $OutputFile
$TarPath = Join-Path $ScriptDir "install.tar"

# Step 1: Export raw tar (piped gzip fails with OutOfMemoryException on large images)
Write-Host "  Exporting raw rootfs..." -ForegroundColor Gray
docker export -o $TarPath $ContainerName
docker rm $ContainerName | Out-Null

$rawSizeMB = [math]::Round((Get-Item $TarPath).Length / 1MB, 2)
Write-Host "  Raw size: $rawSizeMB MB" -ForegroundColor Gray

# Step 2: Compress with PowerShell native GZipStream
# (WSL gzip on /mnt/c/ paths hangs indefinitely — do NOT use)
Write-Host "  Compressing with GZipStream..." -ForegroundColor Gray

try {
    if (Test-Path $TarGzPath) { Remove-Item $TarGzPath -Force }
    $inputStream = [System.IO.File]::OpenRead($TarPath)
    $outputStream = [System.IO.File]::Create($TarGzPath)
    $gzipStream = New-Object System.IO.Compression.GZipStream($outputStream, [System.IO.Compression.CompressionLevel]::Optimal)
    $inputStream.CopyTo($gzipStream)
    $gzipStream.Close()
    $outputStream.Close()
    $inputStream.Close()
    
    # Remove raw tar to save disk space
    Remove-Item $TarPath -Force
    
    $SizeMB = [math]::Round((Get-Item $TarGzPath).Length / 1MB, 2)
    Write-Host "[OK] Rootfs compressed: $OutputFile ($SizeMB MB, was $rawSizeMB MB raw)" -ForegroundColor Green
}
catch {
    Write-Host "[WARN] Compression failed: $_" -ForegroundColor Yellow
    Write-Host "[WARN] Keeping raw tar ($rawSizeMB MB)" -ForegroundColor Yellow
    $TarGzPath = $TarPath
    $SizeMB = $rawSizeMB
}
Write-Host "[OK] Rootfs exported: $OutputFile ($SizeMB MB)" -ForegroundColor Green

# Step 3: Summary
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Build Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Output:  $TarGzPath" -ForegroundColor White
Write-Host "  Size:    $SizeMB MB" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Run 'npm run tauri build' in the /gui directory" -ForegroundColor White
Write-Host "  2. Tauri will bundle install.tar.gz into the NSIS installer" -ForegroundColor White
Write-Host "  3. Test the installer or submit to Microsoft Store" -ForegroundColor White
