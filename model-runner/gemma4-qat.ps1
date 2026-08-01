# gemma4-qat.ps1 - Gemma 4 QAT model runner (Windows) with vision support
#
# Models:
#   e2b:    ~2 GB  (smallest variant)
#   e4b:    ~4 GB  (default, good balance of quality/speed)
#   12b:    ~12 GB (medium variant)
#   26b-a4b:~26 GB (large variant)
#   31b:    ~31 GB (largest variant)
#
# Additional Controls:
# --reasoning-budget N        Cap max tokens for thinking
#   (0 = skip thinking, >N = cap at N, -1 = unlimited)
# --thinking|--think          Enable thinking mode
# --no-thinking               Force non-thinking / instruct mode
#
# Sampling:
#   --temp N              Temperature (default: 1.0)
#   --top-p N             Top-p sampling (default: 0.95)
#   --top-k N             Top-k sampling (default: 64)
#   --min-p N             Min-p sampling (default: 0.0)
#
# Vision / Multimodal:
#   --vision              Enable vision (auto-detect mmproj from source or ~/models)
#   --mmproj-path PATH    Use specific mmproj file
#   --no-mmproj           Disable vision
#   --text-only           Disable vision
#
# Additional controls:
#   --ctx-size N          Context size (default: 262103)
#   --port N              Server port (default: 8082)

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$LLAMA_SERVER = Join-Path $env:USERPROFILE "llama.cpp\build\bin\Release\llama-server.exe"

# Model definitions per variant
$modelVariants = @{
    e2b = @{
        repo      = "unsloth--gemma-4-E2B-it-GGUF"
        revision  = "latest"
        modelFile = "*UD-Q4_K_XL*"
    }
    e4b = @{
        repo      = "unsloth--gemma-4-E4B-it-qat-GGUF"
        revision  = "latest"
        modelFile = "*UD-Q4_K_XL*"
    }
    12b = @{
        repo      = "unsloth--gemma-4-12B-it-qat-GGUF"
        revision  = "latest"
        modelFile = "*UD-Q4_K_XL*"
    }
    '26b-a4b' = @{
        repo      = "unsloth--gemma-4-26B-A4B-it-qat-GGUF"
        revision  = "latest"
        modelFile = "*UD-Q4_K_XL*"
    }
    31b = @{
        repo      = "unsloth--gemma-4-31B-it-qat-GGUF"
        revision  = "latest"
        modelFile = "*UD-Q4_K_XL*"
    }
}

# Defaults
$Port = 8082
$ListenHost = "0.0.0.0"
$Temp = 1.0
$TopP = 0.95
$TopK = 64
$MinP = 0.0
$Ctx = 262144
$ReasoningBudget = -1
$EnableThinking = $false
$EnableVision = $false
$Variant = "e4b"
$visionFlag = $false

# Parse args
$params = $null
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        "--no-thinking" { $EnableThinking = $false }
        "--thinking" { $EnableThinking = $true }
        "--think" { $EnableThinking = $true }
        "--reasoning-budget" { $i++; $ReasoningBudget = [int]$args[$i] }
        "--rb" { $i++; $ReasoningBudget = [int]$args[$i] }
        "--temp" { $i++; $Temp = [double]$args[$i] }
        "--top-p" { $i++; $TopP = [double]$args[$i] }
        "--top-k" { $i++; $TopK = [int]$args[$i] }
        "--min-p" { $i++; $MinP = [double]$args[$i] }
        "--ctx-size" { $i++; $Ctx = [int]$args[$i] }
        "--port" { $i++; $Port = [int]$args[$i] }
        "--host" { $i++; $ListenHost = $args[$i] }
        "--mmproj-path" { $i++; $MMPROJ_OVERRIDE = $args[$i]; $EnableVision = $true }
        "--vision" { $EnableVision = $true; $visionFlag = $true }
        "--no-mmproj" { $EnableVision = $false }
        "--text-only" { $EnableVision = $false }
        "--variant" { $i++; $Variant = $args[$i] }
        "-v" { $i++; $Variant = $args[$i] }

        "--" { $i++; $params = $args[$i..($args.Count-1)] -join " "; break }
        default { Write-Error "Unknown arg: $($args[$i])"; exit 1 }
    }
}

# Resolve model path from selected variant
if (-not $modelVariants.ContainsKey($Variant)) {
    Write-Error "Unknown variant: $Variant. Available: $($modelVariants.Keys -join ', ')"
    exit 1
}

