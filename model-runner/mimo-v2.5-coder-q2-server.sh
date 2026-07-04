#!/bin/bash
# mimo-v2.5-coder-q2-server.sh — MiMo V2.5 coder Q2 MoE runner (jedisct1 quant)
#
# Massive MoE model: 680B total params, ~37B active per token, 256 experts.
# Q2_K_S quant by jedisct1 with coding-focused importance matrix.
# ~114 GB weights (16 shards). Target machine: 128+ GB Apple Silicon.
#
# Native context: 1M tokens. Recommended: 32k-100k (KV cache eats fast at this scale).
#

set -eu

MODEL_DIR="${MODEL_DIR:-$HOME/models/mimo-v2.5-coder-q2}"
LLAMA_SERVER="${LLAMA_SERVER:-/Users/kodep/Code/llama.cpp/build/bin/llama-server}"
export GGML_METAL_TENSOR_ENABLE=1

# === Defaults ===
MODEL="${MODEL_DIR}/MiMo-V2.5-coder-Q2-00001-of-00016.gguf"
PORT="${PORT:-8084}"
HOST="${HOST:-0.0.0.0}"

TEMP=1.0
TOP_P=0.95
TOP_K=20
MIN_P=0.0
PRESENCE=0.0
CTX=150000
REASONING_BUDGET=-1
ENABLE_THINKING=0

GPU_LAYERS="${MIMO_GPU_LAYERS:-auto}"
CACHE_K="${MIMO_CACHE_K:-f16}"
CACHE_V="${MIMO_CACHE_V:-f16}"
CPU_MOE=0

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
        --gpu-layers/-n gl)    GPU_LAYERS="$2"; shift 2 ;;
        --cache-k)             CACHE_K="$2"; shift 2 ;;
        --cache-v)             CACHE_V="$2"; shift 2 ;;
        --cpu-moe)             CPU_MOE=1; shift ;;
        --thinking-precise)    TEMP=0.6; PRESENCE=0.0; ENABLE_THINKING=1; shift ;;
        --instruct)            ENABLE_THINKING=0; TEMP=0.7; TOP_P=0.8; shift ;;
        --reasoning)           ENABLE_THINKING=0; TEMP=1.0; TOP_P=0.95; shift ;;
        --)                    shift; CUSTOM_EXTRA="$*"; break ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

# === Build extra args ===
BASE="-m $MODEL --jinja -np 1 -c $CTX --ctx-size $CTX --top-k $TOP_K --top-p $TOP_P --min-p $MIN_P --temp $TEMP --presence-penalty $PRESENCE --host $HOST --port $PORT"
EXTRA="$BASE"

# MiMo2-specific flags
EXTRA+=" --flash-attn on"
EXTRA+=" --fit on"
EXTRA+=" --fit-target 4096"
EXTRA+=" --fit-ctx $CTX"
EXTRA+=" --gpu-layers $GPU_LAYERS"
EXTRA+=" --cache-type-k $CACHE_K"
EXTRA+=" --cache-type-v $CACHE_V"
EXTRA+=" --batch-size 512"
EXTRA+=" --ubatch-size 128"

# Configure thinking/reasoning
if [ "$ENABLE_THINKING" -eq 0 ]; then
    EXTRA+=" --reasoning off"
fi
EXTRA+=" --reasoning-budget $REASONING_BUDGET"

if [ "$CPU_MOE" -eq 1 ]; then
    EXTRA+=" --cpu-moe"
fi

# Apply custom flags (after --)
[ -n "${CUSTOM_EXTRA:-}" ] && EXTRA+=" $CUSTOM_EXTRA"

# === Print config ===
echo "=== MiMo V2.5-coder Q2 Runner ==="
echo "model:  $MODEL"
echo "port:   $PORT"
echo "temp:   $TEMP  top_p: $TOP_P"
echo "ctx:    $CTX"
echo "think:  $(if [ $ENABLE_THINKING -eq 1 ]; then echo ON; else echo OFF; fi)"
echo "budget: $REASONING_BUDGET tokens (0=skip, >N=max, -1=unlimited)"
echo "gpu-layers: $GPU_LAYERS"
echo "cpu-moe:    $CPU_MOE"
echo ""
echo "Config: $EXTRA"
echo ""

exec "$LLAMA_SERVER" $EXTRA