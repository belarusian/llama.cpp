#!/bin/bash
# deepseek-v4-flash-server.sh — DeepSeek-V4-Flash-0731 runner
#
# 284B total, 13B activated (MoE), UD-IQ3_XXS quant (~97GB)
#
# Use cases:
#   --coding   : Think High mode, coding tasks
#                temp=1.0, top_p=0.95
#   --agentic  : Think High mode, agentic/tool-calling
#                temp=1.0, top_p=0.95
#   --nonthink : Fast, no reasoning
#                temp=1.0, top_p=1.0
#   --max      : Think Max mode (needs large ctx)
#                temp=1.0, top_p=1.0, ctx=393216

set -eu

DSV4_DIR="${DSV4_DIR:-$HOME/models/unsloth/deepseek-v4-flash-0731-gguf}"
LLAMA_SERVER="${LLAMA_SERVER:-/Users/kodep/Code/llama.cpp/build/bin/llama-server}"
export GGML_METAL_TENSOR_ENABLE=1

# === Defaults ===
PORT=8080
HOST=0.0.0.0
QUANT="UD-IQ3_XXS"
CTX=131072

TEMP=1.0
TOP_P=1.0
TOP_K=40
MIN_P=0.0
ENABLE_THINKING=1
REASONING_EFFORT=""

MODEL="${DSV4_DIR}/UD-IQ3_XXS/DeepSeek-V4-Flash-0731-UD-IQ3_XXS-00001-of-00004.gguf"

# === Parse args ===
while [ $# -gt 0 ]; do
    case "$1" in
        --coding)
            REASONING_EFFORT="high"
            ENABLE_THINKING=1
            TOP_P=0.95
            shift ;;
        --agentic)
            REASONING_EFFORT="high"
            ENABLE_THINKING=1
            TOP_P=0.95
            shift ;;
        --nonthink)
            REASONING_EFFORT=""
            ENABLE_THINKING=0
            TOP_P=1.0
            shift ;;
        --max)
            REASONING_EFFORT="max"
            ENABLE_THINKING=1
            CTX=393216
            shift ;;
        --temp|-t)              TEMP="$2"; shift 2 ;;
        --top-p)                TOP_P="$2"; shift 2 ;;
        --top-k|-k)             TOP_K="$2"; shift 2 ;;
        --min-p)                MIN_P="$2"; shift 2 ;;
        --ctx-size|-c)          CTX="$2"; shift 2 ;;
        --port)                 PORT="$2"; shift 2 ;;
        --host)                 HOST="$2"; shift 2 ;;
        --quant|-q)             QUANT="$2"
                                MODEL="${DSV4_DIR}/$QUANT/DeepSeek-V4-Flash-0731-$QUANT-00001-of-*.gguf"
                                shift 2 ;;
        --)                     shift; CUSTOM_EXTRA="$*"; break ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

# Default to --coding if no mode specified
if [ -z "$REASONING_EFFORT" ] && [ "$ENABLE_THINKING" -eq 1 ]; then
    REASONING_EFFORT="high"
    TOP_P=0.95
fi

# === Build args ===
BASE="-m $MODEL --jinja -np 1 -fa on -ngl 99 -c $CTX --ctx-size $CTX --top-k $TOP_K --top-p $TOP_P --min-p $MIN_P --temp $TEMP --host $HOST --port $PORT"
EXTRA="$BASE"

if [ "$ENABLE_THINKING" -eq 0 ]; then
    EXTRA+=" --reasoning off"
fi

[ -n "${CUSTOM_EXTRA:-}" ] && EXTRA+=" $CUSTOM_EXTRA"

# === Print config ===
echo "=== DeepSeek-V4-Flash-0731 Runner ==="
echo "model:  $MODEL"
echo "quant:  $QUANT (~97GB)"
echo "port:   $PORT"
echo "ctx:    $CTX"
echo "temp:   $TEMP  top_p: $TOP_P  top_k: $TOP_K"
echo "think:  $(if [ $ENABLE_THINKING -eq 1 ]; then echo "ON ($REASONING_EFFORT)"; else echo OFF; fi)"
echo ""
[ ! -f "$MODEL" ] && echo "WARNING: Model file not found at $MODEL" >&2
echo "Config: $EXTRA"
echo ""

exec "$LLAMA_SERVER" $EXTRA
