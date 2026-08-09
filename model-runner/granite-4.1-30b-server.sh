#!/bin/bash
# granite-4.1-30b-server.sh — IBM Granite 4.1 30B runner
#
# Text-only model, no multimodal, no MTP, no thinking mode.
#
# 2 Primary Use Cases:
#   --coding   : Precise coding tasks
#                temp=0.6, top_p=0.95, top_k=20, min_p=0.0, presence_penalty=0.0
#   --agentic  : Tool-calling / agentic work
#                temp=0.7, top_p=0.8, top_k=20, min_p=0.0, presence_penalty=1.5
#
# Quantizations:
#   Q4_K_M: ~17.5 GB  (default, good balance)
#   Q8_0:   ~30.7 GB  (near-lossless)
#   BF16:   ~57.7 GB  (full precision, 5 shards)

set -eu

MODEL_DIR="${MODEL_DIR:-$HOME/models/ibm-granite}"
LLAMA_SERVER="${LLAMA_SERVER:-/Users/kodep/Code/llama.cpp/build/bin/llama-server}"
export GGML_METAL_TENSOR_ENABLE=1

# === Defaults ===
PORT=8080
HOST=0.0.0.0
QUANT="Q8_0"

USE_CASE="" # "coding" or "agentic"

case "$QUANT" in
    Q4_K_M)   MODEL="${MODEL_DIR}/granite-4.1-30b-q4/granite-4.1-30b-Q4_K_M.gguf" ;;
    Q8_0)     MODEL="${MODEL_DIR}/granite-4.1-30b-q8/granite-4.1-30b-Q8_0.gguf" ;;
    BF16)     MODEL="${MODEL_DIR}/granite-4.1-30b-bf16/granite-4.1-30b-bf16-00001-of-00005.gguf" ;;
    *)        echo "ERROR: Unknown quant '$QUANT'. Use Q4_K_M, Q8_0, or BF16." >&2; exit 1 ;;
esac

TEMP=1.0
TOP_P=0.95
TOP_K=20
MIN_P=0.0
PRESENCE=0.0
CTX=131072

# === Parse args ===
while [ $# -gt 0 ]; do
    case "$1" in
        --coding)
            USE_CASE="coding"
            TEMP=0.6
            TOP_P=0.95
            PRESENCE=0.0
            shift ;;
        --agentic)
            USE_CASE="agentic"
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
        --quant|-q)             QUANT="$2"
                                case "$QUANT" in
                                    Q4_K_M)   MODEL="${MODEL_DIR}/granite-4.1-30b-q4/granite-4.1-30b-Q4_K_M.gguf" ;;
                                    Q8_0)     MODEL="${MODEL_DIR}/granite-4.1-30b-q8/granite-4.1-30b-Q8_0.gguf" ;;
                                    BF16)     MODEL="${MODEL_DIR}/granite-4.1-30b-bf16/granite-4.1-30b-bf16-00001-of-00005.gguf" ;;
                                    *)        echo "ERROR: Unknown quant '$QUANT'. Use Q4_K_M, Q8_0, or BF16." >&2; exit 1 ;;
                                esac
                                shift 2 ;;
        --)                     shift; CUSTOM_EXTRA="$*"; break ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

# If no use case specified, default to --coding
if [ -z "$USE_CASE" ]; then
    USE_CASE="coding"
    TEMP=0.6
    TOP_P=0.95
    PRESENCE=0.0
fi

# === Build args ===
BASE="-m $MODEL --jinja -np 1 -fa on -ngl 99 -c $CTX --ctx-size $CTX --top-k $TOP_K --top-p $TOP_P --min-p $MIN_P --temp $TEMP --presence-penalty $PRESENCE --host $HOST --port $PORT"
EXTRA="$BASE"

[ -n "${CUSTOM_EXTRA:-}" ] && EXTRA+=" $CUSTOM_EXTRA"

# === Print config ===
echo "=== Granite 4.1 30B Runner ==="
echo "use-case: $USE_CASE"
echo "model:    $MODEL"
echo "quant:    $QUANT"
echo "port:     $PORT"
echo "temp:     $TEMP  top_p: $TOP_P  top_k: $TOP_K"
echo "presence: $PRESENCE"
echo ""
[ ! -f "$MODEL" ] && echo "WARNING: Model file not found at $MODEL" >&2
echo "Config: $EXTRA"
echo ""

exec "$LLAMA_SERVER" $EXTRA
