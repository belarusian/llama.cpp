#!/bin/bash
# agentworld-bf16-download.sh — Download Qwen-AgentWorld-35B-A3B BF16 weights
# Total: ~69.3 GB, 21 shards + tokenizer files.
#

set -eu

MODEL_DIR="${MODEL_DIR:-$HOME/models/agentworld-bf16}"
mkdir -p "$MODEL_DIR"
cd "$MODEL_DIR"

echo "Downloading Qwen-AgentWorld-35B-A3B BF16 to $MODEL_DIR (~69 GB)"
echo ""

BASE="https://huggingface.co/Qwen/Qwen-AgentWorld-35B-A3B/resolve/main"

# Download config files first (small, fast)
for f in \
  "config.json" \
  \
  "merges.txt" \
  "model.safetensors.index.json" \
  "preprocessor_config.json" \
  "tokenizer.json" \
  "tokenizer_config.json" \
  "vocab.json" \
  "video_preprocessor_config.json"; do
  echo "[config] $f"
  curl -sL -C - "$BASE/$f" -o "$f"
done

# Download model shards sequentially with resume support
for i in $(seq -w 1 21); do
  shard="model-${i}-of-00021.safetensors"
  echo "[$(printf '%02d' $((10#$i)))/21] $shard"
  curl -L -C - --progress-bar "$BASE/$shard" -o "$shard"
done

echo ""
echo "Done! Files:"
ls -lh "$MODEL_DIR/" | tail -5
echo ""
TOTAL=$(du -sh "$MODEL_DIR" | cut -f1)
echo "Total size: $TOTAL"
