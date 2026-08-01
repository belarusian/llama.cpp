#!/bin/bash
# gemma4-qat-server.sh — Gemma 4 QAT model runner
#
# Gemma 4 QAT 31B model from Unsloth.
# This is a Quantization-Aware Training model optimized for local execution.
#
# Model:
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
#   --no-mmproj|--text-only       Disable vision entirely
#   --mmproj-path PATH            Custom mmproj path

set -eu

MODEL_DIR="${MODEL_DIR:-$HOME/models/gemma4-qat}"
LLAMA_SERVER="${LLAMA_SERVER:-/Users/kodep/Code/llama.cpp/build/bin/llama-server}"
export GGML_METAL_TENSOR_ENABLE=1
export LLAMA_CACHE="unsloth"

# Model for 31b variant
MODEL="unsloth/gemma-4-31B-it-qat-GGUF:UD-Q4_K_XL"

TEMP=1.0
TOP_P=0.95
TOP_K=64
MIN_P=0.0
CTX=8192
REASONING_BUDGET=-1
ENABLE_THINKING=0

# === Parse args ===
while [ $# -gt 0 ]; do
    case "$1" in
        --no-thinking)          ENABLE_THINKING=0; shift ;;
        --thinking|--think)     ENABLE_THINKING=1; shift ;;
        --reasoning-budget|-rb) REASONING_BUDGET="$2"; shift 2 ;;
        --temp|-t)             TEMP="$2"; shift 2 ;;
        --top-p|-p)            TOP_P="$2"; shift 2 ;;
        --top-k|-k)            TOP_K="$2"; shift 2 ;;
        --min-p)               MIN_P="$2"; shift 2 ;;
        --ctx-size|-c)         CTX="$2"; shift 2 ;;
        --port|-p)             PORT="$2"; shift 2 ;;
        --host)                HOST="$2"; shift 2 ;;
        --no-mmproj|--text-only) MMPROJ=""; shift ;;
        --mmproj-path)         MMPROJ="$2"; shift 2 ;;
        --)                    shift; CUSTOM_EXTRA="$*"; break ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

# === Build extra args ===
PORT="${PORT:-8082}"
HOST="${HOST:-0.0.0.0}"

BASE="-m $MODEL --jinja -np 1 -fa on -ngl 99 -c $CTX --ctx-size $CTX --top-k $TOP_K --top-p $TOP_P --min-p $MIN_P --temp $TEMP --host $HOST --port $PORT"
EXTRA="$BASE"

# Configure thinking/reasoning via llama-server native flag
if [ "$ENABLE_THINKING" -eq 0 ]; then
    EXTRA+=" --reasoning off"
fi
EXTRA+=" --reasoning-budget $REASONING_BUDGET"

# Apply custom flags (after --)
[ -n "${CUSTOM_EXTRA:-}" ] && EXTRA+=" $CUSTOM_EXTRA"

# === Print config ===
echo "=== Gemma 4 QAT Runner ==="
echo "model:  $MODEL"
echo "port:   $PORT"
echo "temp:   $TEMP  top_p: $TOP_P  top_k: $TOP_K"
echo "think:  $(if [ $ENABLE_THINKING -eq 1 ]; then echo ON; else echo OFF; fi)"
echo "budget: $REASONING_BUDGET tokens (0=skip, >N=max, -1=unlimited)"
echo ""
echo "Config: $EXTRA"
echo ""

exec "$LLAMA_SERVER" $EXTRA