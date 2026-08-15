# download-qwen3.8-27b.ps1 - Download Qwen3.8-27B quantized variants from Unsloth
# Usage: .\download-qwen3.8-27b.ps1 [ud8|ud6|ud5|ud4|ud3|ud2|q8|q4|bf16|mmproj|all]  (default: ud4)

param(
    [string]$Variant = "ud4"
)

$ErrorActionPreference = "Stop"

$env:HF_HUB_DISABLE_XET = "1"

$repo = "unsloth/Qwen3.8-27B-GGUF"
$base = Join-Path $env:USERPROFILE "models\unsloth"
$target = Join-Path $base "Qwen3.8-27B-GGUF"

New-Item -ItemType Directory -Force -Path $target | Out-Null

$models = @{
    "ud8"  = @{ file = "Qwen3.8-27B-UD-Q8_K_XL.gguf";  size = "~31.5 GB" }
    "ud6"  = @{ file = "Qwen3.8-27B-UD-Q6_K_XL.gguf";  size = "~25.9 GB" }
    "ud5"  = @{ file = "Qwen3.8-27B-UD-Q5_K_XL.gguf";  size = "~20.2 GB" }
    "ud4"  = @{ file = "Qwen3.8-27B-UD-Q4_K_XL.gguf";  size = "~17.9 GB" }
    "ud3"  = @{ file = "Qwen3.8-27B-UD-Q3_K_XL.gguf";  size = "~13.4 GB" }
    "ud2"  = @{ file = "Qwen3.8-27B-UD-Q2_K_XL.gguf";  size = "~10.7 GB" }
    "q8"   = @{ file = "Qwen3.8-27B-Q8_0.gguf";         size = "~29 GB" }
    "q4"   = @{ file = "Qwen3.8-27B-Q4_K_M.gguf";       size = "~17.1 GB" }
}

$bf16Dir = Join-Path $target "BF16"
New-Item -ItemType Directory -Force -Path $bf16Dir | Out-Null

Switch ($Variant.ToLower()) {
    { $models.ContainsKey($_) } {
        $cfg = $models[$Variant.ToLower()]
        $modelFile = Join-Path $target $cfg.file
        if (Test-Path $modelFile) {
            Write-Host "[SKIP] Qwen3.8-27B $($cfg.file) already at $modelFile"
            exit 0
        }
        Write-Host "=== Downloading Qwen3.8-27B $($cfg.file) ($($cfg.size)) ==="
        Write-Host "Target: $modelFile"
        huggingface-cli download $repo --include $cfg.file --local-dir $target
    }
    "bf16" {
        $bf16Files = @(
            "BF16/Qwen3.8-27B-BF16-00001-of-00002.gguf",
            "BF16/Qwen3.8-27B-BF16-00002-of-00002.gguf"
        )
        $f1 = Join-Path $bf16Dir "Qwen3.8-27B-BF16-00001-of-00002.gguf"
        $f2 = Join-Path $bf16Dir "Qwen3.8-27B-BF16-00002-of-00002.gguf"
        if ((Test-Path $f1) -and (Test-Path $f2)) {
            Write-Host "[SKIP] Qwen3.8-27B BF16 already at $bf16Dir"
            exit 0
        }
        Write-Host "=== Downloading Qwen3.8-27B BF16 (~55 GB, 2 shards) ==="
        Write-Host "Target: $bf16Dir"
        foreach ($inc in $bf16Files) {
            Write-Host "`nDownloading $inc"
            huggingface-cli download $repo --include $inc --local-dir $target
        }
    }
    "mmproj" {
        $mmprojFiles = @("mmproj-BF16.gguf", "mmproj-F16.gguf")
        $allPresent = $true
        foreach ($mf in $mmprojFiles) {
            if (-not (Test-Path (Join-Path $target $mf))) {
                $allPresent = $false
                break
            }
        }
        if ($allPresent) {
            Write-Host "[SKIP] mmproj files already at $target"
            exit 0
        }
        Write-Host "=== Downloading mmproj files (~1.8 GB) ==="
        Write-Host "Target: $target"
        foreach ($mf in $mmprojFiles) {
            $fullPath = Join-Path $target $mf
            if (-not (Test-Path $fullPath)) {
                Write-Host "`nDownloading $mf"
                huggingface-cli download $repo --include $mf --local-dir $target
            } else {
                Write-Host "`n[SKIP] $mf already exists"
            }
        }
    }
    "all" {
        $modelFile = Join-Path $target "Qwen3.8-27B-UD-Q4_K_XL.gguf"
        $mmprojF16 = Join-Path $target "mmproj-F16.gguf"
        if ((Test-Path $modelFile) -and (Test-Path $mmprojF16)) {
            Write-Host "[SKIP] Qwen3.8-27B (UD-Q4 + mmproj) already fully downloaded at $target"
            exit 0
        }
        Write-Host "=== Downloading Qwen3.8-27B UD-Q4_K_XL + mmproj (~19.7 GB total) ==="
        Write-Host "Target: $target"

        $cacheDir = Join-Path $target ".cache"
        if (Test-Path $cacheDir) {
            Remove-Item -Recurse -Force $cacheDir
            Write-Host "Cleaned partial cache at $cacheDir (will resume)"
        }

        if (-not (Test-Path $modelFile)) {
            Write-Host "`nDownloading Qwen3.8-27B-UD-Q4_K_XL.gguf"
            huggingface-cli download $repo --include "Qwen3.8-27B-UD-Q4_K_XL.gguf" --local-dir $target
        }

        foreach ($mf in @("mmproj-F16.gguf", "mmproj-BF16.gguf")) {
            $fullPath = Join-Path $target $mf
            if (-not (Test-Path $fullPath)) {
                Write-Host "`nDownloading $mf"
                huggingface-cli download $repo --include $mf --local-dir $target
            } else {
                Write-Host "`n[SKIP] $mf already exists"
            }
        }

        if (Test-Path $cacheDir) {
            Remove-Item -Recurse -Force $cacheDir
            Write-Host "`nCleaned cache at $cacheDir"
        }
    }
    default {
        Write-Error "Usage: $MyInvocation.MyCommand.Name [ud8|ud6|ud5|ud4|ud3|ud2|q8|q4|bf16|mmproj|all]"
        exit 1
    }
}

Write-Host "`nDone:"
$ggufFiles = Get-ChildItem -Path $target -Filter "*.gguf" -Recurse
foreach ($f in $ggufFiles) {
    $sizeGB = $f.Length / 1e9
    Write-Host "  $($f.Name) ($($sizeGB.ToString('0.0')) GB)"
}
