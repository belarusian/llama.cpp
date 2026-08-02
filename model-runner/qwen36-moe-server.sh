#!/bin/bash
# qwen36-moe-server.sh — Qwen3.6-35B-A3B MoE runner
#
# Simplified for 2 primary use cases:
#   --coding   : Thinking mode, precise coding tasks
#                temp=0.6, top_p=0.95, top_k=20, min_p=0.0, presence_penalty=0.0
#   --agentic  : Non-thinking mode (instruct), for tool-calling/agentic work
#                temp=0.7, top_p=0.8, top_k=20, min_p=0.0, presence_penalty=1.5
#
# MTP is enabled by default: --spec-type draft-mtp --spec-draft-n-max 2

set -eu

UNSLOTH_DIR="${UNSLOTH_DIR:-$HOME/models/unsloth/qwen3.6-35b-a3b-mtp-gguf}"
LLAMA_SERVER="${LLAMA_SERVER:-/Users/kodep/Code/llama.cpp/build/bin/llama-server}"
export GGML_METAL_TENSOR_ENABLE=1

# === Defaults ===
PORT=8080
HOST=0.0.0.0
QUANT="UD-Q8"
MTP_ENABLED=1
SPEC_N_MAX=2

USE_CASE="" # "coding" or "agentic"

case "$QUANT" in
    UD-Q8) MODEL="${UNSLOTH_DIR}/Qwen3.6-35B-A3B-UD-Q8_K_XL.gguf" ;;
    *)     echo "ERROR: Unknown quant '$QUANT'. Use UD-Q8." >&2; exit 1 ;;
esac

MMPROJ="$HOME/models/vision/mmproj-qwen3.6-35b.gguf"

TEMP=1.0
TOP_P=0.95
TOP_K=20
MIN_P=0.0
PRESENCE=1.5
CTX=262144
ENABLE_THINKING=1

# === Parse args ===
while [ $# -gt 0 ]; do
    case "$1" in
        --coding)
            USE_CASE="coding"
            ENABLE_THINKING=1
            TEMP=0.6
            TOP_P=0.95
            PRESENCE=0.0
            shift ;;
        --agentic)
            USE_CASE="agentic"
            ENABLE_THINKING=0
            TEMP=0.7
            TOP_P=0.8
            PRESENCE=1.5
            shift ;;
        --temp|-t)              TEMP="$2"; shift 2 ;;
        --top-p)                TOP_P="$2"; shift 2 ;;
        --top-k|-k)             TOP_K="$2"; shift 2 ;;
        --min-p)                MIN_P="$2"; shift 2 ;;
        --presence-penalty)     PRESENCE="$2"; shift 2 ;;
        --ctx-size|-c)          CTX="$2"; shift 2 ;;
        --port)                 PORT="$2"; shift 2 ;;
        --host)                 HOST="$2"; shift 2 ;;
        --mmproj-path)          MMPROJ="$2"; shift 2 ;;
        --no-mmproj|--text-only) MMPROJ=""; shift ;;
        --quant|-q)             QUANT="$2"
                                case "$QUANT" in
                                    UD-Q8) MODEL="${UNSLOTH_DIR}/Qwen3.6-35B-A3B-UD-Q8_K_XL.gguf" ;;
                                    *)     echo "ERROR: Unknown quant '$QUANT'. Use UD-Q8." >&2; exit 1 ;;
                                esac
                                shift 2 ;;
        --mtp|--enable-mtp)     MTP_ENABLED=1; shift ;;
        --no-mtp)               MTP_ENABLED=0; shift ;;
        --spec-n-max|-sn)       SPEC_N_MAX="$2"; shift 2 ;;
        --)                     shift; CUSTOM_EXTRA="$*"; break ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

# If no use case specified, default to --coding
if [ -z "$USE_CASE" ]; then
    USE_CASE="coding"
    ENABLE_THINKING=1
    TEMP=0.6
    TOP_P=0.95
    PRESENCE=0.0
fi

# === Build args ===
BASE="-m $MODEL --jinja -np 1 -fa on -ngl 99 -c $CTX --ctx-size $CTX --top-k $TOP_K --top-p $TOP_P --min-p $MIN_P --temp $TEMP --presence-penalty $PRESENCE --host $HOST --port $PORT"
EXTRA="$BASE"

[ -n "${MMPROJ}" ] && EXTRA+=" --mmproj $MMPROJ"

if [ "$ENABLE_THINKING" -eq 0 ]; then
    EXTRA+=" --reasoning off"
fi

if [ "$MTP_ENABLED" -eq 1 ]; then
    EXTRA+=" --spec-type draft-mtp --spec-draft-n-max $SPEC_N_MAX"
fi

[ -n "${CUSTOM_EXTRA:-}" ] && EXTRA+=" $CUSTOM_EXTRA"

# === Print config ===
echo "=== Qwen3.6-35B-A3B MoE Runner ==="
echo "use-case: $USE_CASE"
echo "model:    $MODEL"
echo "quant:    $QUANT"
echo "mmproj:   ${MMPROJ:-none}"
echo "port:     $PORT"
echo "temp:     $TEMP  top_p: $TOP_P  top_k: $TOP_K"
echo "think:    $(if [ $ENABLE_THINKING -eq 1 ]; then echo ON; else echo OFF; fi)"

if [ "$MTP_ENABLED" -eq 1 ]; then
    MTP_STR="ON (n_max=$SPEC_N_MAX)"
else
    MTP_STR="OFF"
fi
echo "mtp:      $MTP_STR"
echo "presence: $PRESENCE"
echo ""
[ ! -f "$MODEL" ] && echo "WARNING: Model file not found at $MODEL" >&2
echo "Config: $EXTRA"
echo ""

exec "$LLAMA_SERVER" $EXTRA
