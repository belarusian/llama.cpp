#!/bin/bash
# agentworld-bf16-server.sh — Qwen-AgentWorld-35B-A3B BF16 runner (official weights)
#
# Full BF16 precision: 35B params, ~69 GB weights. No quantization loss.
# Best coding quality of any AgentWorld variant.
#

set -eu

MODEL_DIR="${MODEL_DIR:-$HOME/models/agentworld-bf16}"
LLAMA_SERVER="${LLAMA_SERVER:-/Users/kodep/Code/llama.cpp/build/bin/llama-server}"
export GGML_METAL_TENSOR_ENABLE=1

# === Defaults ===
MODEL="${MODEL_DIR}/Qwen-AgentWorld-35B-A3B-BF16-00001-of-00002.gguf"
PORT="${PORT:-8086}"
HOST="${HOST:-0.0.0.0}"

TEMP=0.6
TOP_P=0.95
TOP_K=20
MIN_P=0.0
PRESENCE=0.0
CTX=262144
REASONING_BUDGET=-1
ENABLE_THINKING=1

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
        --presence-penalty)    PRESENCE="$2"; shift 2 ;;
        --ctx-size|-c)         CTX="$2"; shift 2 ;;
        --port)                PORT="$2"; shift 2 ;;
        --host)                HOST="$2"; shift 2 ;;
        --thinking-precise)    TEMP=0.6; PRESENCE=0.0; ENABLE_THINKING=1; shift ;;
        --instruct)            ENABLE_THINKING=0; TEMP=0.7; TOP_P=0.8; shift ;;
        --reasoning)           ENABLE_THINKING=0; TEMP=1.0; TOP_P=0.95; shift ;;
        --)                    shift; CUSTOM_EXTRA="$*"; break ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

# === Build extra args ===
BASE="-m $MODEL --jinja -np 1 -fa on -ngl 99 -c $CTX --ctx-size $CTX --top-k $TOP_K --top-p $TOP_P --min-p $MIN_P --temp $TEMP --presence-penalty $PRESENCE --host $HOST --port $PORT"
EXTRA="$BASE"

# Configure thinking/reasoning via llama-server native flag
if [ "$ENABLE_THINKING" -eq 0 ]; then
    EXTRA+=" --reasoning off"
fi
EXTRA+=" --reasoning-budget $REASONING_BUDGET"

# Apply custom flags (after --)
[ -n "${CUSTOM_EXTRA:-}" ] && EXTRA+=" $CUSTOM_EXTRA"

# === Print config ===
echo "=== Qwen-AgentWorld-35B-A3B BF16 Runner ==="
echo "model:  $MODEL"
echo "port:   $PORT"
echo "temp:   $TEMP  top_p: $TOP_P"
echo "ctx:    $CTX"
echo "think:  $(if [ $ENABLE_THINKING -eq 1 ]; then echo ON; else echo OFF; fi)"
echo "budget: $REASONING_BUDGET tokens (0=skip, >N=max, -1=unlimited)"
echo ""
echo "Config: $EXTRA"
echo ""

exec "$LLAMA_SERVER" $EXTRA
