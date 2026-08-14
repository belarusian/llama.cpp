#!/bin/bash
# qwen38-27b-server.sh — Qwen3.8-27B server runner
#
# Alibaba's 27B dense model, Unsloth dynamic quants.
# Vision (mmproj) enabled by default, disable with --no-mmproj.
# Thinking mode enabled by default.
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

set -eu

MODEL_DIR="${MODEL_DIR:-$HOME/models/unsloth}"
LLAMA_SERVER="${LLAMA_SERVER:-/Users/kodep/Code/llama.cpp/build/bin/llama-server}"
export GGML_METAL_TENSOR_ENABLE=1

# === Defaults ===
PORT=8080
HOST=0.0.0.0
QUANT="UD-Q8_K_XL"

USE_CASE="" # "coding" or "agentic"

# Model paths resolved from QUANT
case "$QUANT" in
    UD-Q8_K_XL)   MODEL="${MODEL_DIR}/Qwen3.8-27B-GGUF/Qwen3.8-27B-UD-Q8_K_XL.gguf" ;;
    UD-Q6_K_XL)   MODEL="${MODEL_DIR}/Qwen3.8-27B-GGUF/Qwen3.8-27B-UD-Q6_K_XL.gguf" ;;
    UD-Q5_K_XL)   MODEL="${MODEL_DIR}/Qwen3.8-27B-GGUF/Qwen3.8-27B-UD-Q5_K_XL.gguf" ;;
    UD-Q4_K_XL)   MODEL="${MODEL_DIR}/Qwen3.8-27B-GGUF/Qwen3.8-27B-UD-Q4_K_XL.gguf" ;;
    UD-Q3_K_XL)   MODEL="${MODEL_DIR}/Qwen3.8-27B-GGUF/Qwen3.8-27B-UD-Q3_K_XL.gguf" ;;
    UD-Q2_K_XL)   MODEL="${MODEL_DIR}/Qwen3.8-27B-GGUF/Qwen3.8-27B-UD-Q2_K_XL.gguf" ;;
    Q8_0)         MODEL="${MODEL_DIR}/Qwen3.8-27B-GGUF/Qwen3.8-27B-Q8_0.gguf" ;;
    Q4_K_M)       MODEL="${MODEL_DIR}/Qwen3.8-27B-GGUF/Qwen3.8-27B-Q4_K_M.gguf" ;;
    BF16)         MODEL="${MODEL_DIR}/Qwen3.8-27B-GGUF/BF16/Qwen3.8-27B-BF16-00001-of-00002.gguf" ;;
    *)            echo "ERROR: Unknown quant '$QUANT'. Use UD-Q8_K_XL, Q8_0, Q4_K_M, BF16, etc." >&2; exit 1 ;;
esac

MMPROJ="${MODEL_DIR}/Qwen3.8-27B-GGUF/mmproj-F16.gguf"

TEMP=1.0
TOP_P=0.95
TOP_K=20
MIN_P=0.0
PRESENCE=0.0
REPEAT=1.0
CTX=262144
ENABLE_THINKING=1
REASONING_BUDGET=-1

