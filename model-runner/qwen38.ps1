# qwen38.ps1 - Qwen3.8-27B server runner
#
# Alibaba's 27B dense model, Unsloth dynamic quants.
# Vision (mmproj) enabled by default, disable with --no-mmproj.
# Thinking mode enabled by default.
# MTP speculative decoding enabled by default: --spec-type draft-mtp --spec-draft-n-max 2
#
# Thinking levels (via --think-level N):
#   0  : off (no thinking)
#   1  : low
#   2  : medium (default for --coding)
#   3  : xhigh
#
# Based on Unsloth best practices:
#   Thinking: temp=1.0, top_p=0.95, top_k=20, min_p=0.0, presence=0.0, repeat=1.0
#   Instruct: temp=0.7, top_p=0.80, top_k=20, min_p=0.0, presence=1.5, repeat=1.0
#
# Use Cases:
#   --coding   : Thinking mode, precise coding tasks
#                temp=1.0, top_p=0.95, top_k=20, min_p=0.0, presence_penalty=0.0
#   --agentic  : Non-thinking mode (instruct), tool-calling/agentic work
#                temp=0.7, top_p=0.80, top_k=20, min_p=0.0, presence_penalty=1.5
#
# Thinking depth control:
#   --think-level 0|1|2|3   (off|low|medium|xhigh) - default 2 for --coding
#
# Metrics:
#   --metrics   Enable prometheus metrics endpoint (/metrics)

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$LLAMA_SERVER = Join-Path $env:USERPROFILE "llama.cpp\build\bin\Release\llama-server.exe"

$MODEL_DIR = Join-Path $env:USERPROFILE "models\unsloth\Qwen3.8-27B-GGUF"

$Port = 8080
$ListenHost = "0.0.0.0"
$Quant = "UD-Q4_K_XL"
$MTPEnabled = $true
$SpecNMax = 2
$UseCase = ""
$Temp = 1.0
$TopP = 0.95
$TopK = 20
$MinP = 0.0
$Presence = 0.0
$Repeat = 1.0
$Ctx = 65536
$EnableThinking = $true
$ReasoningBudget = -1
$ReasoningPreserve = $false
$Metrics = $false
$ThinkLevel = 2
$EnableVision = $true

$modelMap = @{
    "UD-Q8_K_XL" = "Qwen3.8-27B-UD-Q8_K_XL.gguf"
    "UD-Q6_K_XL" = "Qwen3.8-27B-UD-Q6_K_XL.gguf"
    "UD-Q5_K_XL" = "Qwen3.8-27B-UD-Q5_K_XL.gguf"
    "UD-Q4_K_XL" = "Qwen3.8-27B-UD-Q4_K_XL.gguf"
    "UD-Q3_K_XL" = "Qwen3.8-27B-UD-Q3_K_XL.gguf"
    "UD-Q2_K_XL" = "Qwen3.8-27B-UD-Q2_K_XL.gguf"
    "Q8_0"       = "Qwen3.8-27B-Q8_0.gguf"
    "Q4_K_M"     = "Qwen3.8-27B-Q4_K_M.gguf"
    "BF16"       = "BF16\Qwen3.8-27B-BF16-00001-of-00002.gguf"
}

$MODEL = Join-Path $MODEL_DIR $modelMap[$Quant]
$MMPROJ = Join-Path $MODEL_DIR "mmproj-F16.gguf"

$params = $null
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        "--coding" {
            $UseCase = "coding"
            $EnableThinking = $true
            $ThinkLevel = 2
            $Temp = 1.0
            $TopP = 0.95
            $Presence = 0.0
        }
        "--agentic" {
            $UseCase = "agentic"
            $EnableThinking = $false
            $ThinkLevel = 0
            $Temp = 0.7
            $TopP = 0.8
            $Presence = 1.5
        }
        "--no-thinking" { $EnableThinking = $false }
        "--thinking" { $EnableThinking = $true }
        "--think" { $EnableThinking = $true }
        "--think-level" { $i++; $ThinkLevel = [int]$args[$i] }
        "--tl" { $i++; $ThinkLevel = [int]$args[$i] }
        "--reasoning-budget" { $i++; $ReasoningBudget = [int]$args[$i] }
        "--rb" { $i++; $ReasoningBudget = [int]$args[$i] }
        "--reasoning-preserve" { $ReasoningPreserve = $true }
        "--no-reasoning-preserve" { $ReasoningPreserve = $false }
        "--temp" { $i++; $Temp = [double]$args[$i] }
        "--t" { $i++; $Temp = [double]$args[$i] }
        "--top-p" { $i++; $TopP = [double]$args[$i] }
        "--top-k" { $i++; $TopK = [int]$args[$i] }
        "--k" { $i++; $TopK = [int]$args[$i] }
        "--min-p" { $i++; $MinP = [double]$args[$i] }
        "--presence-penalty" { $i++; $Presence = [double]$args[$i] }
        "--repeat-penalty" { $i++; $Repeat = [double]$args[$i] }
        "--ctx-size" { $i++; $Ctx = [int]$args[$i] }
        "--c" { $i++; $Ctx = [int]$args[$i] }
        "--port" { $i++; $Port = [int]$args[$i] }
        "--host" { $i++; $ListenHost = $args[$i] }
        "--mmproj-path" { $i++; $MMPROJ = $args[$i]; $EnableVision = $true }
        "--no-mmproj" { $EnableVision = $false }
        "--metrics" { $Metrics = $true }
        "--no-metrics" { $Metrics = $false }
        "--text-only" { $EnableVision = $false }
        "--mtp" { $MTPEnabled = $true }
        "--enable-mtp" { $MTPEnabled = $true }
        "--no-mtp" { $MTPEnabled = $false }
        "--spec-n-max" { $i++; $SpecNMax = [int]$args[$i] }
        "--sn" { $i++; $SpecNMax = [int]$args[$i] }
        "--quant" {
            $i++
            $Quant = $args[$i]
            if (-not $modelMap.ContainsKey($Quant)) {
                Write-Error "Unknown quant: $Quant. Available: $($modelMap.Keys -join ', ')"
                exit 1
            }
            $MODEL = Join-Path $MODEL_DIR $modelMap[$Quant]
        }
        "--q" {
            $i++
            $Quant = $args[$i]
            if (-not $modelMap.ContainsKey($Quant)) {
                Write-Error "Unknown quant: $Quant. Available: $($modelMap.Keys -join ', ')"
                exit 1
            }
            $MODEL = Join-Path $MODEL_DIR $modelMap[$Quant]
        }
        "--" { $i++; $params = $args[$i..($args.Count - 1)] -join " "; break }
        default { Write-Error "Unknown arg: $($args[$i])"; exit 1 }
    }
}

