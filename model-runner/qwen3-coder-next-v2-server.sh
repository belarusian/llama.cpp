#!/bin/bash
# qwen3-coder-next-v2-server.sh — Qwen3-Coder-Next MoE server runner v2
#
# EVOLUTION OF qwen3-coder-next-server.sh — added --agentic / --coding modes.
#
# ORIGINAL (qwen3-coder-next-server.sh) used these four modes:
#   --thinking          | ON  | temp=1.0, top_p=0.95, presence=1.5  — General chatty
#   --thinking-precise  | ON  | temp=0.6, top_p=0.95, presence=0.0   — Precise coding
#   --instruct          | OFF | temp=0.7, top_p=0.8                  — Direct answers
#   --reasoning         | OFF | temp=1.0, top_p=0.95                 — Reasoning tasks
#
# WHAT'S DIFFERENT IN V2:
#   1. Added --agentic mode: thinking OFF, higher presence penalty (1.5) for
#      diverse action selection, temp=0.7 for exploration in tool-calling space.
#      This mirrors the --agentic mode from qwen-agentworld-mtp-apex-server.sh.
#   2. Added --coding mode: alias for --thinking-precise (thinking ON, temp=0.6,
#      presence=0.0), matching the --coding mode from qwen-agentworld-mtp-apex-server.sh.
#   3. All original modes (--thinking, --thinking-precise, --instruct, --reasoning)
#      are preserved for backward compatibility.
#
# Qwen3-Coder-Next (80B MoE, ~3B active params) — optimized coder model.
# Two quantizations available (default: q4):
#   --quant q4   bartowski Q4_K_M  — ~49GB, single file, faster
#   --quant q8   original Q8_0     — ~76GB, 4 shards, higher quality
#
# 6 Modes:
#   --coding            | ON  | temp=0.6, top_p=0.95, presence=0.0   — Precise coding (thinking ON)
#   --agentic           | OFF | temp=0.7, top_p=0.8,  presence=1.5   — Tool-calling / world-model
#   --thinking          | ON  | temp=1.0, top_p=0.95, presence=1.5   — General chatty
#   --thinking-precise  | ON  | temp=0.6, top_p=0.95, presence=0.0   — Precise coding (same as --coding)
#   --instruct          | OFF | temp=0.7, top_p=0.8,  presence=0.0   — Direct answers (no thinking)
#   --reasoning         | OFF | temp=1.0, top_p=0.95, presence=0.0   — Reasoning tasks (direct output)
#
# Additional Controls:
# --quant q4|q8               Quantization (default: q4)
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

MODEL_DIR="${MODEL_DIR:-$HOME/models}"
LLAMA_SERVER="${LLAMA_SERVER:-/Users/kodep/Code/llama.cpp/build/bin/llama-server}"
export GGML_METAL_TENSOR_ENABLE=1

# Quantization (default: q4)
QUANT="q4"

# Model paths — resolved after arg parsing
MODEL=""

TEMP=1.0
TOP_P=0.95
TOP_K=20
MIN_P=0.0
PRESENCE=1.5
CTX=262103
REASONING_BUDGET=-1
ENABLE_THINKING=0
USE_CASE=""

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
        --quant|-q)            QUANT="$2"; shift 2 ;;
        --coding)              USE_CASE="coding"; ENABLE_THINKING=1; TEMP=0.6; TOP_P=0.95; PRESENCE=0.0; shift ;;
        --agentic)             USE_CASE="agentic"; ENABLE_THINKING=0; TEMP=0.7; TOP_P=0.8; PRESENCE=1.5; shift ;;
        --thinking-precise)    USE_CASE="coding"; ENABLE_THINKING=1; TEMP=0.6; PRESENCE=0.0; shift ;;
        --instruct)            USE_CASE="instruct"; ENABLE_THINKING=0; TEMP=0.7; TOP_P=0.8; PRESENCE=0.0; shift ;;
        --reasoning)           USE_CASE="reasoning"; ENABLE_THINKING=0; TEMP=1.0; TOP_P=0.95; PRESENCE=0.0; shift ;;
        --)                    shift; CUSTOM_EXTRA="$*"; break ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

# === Resolve model path ===
case "$QUANT" in
    q4) MODEL="${MODEL_DIR}/bartowski/qwen3-coder-next-q4/Qwen_Qwen3-Coder-Next-Q4_K_M/Qwen_Qwen3-Coder-Next-Q4_K_M.gguf" ;;
    q8) MODEL="${MODEL_DIR}/Qwen3-Coder-Next-Q8_0/Qwen3-Coder-Next-Q8_0/Qwen3-Coder-Next-Q8_0-00001-of-00004.gguf" ;;
    *)  echo "ERROR: Unknown quantization '$QUANT' (use q4 or q8)"; exit 1 ;;
esac

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
echo "=== Qwen3-Coder-Next MoE Runner v2 ==="
echo "use-case: ${USE_CASE:-default}"
echo "quant:    $QUANT"
echo "model:    $MODEL"
echo "port:     $PORT"
echo "temp:     $TEMP  top_p: $TOP_P  presence: $PRESENCE"
echo "think:    $(if [ $ENABLE_THINKING -eq 1 ]; then echo ON; else echo OFF; fi)"
echo "budget:   $REASONING_BUDGET tokens (0=skip, >N=max, -1=unlimited)"
echo ""
echo "Config: $EXTRA"
echo ""

exec "$LLAMA_SERVER" $EXTRA
