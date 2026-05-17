#!/bin/bash
# run-qwen36.sh — Qwen3.6 model runner
#
# Qwen3.6 supports hybrid thinking modes with different settings:
#
#   THINKING MODE (enable_thinking: true) - Model generates reasoning before answering
#   INSTRUCT MODE (enable_thinking: false) - Direct answer without reasoning
#
# For each mode, you can optimize for different tasks:
#
#   Thinking Mode (default):
#     --thinking-precise  Coding tasks (temp=0.6, presence=0.0)
#     (default)           General tasks (temp=1.0, presence=1.5)
#
#   Instruct Mode (non-thinking):
#     --instruct          General tasks (temp=0.7, top_p=0.8)
#     --reasoning         Reasoning tasks (temp=1.0, top_p=0.95)
#
# Additional controls:
#   --no-thinking         Force non-thinking mode (same as --instruct)
#   --preserve-thinking   Keep reasoning context across conversation turns
#
# Performance:
#   --mtp                 Enable MTP speculative decoding (~1.5x faster)
#                         Note: MTP doesn't support vision (--mmproj)
#
# Sampling:
#   --temp N              Temperature (default: 1.0)
#   --top-p N             Top-p sampling (default: 0.95)
#   --top-k N             Top-k sampling (default: 20)
#   --min-p N             Min-p sampling (default: 0.0)
#
# Examples:
#   ./qwen36-server.sh                  # default: thinking mode, general tasks
#   ./qwen36-server.sh --thinking-precise  # thinking + coding settings
#   ./qwen36-server.sh --instruct       # non-thinking for general tasks
#   ./qwen36-server.sh --mtp --instruct  # MTP + non-thinking (fastest)

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
MTP=0

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
        --mtp)             MTP=1; shift ;;
        --thinking-precise) TEMP=0.6; PRESENCE=0.0; shift ;;
        --instruct)        ENABLE_THINKING=0; TEMP=0.7; TOP_P=0.8; shift ;;
        --reasoning)       ENABLE_THINKING=0; TEMP=1.0; TOP_P=0.95; shift ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

# === Build extra args ===
EXTRA="-m $MODEL --jinja -c $CTX --ctx-size $CTX --top-p $TOP_P --min-p $MIN_P --temp $TEMP --presence-penalty $PRESENCE --repetition-penalty $REP_PENALTY --ngl $NGL --host $HOST --port $PORT"
[ -n "${MMPROJ}" ] && [ "${MMPROJ}" != "" ] && EXTRA+=" --mmproj $MMPROJ"
[ "$MTP" -eq 1 ] && EXTRA+=" --spec-type draft-mtp --spec-draft-n-max 6"

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
echo "mtp:    $(if [ $MTP -eq 1 ]; then echo ON; else echo OFF; fi)"
echo ""
echo "Config: $EXTRA"
echo ""

exec "$LLAMA_SERVER" $EXTRA