# === Parse args ===
while [ $# -gt 0 ]; do
    case "$1" in
        --coding)
            USE_CASE="coding"
            ENABLE_THINKING=1
            TEMP=1.0
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
        --no-thinking)          ENABLE_THINKING=0; shift ;;
        --thinking|--think)     ENABLE_THINKING=1; shift ;;
        --reasoning-budget|-rb) REASONING_BUDGET="$2"; shift 2 ;;
        --temp|-t)              TEMP="$2"; shift 2 ;;
        --top-p)                TOP_P="$2"; shift 2 ;;
        --top-k|-k)             TOP_K="$2"; shift 2 ;;
        --min-p)                MIN_P="$2"; shift 2 ;;
        --presence-penalty)     PRESENCE="$2"; shift 2 ;;
        --repeat-penalty)       REPEAT="$2"; shift 2 ;;
        --ctx-size|-c)          CTX="$2"; shift 2 ;;
        --port)                 PORT="$2"; shift 2 ;;
        --host)                 HOST="$2"; shift 2 ;;
        --mmproj-path)          MMPROJ="$2"; shift 2 ;;
        --no-mmproj|--text-only) MMPROJ=""; shift ;;
        --quant|-q)             QUANT="$2"
                                case "$QUANT" in
                                    UD-Q8_K_XL)   MODEL="${MODEL_DIR}/Qwen3.8-27B-GGUF/Qwen3.8-27B-UD-Q8_K_XL.gguf" ;;
                                    UD-Q6_K_XL)   MODEL="${MODEL_DIR}/Qwen3.8-27B-GGUF/Qwen3.8-27B-UD-Q6_K_XL.gguf" ;;
                                    UD-Q5_K_XL)   MODEL="${MODEL_DIR}/Qwen3.8-27B-GGUF/Qwen3.8-27B-UD-Q5_K_XL.gguf" ;;
                                    UD-Q4_K_XL)   MODEL="${MODEL_DIR}/Qwen3.8-27B-GGUF/Qwen3.8-27B-UD-Q4_K_XL.gguf" ;;
                                    UD-Q3_K_XL)   MODEL="${MODEL_DIR}/Qwen3.8-27B-GGUF/Qwen3.8-27B-UD-Q3_K_XL.gguf" ;;
                                    UD-Q2_K_XL)   MODEL="${MODEL_DIR}/Qwen3.8-27B-GGUF/Qwen3.8-27B-UD-Q2_K_XL.gguf" ;;
                                    Q8_0)         MODEL="${MODEL_DIR}/Qwen3.8-27B-GGUF/Qwen3.8-27B-Q8_0.gguf" ;;
                                    Q4_K_M)       MODEL="${MODEL_DIR}/Qwen3.8-27B-GGUF/Qwen3.8-27B-Q4_K_M.gguf" ;;
                                    BF16)         MODEL="${MODEL_DIR}/Qwen3.8-27B-GGUF/BF16/Qwen3.8-27B-BF16-00001-of-00002.gguf" ;;
                                    *)            echo "ERROR: Unknown quant '$QUANT'" >&2; exit 1 ;;
                                esac
                                shift 2 ;;
        --)                     shift; CUSTOM_EXTRA="$*"; break ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

# If no use case specified, default to --coding
if [ -z "$USE_CASE" ]; then
    USE_CASE="coding"
    ENABLE_THINKING=1
    TEMP=1.0
    TOP_P=0.95
    PRESENCE=0.0
fi

# === Build args ===
BASE="-m $MODEL --jinja -np 1 -fa on -ngl 99 -c $CTX --ctx-size $CTX --top-k $TOP_K --top-p $TOP_P --min-p $MIN_P --temp $TEMP --presence-penalty $PRESENCE --repeat-penalty $REPEAT --host $HOST --port $PORT"
EXTRA="$BASE"

[ -n "${MMPROJ}" ] && EXTRA+=" --mmproj $MMPROJ"

if [ "$ENABLE_THINKING" -eq 0 ]; then
    EXTRA+=" --reasoning off"
fi

EXTRA+=" --reasoning-budget $REASONING_BUDGET"

[ -n "${CUSTOM_EXTRA:-}" ] && EXTRA+=" $CUSTOM_EXTRA"

# === Print config ===
echo "=== Qwen3.8-27B Runner ==="
echo "use-case: $USE_CASE"
echo "model:    $MODEL"
echo "quant:    $QUANT"
echo "mmproj:   ${MMPROJ:-none}"
echo "port:     $PORT"
echo "temp:     $TEMP  top_p: $TOP_P  top_k: $TOP_K"
echo "think:    $(if [ $ENABLE_THINKING -eq 1 ]; then echo ON; else echo OFF; fi)"
echo "budget:   $REASONING_BUDGET tokens (0=skip, >N=max, -1=unlimited)"

if [ -n "${MMPROJ}" ] && [ "${MMPROJ}" != "" ]; then
    VISION_STR="ON"
else
    VISION_STR="OFF"
fi
echo "vision:   $VISION_STR"
echo "presence: $PRESENCE  repeat: $REPEAT"
echo ""
[ ! -f "$MODEL" ] && echo "WARNING: Model file not found at $MODEL" >&2
echo "Config: $EXTRA"
echo ""

exec "$LLAMA_SERVER" $EXTRA