$variantInfo = $modelVariants[$Variant]
$HF_CACHE = Join-Path $env:USERPROFILE ".cache\huggingface\hub"
$MODEL_DIR = Join-Path $HF_CACHE "models--$($variantInfo.repo)\snapshots\$($variantInfo.revision)"

# For HuggingFace models with wildcards, we need to find the actual file
$MODEL = $null
if ($variantInfo.modelFile -like "*UD-Q4_K_XL*") {
    # Look for files matching the pattern
    $foundFiles = Get-ChildItem -Path $MODEL_DIR -Filter "*.gguf" -Recurse | Where-Object { $_.Name -like "*UD-Q4_K_XL*" } | Select-Object -First 1
    if ($foundFiles) {
        $MODEL = $foundFiles.FullName
    }
} else {
    $MODEL = Join-Path $MODEL_DIR $variantInfo.modelFile
}

# Resolve mmproj: explicit override > default location
if ($MMPROJ_OVERRIDE -and (Test-Path $MMPROJ_OVERRIDE)) {
    $MMPROJ = $MMPROJ_OVERRIDE
} elseif ($EnableVision) {
    # Try to find mmproj in the model directory or standard locations
    $mmprojCandidates = @(
        (Join-Path $MODEL_DIR "mmproj*.gguf"),
        (Join-Path $env:USERPROFILE "models\mmproj-gemma4-qat-*.gguf"),
        (Join-Path $env:USERPROFILE "models\mmproj-*.gguf")
    )
    
    $MMPROJ = $null
    foreach ($candidate in $mmprojCandidates) {
        $found = Get-ChildItem -Path $candidate -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $MMPROJ = $found.FullName
            break
        }
    }
} else {
    $MMPROJ = ""
}

# If --vision was used without mmproj, warn but still allow text-only mode
if ($visionFlag -and (-not (Test-Path $MMPROJ))) {
    Write-Host "" -ForegroundColor Yellow
    Write-Host "WARNING: --vision requested but no mmproj found." -ForegroundColor Yellow
    Write-Host "  Running in text-only mode. Vision requires a downloaded mmproj." -ForegroundColor Yellow
    Write-Host ""
}

# Verify model exists
if (-not (Test-Path $MODEL)) {
    Write-Host ""
    Write-Host "Model not found: $MODEL" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Download with:" -ForegroundColor Yellow
    Write-Host "  ./model-runner/download-gemma4-qat.sh $Variant" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# Build args array
$serverArgs = @(
    "-m", $MODEL,
    "--jinja",
    "-np", "1",
    "-fa", "on",
    "-ngl", "99",
    "-c", "$Ctx",
    "--ctx-size", "$Ctx",
    "--top-k", "$TopK",
    "--top-p", "$TopP",
    "--min-p", "$MinP",
    "--temp", "$Temp",
    "--host", $ListenHost,
    "--port", "$Port"
)

if ($EnableVision -and (Test-Path $MMPROJ)) {
    $serverArgs += @("--mmproj", $MMPROJ)
}

if (-not $EnableThinking) {
    $serverArgs += @("--reasoning", "off")
}

$serverArgs += @("--reasoning-budget", "$ReasoningBudget")

# Append custom params if provided
if ($params) {
    $serverArgs += $params.Split(' ')
}

# Print config
$thinkStr = if ($EnableThinking) { "ON" } else { "OFF" }
$visionStr = if ($EnableVision -and (Test-Path $MMPROJ)) { "ON" } else { "OFF" }

Write-Host ""
Write-Host "=== Gemma 4 QAT Runner ===" -ForegroundColor Cyan
Write-Host "variant:  $Variant"
Write-Host "model:    $MODEL"
Write-Host "mmproj:   $(if ($EnableVision -and (Test-Path $MMPROJ)) { $MMPROJ } else { 'none' })"
Write-Host "port:     $Port"
Write-Host "temp:     $Temp  top_p: $TopP  top_k: $TopK"
Write-Host "think:    $thinkStr"
Write-Host "budget:   $ReasoningBudget tokens (0=skip, >N=max, -1=unlimited)"
Write-Host "vision:   $visionStr"
Write-Host "ctx:      $Ctx"
Write-Host ""
Write-Host "Args: $($serverArgs -join ' ')"
Write-Host ""

& $LLAMA_SERVER @serverArgs