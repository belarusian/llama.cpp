# qwen36_bartowski.ps1 - Qwen3.6-27B runner (CUDA) using bartowski GGUFs
#
# Thinking modes:
#   --thinking          ON  | temp=1.0, top_p=0.95, presence=1.5  - General chatty
#   --thinking-precise  ON  | temp=0.6, top_p=0.95, presence=0.0  - Precise coding
#   --instruct          OFF | temp=0.7, top_p=0.8                 - Direct answers
#   --reasoning         OFF | temp=1.0, top_p=0.95                - Reasoning (direct output)
#
# Model source:
#   --source unsloth     Use unsloth/Qwen3.6-27B-GGUF (UD-Q4_K_XL) [default]
#   --source bartowski   Use bartowski/Qwen_Qwen3.6-27B-GGUF (Q4_K_L)
#
# Additional controls:
#   --no-thinking          Force non-thinking (same as --instruct)
#   --reasoning-budget N   Cap max tokens for thinking (0=skip, -1=unlimited)
#   --temp N               Temperature (default: 1.0)
#   --top-p N              Top-p sampling (default: 0.95)
#   --top-k N              Top-k sampling (default: 20)
#   --min-p N              Min-p sampling (default: 0.0)
#   --ctx-size N           Context size (default: 65536)
#   --port N               Server port (default: 8080)
#   --vision              Enable vision (auto-detect mmproj from bartowski or ~/models)
#   --no-mmproj           Disable vision

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$LLAMA_SERVER = Join-Path $SCRIPT_DIR "build\bin\Release\llama-server.exe"

$HF_CACHE = Join-Path $env:USERPROFILE ".cache\huggingface\hub"

# Model definitions per source
$modelSources = @{
    unsloth = @{
        repo      = "unsloth--Qwen3.6-27B-GGUF"
        revision  = "82d411acf4a06cfb8d9b073a5211bf410bfc29bf"
        modelFile = "Qwen3.6-27B-UD-Q4_K_XL.gguf"
        mmproj    = "mmproj-F16.gguf"
    }
    bartowski = @{
        repo      = "bartowski--Qwen_Qwen3.6-27B-GGUF"
        revision  = "4612927928b49982f8319dc3e2e6f62b9b73b192"
        modelFile = "Qwen_Qwen3.6-27B-Q4_K_L.gguf"
        mmproj    = "mmproj-Qwen_Qwen3.6-27B-f16.gguf"
    }
}

# Defaults
$Port = 8080
$ListenHost = "0.0.0.0"
$Temp = 1.0
$TopP = 0.95
$TopK = 20
$MinP = 0.0
$Presence = 1.5
$Ctx = 65536
$ReasoningBudget = -1
$EnableThinking = $false
$EnableVision = $false
$FitMode = "auto"
$Source = "unsloth"
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
        "--presence-penalty" { $i++; $Presence = [double]$args[$i] }
        "--ctx-size" { $i++; $Ctx = [int]$args[$i] }
        "--port" { $i++; $Port = [int]$args[$i] }
        "--host" { $i++; $ListenHost = $args[$i] }
        "--mmproj-path" { $i++; $MMPROJ_OVERRIDE = $args[$i]; $EnableVision = $true }
        "--vision" { $EnableVision = $true; $visionFlag = $true }
        "--no-mmproj" { $EnableVision = $false }
        "--text-only" { $EnableVision = $false }
        "--thinking-precise" { $Temp = 0.6; $Presence = 0.0; $EnableThinking = $true }
        "--instruct" { $EnableThinking = $false; $Temp = 0.7; $TopP = 0.8 }
        "--reasoning" { $EnableThinking = $false; $Temp = 1.0; $TopP = 0.95 }
        "--fit" { $FitMode = $args[++$i] }
        "--source" { $i++; $Source = $args[$i] }

        "--" { $i++; $params = $args[$i..($args.Count-1)] -join " "; break }
        default { Write-Error "Unknown arg: $($args[$i])"; exit 1 }
    }
}

# Resolve model path from selected source
if (-not $modelSources.ContainsKey($Source)) {
    Write-Error "Unknown source: $Source. Available: $($modelSources.Keys -join ', ')"
    exit 1
}

$sourceInfo = $modelSources[$Source]
$MODEL_DIR = Join-Path $HF_CACHE "models--$($sourceInfo.repo)\snapshots\$($sourceInfo.revision)"
$MODEL = Join-Path $MODEL_DIR $sourceInfo.modelFile

