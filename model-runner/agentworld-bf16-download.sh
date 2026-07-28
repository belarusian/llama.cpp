#!/bin/bash
# agentworld-bf16-download.sh — Download Qwen-AgentWorld-35B-A3B BF16 weights
# Total: ~69.3 GB, 21 shards + tokenizer files.
# Requires: hf CLI (huggingface_hub), logged in via `hf login`
#

set -eu

MODEL_DIR="${MODEL_DIR:-$HOME/models/agentworld-bf16}"

echo "Downloading Qwen-AgentWorld-35B-A3B BF16 (~69 GB)"
echo ""

# Download full model to HF cache (handles auth, resume, and integrity)
hf download Qwen/Qwen-AgentWorld-35B-A3B 2>&1

# Copy to target directory (HF uses symlinks to blobs, we hardlink instead)
mkdir -p "$MODEL_DIR"
HF_CACHE=$(python3 -c "from huggingface_hub import snapshot_download; print(snapshot_download('Qwen/Qwen-AgentWorld-35B-A3B'))")

echo ""
echo "Copying to $MODEL_DIR ..."
for f in "$HF_CACHE"/*; do
  bn=$(basename "$f")
  [ -e "$MODEL_DIR/$bn" ] && continue
  ln "$f" "$MODEL_DIR/$bn"
done

echo ""
echo "Done! Files:"
ls -lh "$MODEL_DIR/" | tail -5
TOTAL=$(du -sh "$MODEL_DIR" | cut -f1)
echo "Total size: $TOTAL"
