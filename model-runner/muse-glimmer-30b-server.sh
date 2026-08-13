#!/bin/bash
# Muse-Glimmer-30B server runner
#
# Meta's 30B dense vision model, Unsloth dynamic quants.
# Vision (mmproj) enabled by default, disable with --no-mmproj.
# Thinking mode enabled by default.
#
# Use Cases:
#   --coding   : Thinking mode, precise coding tasks
#                temp=0.6, top_p=0.95, top_k=64, min_p=0.0, presence_penalty=0.0
#   --agentic  : Non-thinking mode (instruct), tool-calling/agentic work
#                temp=0.7, top_p=0.8, top_k=64, min_p=0.0, presence_penalty=1.5

set -eu

MODEL_DIR="${MODEL_DIR:-$HOME/models/unsloth}"
LLAMA_SERVER="${LLAMA_SERVER:-/Users/kodep/Code/llama.cpp/build/bin/llama-server}"
export GGML_METAL_TENSOR_ENABLE=1

# === Defaults ===
PORT=8080
HOST=0.0.0.0
QUANT="Q8_0"

USE_CASE="" # "coding" or "agentic"

case "$QUANT" in
    Q8_0)           MODEL="${MODEL_DIR}/Muse-Glimmer-30B-GGUF/Muse-Glimmer-30B-Q8_0.gguf" ;;
    UD-Q8_K_XL)     MODEL="${MODEL_DIR}/Muse-Glimmer-30B-GGUF/Muse-Glimmer-30B-UD-Q8_K_XL.gguf" ;;
    UD-Q6_K_XL)     MODEL="${MODEL_DIR}/Muse-Glimmer-30B-GGUF/Muse-Glimmer-30B-UD-Q6_K_XL.gguf" ;;
    UD-Q5_K_XL)     MODEL="${MODEL_DIR}/Muse-Glimmer-30B-GGUF/Muse-Glimmer-30B-UD-Q5_K_XL.gguf" ;;
    UD-Q4_K_XL)     MODEL="${MODEL_DIR}/Muse-Glimmer-30B-GGUF/Muse-Glimmer-30B-UD-Q4_K_XL.gguf" ;;
    UD-Q3_K_XL)     MODEL="${MODEL_DIR}/Muse-Glimmer-30B-GGUF/Muse-Glimmer-30B-UD-Q3_K_XL.gguf" ;;
    UD-Q2_K_XL)     MODEL="${MODEL_DIR}/Muse-Glimmer-30B-GGUF/Muse-Glimmer-30B-UD-Q2_K_XL.gguf" ;;
    BF16)           MODEL="${MODEL_DIR}/Muse-Glimmer-30B-GGUF/BF16/Muse-Glimmer-30B-BF16-00001-of-00002.gguf" ;;
    *)              echo "ERROR: Unknown quant '$QUANT'. Use Q8_0, UD-Q4_K_XL, UD-Q8_K_XL, BF16, etc." >&2; exit 1 ;;
esac

case "$QUANT" in
    Q8_0)     MMPROJ="${MODEL_DIR}/Muse-Glimmer-30B-GGUF/mmproj-Muse-Glimmer-30B-Q8_0.gguf" ;;
    *)        MMPROJ="${MODEL_DIR}/Muse-Glimmer-30B-GGUF/mmproj-Muse-Glimmer-30B-BF16.gguf" ;;
esac

TEMP=1.0
TOP_P=0.95
TOP_K=64
MIN_P=0.0
PRESENCE=0.0
CTX=131072
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
                                    Q8_0)           MODEL="${MODEL_DIR}/Muse-Glimmer-30B-GGUF/Muse-Glimmer-30B-Q8_0.gguf" ;;
                                    UD-Q8_K_XL)     MODEL="${MODEL_DIR}/Muse-Glimmer-30B-GGUF/Muse-Glimmer-30B-UD-Q8_K_XL.gguf" ;;
                                    UD-Q6_K_XL)     MODEL="${MODEL_DIR}/Muse-Glimmer-30B-GGUF/Muse-Glimmer-30B-UD-Q6_K_XL.gguf" ;;
                                    UD-Q5_K_XL)     MODEL="${MODEL_DIR}/Muse-Glimmer-30B-GGUF/Muse-Glimmer-30B-UD-Q5_K_XL.gguf" ;;
                                    UD-Q4_K_XL)     MODEL="${MODEL_DIR}/Muse-Glimmer-30B-GGUF/Muse-Glimmer-30B-UD-Q4_K_XL.gguf" ;;
                                    UD-Q3_K_XL)     MODEL="${MODEL_DIR}/Muse-Glimmer-30B-GGUF/Muse-Glimmer-30B-UD-Q3_K_XL.gguf" ;;
                                    UD-Q2_K_XL)     MODEL="${MODEL_DIR}/Muse-Glimmer-30B-GGUF/Muse-Glimmer-30B-UD-Q2_K_XL.gguf" ;;
                                    BF16)           MODEL="${MODEL_DIR}/Muse-Glimmer-30B-GGUF/BF16/Muse-Glimmer-30B-BF16-00001-of-00002.gguf" ;;
                                    *)              echo "ERROR: Unknown quant '$QUANT'. Use Q8_0, UD-Q4_K_XL, UD-Q8_K_XL, BF16, etc." >&2; exit 1 ;;
                                esac
                                case "$QUANT" in
                                    Q8_0)     MMPROJ="${MODEL_DIR}/Muse-Glimmer-30B-GGUF/mmproj-Muse-Glimmer-30B-Q8_0.gguf" ;;
                                    *)        MMPROJ="${MODEL_DIR}/Muse-Glimmer-30B-GGUF/mmproj-Muse-Glimmer-30B-BF16.gguf" ;;
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

[ -n "${CUSTOM_EXTRA:-}" ] && EXTRA+=" $CUSTOM_EXTRA"

# === Print config ===
echo "=== Muse-Glimmer-30B Runner ==="
echo "use-case: $USE_CASE"
echo "model:    $MODEL"
echo "quant:    $QUANT"
echo "mmproj:   ${MMPROJ:-none}"
echo "port:     $PORT"
echo "temp:     $TEMP  top_p: $TOP_P  top_k: $TOP_K"
echo "think:    $(if [ $ENABLE_THINKING -eq 1 ]; then echo ON; else echo OFF; fi)"

if [ -n "${MMPROJ}" ] && [ "${MMPROJ}" != "" ]; then
    VISION_STR="ON"
else
    VISION_STR="OFF"
fi
echo "vision:   $VISION_STR"
echo "presence: $PRESENCE"
echo ""
[ ! -f "$MODEL" ] && echo "WARNING: Model file not found at $MODEL" >&2
echo "Config: $EXTRA"
echo ""

exec "$LLAMA_SERVER" $EXTRA