# Resolve mmproj: explicit override > bartowski repo (unsloth only) > ~/models fallback for bartowski
if ($MMPROJ_OVERRIDE -and (Test-Path $MMPROJ_OVERRIDE)) {
    $MMPROJ = $MMPROJ_OVERRIDE
} elseif ((Test-Path (Join-Path $MODEL_DIR $sourceInfo.mmproj))) {
    $MMPROJ = Join-Path $MODEL_DIR $sourceInfo.mmproj
} elseif ($Source -eq "bartowski" -and (-not $MMPROJ_OVERRIDE)) {
    # bartowski Qwen3.6-27B doesn't ship mmproj in its HF repo; check ~/models for compatible projector
    $FALLBACK_MMPROJ = Join-Path $env:USERPROFILE "models\mmproj-Qwen3VL-30B-A3B-Instruct-F16.gguf"
    if (Test-Path $FALLBACK_MMPROJ) {
        $MMPROJ = $FALLBACK_MMPROJ
    } else {
        $MMPROJ = ""
    }
} else {
    $MMPROJ = Join-Path $MODEL_DIR $sourceInfo.mmproj
}

# If --vision was used without mmproj, warn but still allow text-only mode
if ($visionFlag -and (-not (Test-Path $MMPROJ))) {
    Write-Host "" -ForegroundColor Yellow
    Write-Host "WARNING: --vision requested but no mmproj found at:" -ForegroundColor Yellow
    Write-Host "  Expected: $(Join-Path $MODEL_DIR $sourceInfo.mmproj)" -ForegroundColor DarkYellow
    if ($Source -eq "bartowski") {
        Write-Host "  Fallback checked: ~/models/mmproj-Qwen3VL-30B-A3B-Instruct-F16.gguf" -ForegroundColor DarkYellow
    }
    Write-Host "  Running in text-only mode. Vision requires a downloaded mmproj." -ForegroundColor Yellow
    Write-Host ""
}

# Verify model exists
if (-not (Test-Path $MODEL)) {
    Write-Host ""
    Write-Host "Model not found: $MODEL" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Download with:" -ForegroundColor Yellow
    Write-Host "  huggingface-cli download $($sourceInfo.repo.replace('--', '/')) `r`n"
    Write-Host "    --revision $($sourceInfo.revision) `r`n"
    Write-Host "    --local-dir $($MODEL_DIR.Replace('\snapshots\', '').Replace('\','/')) `r`n"
    Write-Host "    $($sourceInfo.modelFile)" -ForegroundColor Yellow
    Write-Host ""
    $mmprojHfName = $sourceInfo.mmproj -replace '-Qwen_Qwen3\.6-27B', ''
    if ($mmprojHfName) {
        Write-Host "  # And the vision projector:" -ForegroundColor DarkYellow
        Write-Host "  huggingface-cli download $($sourceInfo.repo.replace('--', '/')) `r`n"
        Write-Host "    --revision $($sourceInfo.revision) `r`n"
        Write-Host "    --local-dir $($MODEL_DIR.Replace('\snapshots\', '').Replace('\','/')) `r`n"
        Write-Host "    $($sourceInfo.mmproj)" -ForegroundColor Yellow
        Write-Host ""
    }
    exit 1
}

# Build args array
$serverArgs = @(
    "-m", $MODEL,
    "--jinja",
    "-np", "1",
    "-ngl", "99",
    "-c", "$Ctx",
    "--ctx-size", "$Ctx",
    "--top-k", "$TopK",
    "--top-p", "$TopP",
    "--min-p", "$MinP",
    "--temp", "$Temp",
    "--presence-penalty", "$Presence",
    "--host", $ListenHost,
    "--port", "$Port"
)

if ($EnableVision -and (Test-Path $MMPROJ)) {
    $serverArgs += @("--mmproj", $MMPROJ)
}

# Enable idle slot caching for dual-model bridge slot-based context transfer.
# --cache-ram 0 disables the prompt cache entirely, which also auto-disables idle slot caching.
# Use default 8192 MiB (or adjust as needed) so idle slots can be saved/restored via /slots API.
$serverArgs += "--cache-ram", "8192"

if (-not $EnableThinking) {
    $serverArgs += @("--reasoning", "off")
}

$serverArgs += @("--reasoning-budget", "$ReasoningBudget")

$(if ($FitMode -ne "auto") { $serverArgs += @("--fit", "$FitMode") })

# Append custom params if provided
if ($params) {
    $serverArgs += $params.Split(' ')
}

# Print config
$thinkStr = if ($EnableThinking) { "ON" } else { "OFF" }
$visionStr = if ($EnableVision -and (Test-Path $MMPROJ)) { "ON" } else { "OFF" }

Write-Host ""
Write-Host "=== Qwen3.6-27B Runner ===" -ForegroundColor Cyan
Write-Host "source:   $Source"
Write-Host "model:    $MODEL"
Write-Host "mmproj:   $(if ($EnableVision -and (Test-Path $MMPROJ)) { $MMPROJ } else { 'none' })"
Write-Host "port:     $Port"
Write-Host "temp:     $Temp  top_p: $TopP"
Write-Host "think:    $thinkStr"
Write-Host "budget:   $ReasoningBudget tokens (0=skip, >N=max, -1=unlimited)"
Write-Host "vision:   $visionStr"
Write-Host "ctx:      $Ctx"
Write-Host "fit:      $FitMode"
Write-Host ""
Write-Host "Args: $($serverArgs -join ' ')"
Write-Host ""

& $LLAMA_SERVER @serverArgs
