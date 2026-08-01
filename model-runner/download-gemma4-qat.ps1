# download-gemma4-qat.ps1 - Download Gemma 4 QAT variants from Unsloth or HuggingFace
# Usage: ./download-gemma4-qat.ps1 [e2b|e4b|12b|26b-a4b|31b]  (default: e4b)

param(
    [string]$Variant = "e4b"
)

$ErrorActionPreference = "Stop"

# Set environment variable to disable XET
$env:HF_HUB_DISABLE_XET = "1"

# Define configurations
$configs = @{
    "e2b"      = @{repo = "unsloth/gemma-4-E2B-it-GGUF"; include = "*UD-Q4_K_XL*"; target = "gemma4-qat-e2b"}
    "e4b"      = @{repo = "unsloth/gemma-4-E4B-it-qat-GGUF"; include = "*UD-Q4_K_XL*"; target = "gemma4-qat-e4b"}
    "12b"      = @{repo = "unsloth/gemma-4-12B-it-qat-GGUF"; include = "*UD-Q4_K_XL*"; target = "gemma4-qat-12b"}
    "26b-a4b"  = @{repo = "unsloth/gemma-4-26B-A4B-it-qat-GGUF"; include = "*UD-Q4_K_XL*"; target = "gemma4-qat-26b-a4b"}
    "31b"      = @{repo = "unsloth/gemma-4-31B-it-qat-GGUF"; include = "*UD-Q4_K_XL*"; target = "gemma4-qat-31b"}
}

if (-not $configs.ContainsKey($Variant)) {
    Write-Error "Usage: $MyInvocation.MyCommand.Name [e2b|e4b|12b|26b-a4b|31b]"
    exit 1
}

$cfg = $configs[$Variant]
$base = Join-Path $env:USERPROFILE "models\gemma4-qat"
$target = Join-Path $base $cfg.target

# Check if already downloaded
$ggufFiles = Get-ChildItem -Path $target -Filter "*.gguf" -ErrorAction SilentlyContinue
if ($ggufFiles.Count -ge 1) {
    Write-Host "[SKIP] Gemma 4 QAT $Variant already at $target"
    exit 0
}

$sizes = @{
    "e2b"     = "~2 GB"
    "e4b"     = "~4 GB"
    "12b"     = "~12 GB"
    "26b-a4b" = "~26 GB"
    "31b"     = "~31 GB"
}

Write-Host "=== Downloading Gemma 4 QAT $Variant ($($sizes[$Variant])) ==="
Write-Host "Target: $target"
New-Item -ItemType Directory -Force -Path $target | Out-Null

# Clean up cache if partial download
$cacheDir = Join-Path $target ".cache"
if (Test-Path $cacheDir) {
    Remove-Item -Recurse -Force $cacheDir
    Write-Host "Cleaned partial cache at $cacheDir (will resume)"
}

Write-Host "`nDownloading from $($cfg.repo) with include pattern $($cfg.include)"
# Use huggingface-cli download for filtered downloads
try {
    $result = Start-Process -FilePath "huggingface-cli" -ArgumentList "download", $cfg.repo, "--include", $cfg.include, "--local-dir", $target -Wait -NoNewWindow -PassThru
    
    if ($result.ExitCode -ne 0) {
        Write-Error "Error downloading model"
        exit 1
    }
} catch {
    Write-Error "Error downloading model: $_"
    exit 1
}

# Clean up cache after successful download
if (Test-Path $cacheDir) {
    Remove-Item -Recurse -Force $cacheDir
    Write-Host "`nCleaned cache at $cacheDir"
}

Write-Host "`nDone:"
$ggufFiles = Get-ChildItem -Path $target -Filter "*.gguf"
foreach ($f in $ggufFiles) {
    $sizeGB = $f.Length / 1e9
    Write-Host "  $($f.Name) ($($sizeGB.ToString('0.0')) GB)"
}