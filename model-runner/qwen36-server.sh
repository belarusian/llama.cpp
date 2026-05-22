#!/bin/bash
# run-qwen36.sh — Simple Qwen3.6 runner with thinking/preserve-thinking controls
#
# Thinking modes (Qwen3.6 defaults to thinking ON):
#   --no-thinking        disable chain-of-thought reasoning
#   --thinking           re-enable thinking (default)
#   --preserve-thinking  preserve reasoning from previous turns
#   --no-preserve-thinking  don't preserve (default)
#
# Sampling controls:
#   --temp N    temperature (default: 1.0)
#   --top-p N   top-p sampling (default: 0.95)
#   --top-k N   top-k sampling (default: 20)
#
# Examples:
#   ./run-qwen36.sh                    # default: thinking ON, temp 1.0
#   ./run-qwen36.sh --no-thinking      # fast non-thinking
#   ./run-qwen36.sh --temp 0.6         # precise coding mode
#   ./run-qwen36.sh --port 8090        # custom port

set -eu

MODEL_DIR="${MODEL_DIR:-$HOME/models}"
LLAMA_SERVER="${LLAMA_SERVER:-/Users/kodep/Code/llama.cpp/build/bin/llama-server}"
export GGML_METAL_TENSOR_ENABLE=1

# === Defaults ===
PORT=8090
HOST=0.0.0.0
MODEL="${MODEL_DIR}/BF16/Qwen3.6-35B-A3B-BF16-00001-of-00002.gguf"
MMPROJ="${MODEL_DIR}/mmproj-qwen3.6-35b.gguf"

TEMP=1.0
TOP_P=0.95
TOP_K=20
MIN_P=0.0
PRESENCE=1.5
REP_PENALTY=1.0
CTX=262144
NGL=99

ENABLE_THINKING=1
PRESERVE_THINKING=0

# === Parse args ===
while [ $# -gt 0 ]; do
    case "$1" in
        --no-thinking)     ENABLE_THINKING=0; shift ;;
        --thinking|--think) ENABLE_THINKING=1; shift ;;
        --preserve-thinking|--preservethink) PRESERVE_THINKING=1; shift ;;
        --no-preserve-thinking) PRESERVE_THINKING=0; shift ;;
        --temp|-t)         TEMP="$2"; shift 2 ;;
        --top-p|-p)        TOP_P="$2"; shift 2 ;;
        --top-k|-k)        TOP_K="$2"; shift 2 ;;
        --min-p)           MIN_P="$2"; shift 2 ;;
        --presence-penalty) PRESENCE="$2"; shift 2 ;;
        --repetition-penalty) REP_PENALTY="$2"; shift 2 ;;
        --ctx-size|-c)     CTX="$2"; shift 2 ;;
        --ngl)             NGL="$2"; shift 2 ;;
        --port|-p)         PORT="$2"; shift 2 ;;
        --host)            HOST="$2"; shift 2 ;;
        --mmproj)          MMPROJ="$2"; shift 2 ;;
        --mmproj-path)     MMPROJ="$2"; shift 2 ;;
        --no-mmproj|--text-only) MMPROJ=""; shift ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

# === Build extra args ===
EXTRA="-m $MODEL --mmproj $MMPROJ --jinja -c $CTX --ctx-size $CTX --top-p $TOP_P --min-p $MIN_P --temp $TEMP --presence-penalty $PRESENCE --repetition-penalty $REP_PENALTY --ngl $NGL --host $HOST --port $PORT"

# === Qwen3.6 chat-template-kwargs for thinking ===
if [ "$ENABLE_THINKING" -eq 0 ]; then
    EXTRA+=" --chat-template-kwargs '{\"enable_thinking\":false}'"
elif [ "$PRESERVE_THINKING" -eq 1 ]; then
    EXTRA+=" --chat-template-kwargs '{\"enable_thinking\":true,\"preserve_thinking\":true}'"
fi

# === Print config ===
echo "=== Qwen3.6 Runner ==="
echo "model:  $MODEL"
echo "mmproj: ${MMPROJ:-none}"
echo "port:   $PORT"
echo "temp:   $TEMP  top_p: $TOP_P"
echo "think:  $(if [ $ENABLE_THINKING -eq 1 ]; then echo ON; else echo OFF; fi)"
echo "preserve: $(if [ $PRESERVE_THINKING -eq 1 ]; then echo ON; else echo OFF; fi)"
echo ""
echo "Config: $EXTRA"
echo ""

exec "$LLAMA_SERVER" $EXTRA