if (-not $UseCase) {
    $UseCase = "coding"
    $EnableThinking = $true
    $ThinkLevel = 2
    $Temp = 1.0
    $TopP = 0.95
    $Presence = 0.0
}

$chatKwargsLow = '{\"reasoning_effort\":\"low\"}'
$chatKwargsMedium = '{\"reasoning_effort\":\"medium\"}'
$chatKwargsXhigh = '{\"reasoning_effort\":\"xhigh\"}'

if (-not (Test-Path $MODEL)) {
    Write-Host ""
    Write-Host "Model not found: $MODEL" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Download with:" -ForegroundColor Yellow
    Write-Host "  .\download-qwen3.8-27b.ps1 ud4" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

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
    "--presence-penalty", "$Presence",
    "--repeat-penalty", "$Repeat",
    "--host", $ListenHost,
    "--port", "$Port"
)

if ($EnableVision -and (Test-Path $MMPROJ)) {
    $serverArgs += @("--mmproj", $MMPROJ)
}

if (-not $EnableThinking) {
    $serverArgs += @("--reasoning", "off")
} elseif ($ThinkLevel -eq 1) {
    $serverArgs += @("--reasoning", "on", "--chat-template-kwargs", $chatKwargsLow)
} elseif ($ThinkLevel -eq 2) {
    $serverArgs += @("--reasoning", "on", "--chat-template-kwargs", $chatKwargsMedium)
} elseif ($ThinkLevel -eq 3) {
    $serverArgs += @("--reasoning", "on", "--chat-template-kwargs", $chatKwargsXhigh)
}

$serverArgs += @("--reasoning-budget", "$ReasoningBudget")

if ($ReasoningPreserve) {
    $serverArgs += "--reasoning-preserve"
}

if ($Metrics) {
    $serverArgs += "--metrics"
}

if ($MTPEnabled) {
    $serverArgs += @("--spec-type", "draft-mtp", "--spec-draft-n-max", "$SpecNMax")
}

if ($params) {
    $serverArgs += $params.Split(' ')
}

$thinkStr = if ($EnableThinking) { "ON (level: $ThinkLevel, 0=off, 1=low, 2=medium, 3=xhigh)" } else { "OFF" }
$visionStr = if ($EnableVision -and (Test-Path $MMPROJ)) { "ON" } else { "OFF" }
$mtpStr = if ($MTPEnabled) { "ON (n_max=$SpecNMax)" } else { "OFF" }
$preserveStr = if ($ReasoningPreserve) { "ON" } else { "OFF" }
$metricsStr = if ($Metrics) { "ON" } else { "OFF" }

Write-Host ""
Write-Host "=== Qwen3.8-27B Runner ===" -ForegroundColor Cyan
Write-Host "use-case: $UseCase"
Write-Host "model:    $MODEL"
Write-Host "quant:    $Quant"
Write-Host "mmproj:   $(if ($EnableVision -and (Test-Path $MMPROJ)) { $MMPROJ } else { 'none' })"
Write-Host "port:     $Port"
Write-Host "temp:     $Temp  top_p: $TopP  top_k: $TopK"
Write-Host "think:    $thinkStr"
Write-Host "budget:   $ReasoningBudget tokens (0=skip, >N=max, -1=unlimited)"
Write-Host "preserve: $preserveStr"
Write-Host "metrics:  $metricsStr"
Write-Host "mtp:      $mtpStr"
Write-Host "vision:   $visionStr"
Write-Host "presence: $Presence  repeat: $Repeat"
Write-Host ""
Write-Host "Args: $($serverArgs -join ' ')"
Write-Host ""

& $LLAMA_SERVER @serverArgs
