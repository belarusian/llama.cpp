# qwen36-mtp.ps1 - Qwen3.6-27B MTP (Multi-Token Prediction) runner with speculative decoding
#
# Simplified for 2 primary use cases:
#   --coding   : Thinking mode, precise coding tasks
#                temp=0.6, top_p=0.95, top_k=20, min_p=0.0, presence_penalty=0.0
#   --agentic  : Non-thinking mode (instruct), for tool-calling/agentic work
#                temp=0.7, top_p=0.8, top_k=20, min_p=0.0, presence_penalty=1.5
#
# MTP speculative decoding:
#   Enabled by default: --spec-type draft-mtp --spec-draft-n-max 2
#   Use --no-mtp to disable, or --spec-n-max N to adjust
#
# Vision:
#   --vision              Enable vision (auto-detect mmproj-F16 from repo or ~/models)
#   --mmproj-path PATH    Use specific mmproj file
#   --no-mmproj           Disable vision
#
# Additional controls:
#   --temp N               Temperature (overrides use case default)
#   --top-p N              Top-p sampling
#   --top-k N              Top-k sampling
#   --min-p N              Min-p sampling
#   --ctx-size N           Context size (default: 65536)

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$LLAMA_SERVER = Join-Path $env:USERPROFILE "llama.cpp\build\bin\Release\llama-server.exe"

# Model lives in ~/models/unsloth/Qwen3.6-27B-MTP-GGUF
$MODEL_DIR = Join-Path $env:USERPROFILE "models\unsloth\Qwen3.6-27B-MTP-GGUF"
$MODEL = Join-Path $MODEL_DIR "Qwen3.6-27B-UD-Q4_K_XL.gguf"

# Defaults
$Port = 8080
$ListenHost = "0.0.0.0"
$Temp = 1.0
$TopP = 0.95
$TopK = 20
$MinP = 0.0
$Presence = 1.5
$Ctx = 65536
$EnableThinking = $false
$EnableVision = $false
$MTPEnabled = $true
$SpecNMax = 2

# Parse args
$params = $null
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        "--coding" {
            $USE_CASE = "coding"
            $EnableThinking = $true
            $Temp = 0.6
            $TopP = 0.95
            $Presence = 0.0
        }
        "--agentic" {
            $USE_CASE = "agentic"
            $EnableThinking = $false
            $Temp = 0.7
            $TopP = 0.8
            $Presence = 1.5
        }
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
        "--mtp" { $MTPEnabled = $true }
        "--enable-mtp" { $MTPEnabled = $true }
        "--no-mtp" { $MTPEnabled = $false }
        "--spec-n-max" { $i++; $SpecNMax = [int]$args[$i] }
        "--sn" { $i++; $SpecNMax = [int]$args[$i] }

        "--" { $i++; $params = $args[$i..($args.Count-1)] -join " "; break }
        default { Write-Error "Unknown arg: $($args[$i])"; exit 1 }
    }
}

# Default to --coding if no use case specified
if (-not (Test-Path Variable:USE_CASE)) {
    $USE_CASE = "coding"
    $EnableThinking = $true
    $Temp = 0.6
    $TopP = 0.95
    $Presence = 0.0
}

# Resolve mmproj: explicit override > repo directory > ~/models fallback
if ($MMPROJ_OVERRIDE -and (Test-Path $MMPROJ_OVERRIDE)) {
    $MMPROJ = $MMPROJ_OVERRIDE
} elseif (Test-Path (Join-Path $MODEL_DIR "mmproj-F16.gguf")) {
    $MMPROJ = Join-Path $MODEL_DIR "mmproj-F16.gguf"
} else {
    $FALLBACK_MMPROJ = Join-Path $env:USERPROFILE "models\mmproj-Qwen3VL-30B-A3B-Instruct-F16.gguf"
    if (Test-Path $FALLBACK_MMPROJ) {
        $MMPROJ = $FALLBACK_MMPROJ
    } else {
        $MMPROJ = ""
    }
}

# If --vision was used without mmproj, warn but still allow text-only mode
if ($visionFlag -and (-not (Test-Path $MMPROJ))) {
    Write-Host "" -ForegroundColor Yellow
    Write-Host "WARNING: --vision requested but no mmproj found at:" -ForegroundColor Yellow
    Write-Host "  Expected: $(Join-Path $MODEL_DIR 'mmproj-F16.gguf')" -ForegroundColor DarkYellow
    Write-Host "  Fallback checked: ~/models/mmproj-Qwen3VL-30B-A3B-Instruct-F16.gguf" -ForegroundColor DarkYellow
    Write-Host "  Running in text-only mode. Vision requires a downloaded mmproj." -ForegroundColor Yellow
    Write-Host ""
}

# Verify model exists
if (-not (Test-Path $MODEL)) {
    Write-Host ""
    Write-Host "Model not found: $MODEL" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Download with:" -ForegroundColor Yellow
    Write-Host "  .\download-qwen3.6-mtp.ps1" -ForegroundColor Yellow
    Write-Host ""
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

# Idle slot caching for dual-model bridge context transfer
$serverArgs += "--cache-ram", "8192"

if (-not $EnableThinking) {
    $serverArgs += @("--reasoning", "off")
}

# MTP speculative decoding
if ($MTPEnabled) {
    $serverArgs += @("--spec-type", "draft-mtp", "--spec-draft-n-max", "$SpecNMax")
}

# Append custom params if provided
if ($params) {
    $serverArgs += $params.Split(' ')
}

# Print config
$thinkStr = if ($EnableThinking) { "ON" } else { "OFF" }
$visionStr = if ($EnableVision -and (Test-Path $MMPROJ)) { "ON" } else { "OFF" }
$mtpStr = if ($MTPEnabled) { "ON (n_max=$SpecNMax)" } else { "OFF" }

Write-Host ""
Write-Host "=== Qwen3.6-27B MTP Runner ===" -ForegroundColor Cyan
Write-Host "use-case: $USE_CASE"
Write-Host "model:    $MODEL"
Write-Host "mmproj:   $(if ($EnableVision -and (Test-Path $MMPROJ)) { $MMPROJ } else { 'none' })"
Write-Host "port:     $Port"
Write-Host "temp:     $Temp  top_p: $TopP  top_k: $TopK"
Write-Host "think:    $thinkStr"
Write-Host "vision:   $visionStr"
Write-Host "mtp:      $mtpStr"
Write-Host "presence: $Presence"
Write-Host "ctx:      $Ctx"
Write-Host ""
Write-Host "Args: $($serverArgs -join ' ')"
Write-Host ""

& $LLAMA_SERVER @serverArgs
