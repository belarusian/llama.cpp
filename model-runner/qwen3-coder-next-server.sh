#!/bin/bash
# qwen3-coder-next-server.sh — Qwen3-Coder-Next MoE server runner
#
# Qwen3-Coder-Next (80B MoE, ~3B active params) — optimized coder model.
# Runs on bartowski Q8_0 quant from ~/models/bartowski/qwen3-coder-next-q8/
#
# 4 Thinking Modes (configured via --reasoning on/off):
#   --thinking          | ON  | temp=1.0, top_p=0.95, presence=1.5  — General chatty
#   --thinking-precise  | ON  | temp=0.6, top_p=0.95, presence=0.0   — Precise coding
#   --instruct          | OFF | temp=0.7, top_p=0.8                  — Direct answers (no thinking)
#   --reasoning         | OFF | temp=1.0, top_p=0.95                 — Reasoning tasks (direct output)
#
# Additional Controls:
# --reasoning-budget N        Cap max tokens for thinking
#   (0 = skip thinking, >N = cap at N, -1 = unlimited)
# --thinking|--think          Enable thinking mode (default when not in instruct/reasoning mode)
# --no-thinking               Force non-thinking / instruct mode (same as --instruct)
#
# Sampling:
#   --temp N              Temperature (default: 1.0)
#   --top-p N             Top-p sampling (default: 0.95)
#   --top-k N             Top-k sampling (default: 20)
#   --min-p N             Min-p sampling (default: 0.0)

set -eu

MODEL_DIR="${MODEL_DIR:-$HOME/models/bartowski}"
LLAMA_SERVER="${LLAMA_SERVER:-/Users/kodep/Code/llama.cpp/build/bin/llama-server}"
export GGML_METAL_TENSOR_ENABLE=1

# Model path — sharded Q8_0 (3 files, first shard referenced)
MODEL="${MODEL_DIR}/qwen3-coder-next-q8/Qwen_Qwen3-Coder-Next-Q8_0/Qwen_Qwen3-Coder-Next-Q8_0-00001-of-00003.gguf"

TEMP=1.0
TOP_P=0.95
TOP_K=20
MIN_P=0.0
PRESENCE=1.5
CTX=262144
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
PORT="${PORT:-8082}"
HOST="${HOST:-0.0.0.0}"

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
echo "=== Qwen3-Coder-Next MoE Runner ==="
echo "model:  $MODEL"
echo "port:   $PORT"
echo "temp:   $TEMP  top_p: $TOP_P"
echo "think:  $(if [ $ENABLE_THINKING -eq 1 ]; then echo ON; else echo OFF; fi)"
echo "budget: $REASONING_BUDGET tokens (0=skip, >N=max, -1=unlimited)"
echo ""
echo "Config: $EXTRA"
echo ""

exec "$LLAMA_SERVER" $EXTRA
