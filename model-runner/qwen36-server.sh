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
#   --mtp                 Enable MTP speculative decoding (~1.5x faster)
#                         Note: MTP doesn't support vision (--mmproj)
#   --dense               Use Qwen3.6-27B (dense) instead of 35B-A3B (MoE)
#   --moe                 Use Qwen3.6-35B-A3B (MoE) - this is the default
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
PORT=8080
HOST=0.0.0.0
# Default to MOE (35B-A3B) non-MTP
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

ENABLE_THINKING=0
PRESERVE_THINKING=0
MTP=0
CUSTOM_EXTRA=""

# === Parse args ===
while [ $# -gt 0 ]; do
    case "$1" in
        --no-thinking)     ENABLE_THINKING=0; shift ;;
        --thinking|--think) ENABLE_THINKING=1; shift ;;
        --preserve-thinking|--preservethink) PRESERVE_THINKING=1; ENABLE_THINKING=1; shift ;;
        --no-preserve-thinking) PRESERVE_THINKING=0; shift ;;
        --temp|-t)         TEMP="$2"; shift 2 ;;
        --top-p|-p)        TOP_P="$2"; shift 2 ;;
        --top-k|-k)        TOP_K="$2"; shift 2 ;;
        --min-p)           MIN_P="$2"; shift 2 ;;
        --presence-penalty) PRESENCE="$2"; shift 2 ;;
        --ctx-size|-c)     CTX="$2"; shift 2 ;;
        --port|-p)         PORT="$2"; shift 2 ;;
        --host)            HOST="$2"; shift 2 ;;
        --mmproj-path)     MMPROJ="$2"; shift 2 ;;
        --no-mmproj|--text-only) MMPROJ=""; shift ;;
        --mtp)             MTP=1; MMPROJ=""; shift ;;
        --dense)           MODEL="${MODEL_DIR}/Qwen3.6-27B-MTP-BF16/BF16/Qwen3.6-27B-BF16-00001-of-00002.gguf"; shift ;;
        --moe)             MODEL="${MODEL_DIR}/BF16/Qwen3.6-35B-A3B-BF16-00001-of-00002.gguf"; shift ;;
        --thinking-precise) TEMP=0.6; PRESENCE=0.0; ENABLE_THINKING=1; shift ;;
        --instruct)        TEMP=0.7; TOP_P=0.8; shift ;;
        --reasoning)       TEMP=1.0; TOP_P=0.95; shift ;;
        --)                shift; CUSTOM_EXTRA="$*"; break ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

# === Select model ===
if [ "$MTP" -eq 1 ]; then
    if [[ "$MODEL" == *"Qwen3.6-27B-MTP-BF16"* ]]; then
        MODEL="${MODEL}"
    else
        MODEL="${MODEL_DIR}/Qwen3.6-35B-A3B-MTP-BF16/BF16/Qwen3.6-35B-A3B-BF16-00001-of-00002.gguf"
    fi
fi

# === Build extra args ===
BASE="-m $MODEL --jinja -np 1 -fa on -ngl 99 -c $CTX --ctx-size $CTX --top-k $TOP_K --top-p $TOP_P --min-p $MIN_P --temp $TEMP --presence-penalty $PRESENCE --host $HOST --port $PORT"
EXTRA="$BASE"
[ "$MTP" -eq 1 ] && EXTRA+=" --spec-type draft-mtp --spec-draft-n-max 6"
[ -n "${MMPROJ}" ] && EXTRA+=" --mmproj $MMPROJ"

# === Apply custom flags (after --) ===
[ -n "$CUSTOM_EXTRA" ] && EXTRA+=" $CUSTOM_EXTRA"

# === Print config ===
echo "=== Qwen3.6 Runner ==="
echo "model:  $MODEL"
echo "mmproj: ${MMPROJ:-none}"
echo "port:   $PORT"
echo "temp:   $TEMP  top_p: $TOP_P"
echo "think:  $(if [ $ENABLE_THINKING -eq 1 ]; then echo ON; else echo OFF; fi)"
echo "preserve: $(if [ $PRESERVE_THINKING -eq 1 ]; then echo ON; else echo OFF; fi)"
echo "mtp:    $(if [ $MTP -eq 1 ]; then echo ON; else echo OFF; fi)"
echo "type:   $(if [[ "$MODEL" == *"-27B-"* ]]; then echo "27B (dense)"; elif [[ "$MODEL" == *"-35B-A3B-"* ]]; then echo "35B-A3B (MoE)"; else echo "unknown"; fi)"
echo "vision: $(if [ -n "${MMPROJ}" ] && [ "${MMPROJ}" != "" ]; then echo ON; else echo OFF; fi)"
echo ""
echo "Config: $EXTRA"
echo ""

exec "$LLAMA_SERVER" $EXTRA