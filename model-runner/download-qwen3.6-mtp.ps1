# download-qwen3.6-mtp.ps1 - Download Qwen3.6-27B MTP (Multi-Token Prediction) from Unsloth
# Usage: .\download-qwen3.6-mtp.ps1 [model|mmproj|all]  (default: all)

param(
    [string]$Variant = "all"
)

$ErrorActionPreference = "Stop"

# Set environment variable to disable XET
$env:HF_HUB_DISABLE_XET = "1"

$repo = "unsloth/Qwen3.6-27B-MTP-GGUF"
$base = Join-Path $env:USERPROFILE "models\unsloth"
$target = Join-Path $base "Qwen3.6-27B-MTP-GGUF"

# Ensure target directory exists
New-Item -ItemType Directory -Force -Path $target | Out-Null

Switch ($Variant.ToLower()) {
    "model" {
        $modelFile = Join-Path $target "Qwen3.6-27B-UD-Q4_K_XL.gguf"
        if (Test-Path $modelFile) {
            Write-Host "[SKIP] Qwen3.6-27B MTP UD-Q4_K_XL already at $modelFile"
            exit 0
        }
        Write-Host "=== Downloading Qwen3.6-27B MTP UD-Q4_K_XL (~18 GB) ==="
        Write-Host "Target: $modelFile"
        huggingface-cli download $repo --include "Qwen3.6-27B-UD-Q4_K_XL.gguf" --local-dir $target
    }
    "mmproj" {
        $mmprojFile = Join-Path $target "mmproj-F16.gguf"
        if (Test-Path $mmprojFile) {
            Write-Host "[SKIP] mmproj-F16 already at $mmprojFile"
            exit 0
        }
        Write-Host "=== Downloading mmproj-F16 (~0.9 GB) ==="
        Write-Host "Target: $mmprojFile"
        huggingface-cli download $repo --include "mmproj-F16.gguf" --local-dir $target
    }
    "all" {
        $modelFile = Join-Path $target "Qwen3.6-27B-UD-Q4_K_XL.gguf"
        $mmprojFile = Join-Path $target "mmproj-F16.gguf"

        # Check if both already exist
        if ((Test-Path $modelFile) -and (Test-Path $mmprojFile)) {
            Write-Host "[SKIP] Qwen3.6-27B MTP already fully downloaded at $target"
            exit 0
        }

        Write-Host "=== Downloading Qwen3.6-27B MTP (~19 GB total) ==="
        Write-Host "Target: $target"

        # Clean up cache if partial download
        $cacheDir = Join-Path $target ".cache"
        if (Test-Path $cacheDir) {
            Remove-Item -Recurse -Force $cacheDir
            Write-Host "Cleaned partial cache at $cacheDir (will resume)"
        }

        if (-not (Test-Path $modelFile)) {
            Write-Host "`nDownloading model Qwen3.6-27B-UD-Q4_K_XL.gguf"
            huggingface-cli download $repo --include "Qwen3.6-27B-UD-Q4_K_XL.gguf" --local-dir $target
        }

        if (-not (Test-Path $mmprojFile)) {
            Write-Host "`nDownloading mmproj-F16.gguf"
            huggingface-cli download $repo --include "mmproj-F16.gguf" --local-dir $target
        }

        # Clean up cache after successful download
        if (Test-Path $cacheDir) {
            Remove-Item -Recurse -Force $cacheDir
            Write-Host "`nCleaned cache at $cacheDir"
        }
    }
    default {
        Write-Error "Usage: $MyInvocation.MyCommand.Name [model|mmproj|all]"
        exit 1
    }
}

Write-Host "`nDone:"
$ggufFiles = Get-ChildItem -Path $target -Filter "*.gguf"
foreach ($f in $ggufFiles) {
    $sizeGB = $f.Length / 1e9
    Write-Host "  $($f.Name) ($($sizeGB.ToString('0.0')) GB)"
}
