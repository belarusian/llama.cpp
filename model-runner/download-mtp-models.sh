#!/bin/bash
# download-mtp-models.sh — Download Qwen3.6 MTP models safely
# Run this script to download MTP models without affecting your current setup

set -euo pipefail

MODEL_DIR="${MODEL_DIR:-$HOME/models}"

echo "=== Downloading Qwen3.6 MTP Models ==="
echo ""

# 27B MTP (dense, ~55GB BF16)
if [ -f "$MODEL_DIR/Qwen3.6-27B-MTP-BF16/BF16/Qwen3.6-27B-BF16-00001-of-00002.gguf" ] && \
   [ -f "$MODEL_DIR/Qwen3.6-27B-MTP-BF16/BF16/Qwen3.6-27B-BF16-00002-of-00002.gguf" ]; then
    echo "✓ 27B MTP already downloaded"
else
    echo "Downloading Qwen3.6-27B-MTP (BF16, dense)..."
    mkdir -p "$MODEL_DIR/Qwen3.6-27B-MTP-BF16/BF16"
    hf download unsloth/Qwen3.6-27B-MTP-GGUF \
        --include "BF16/Qwen3.6-27B-BF16-00001-of-00002.gguf" \
        --local-dir "$MODEL_DIR/Qwen3.6-27B-MTP-BF16"
    hf download unsloth/Qwen3.6-27B-MTP-GGUF \
        --include "BF16/Qwen3.6-27B-BF16-00002-of-00002.gguf" \
        --local-dir "$MODEL_DIR/Qwen3.6-27B-MTP-BF16"
    echo "✓ 27B MTP downloaded"
fi
echo ""

# 35B-A3B MTP (MoE, ~71GB BF16)
if [ -f "$MODEL_DIR/Qwen3.6-35B-A3B-MTP-BF16/BF16/Qwen3.6-35B-A3B-BF16-00001-of-00002.gguf" ] && \
   [ -f "$MODEL_DIR/Qwen3.6-35B-A3B-MTP-BF16/BF16/Qwen3.6-35B-A3B-BF16-00002-of-00002.gguf" ]; then
    echo "✓ 35B-A3B MTP already downloaded"
else
    echo "Downloading Qwen3.6-35B-A3B-MTP (BF16, MoE)..."
    mkdir -p "$MODEL_DIR/Qwen3.6-35B-A3B-MTP-BF16/BF16"
    hf download unsloth/Qwen3.6-35B-A3B-MTP-GGUF \
        --include "BF16/Qwen3.6-35B-A3B-BF16-00001-of-00002.gguf" \
        --local-dir "$MODEL_DIR/Qwen3.6-35B-A3B-MTP-BF16"
    hf download unsloth/Qwen3.6-35B-A3B-MTP-GGUF \
        --include "BF16/Qwen3.6-35B-A3B-BF16-00002-of-00002.gguf" \
        --local-dir "$MODEL_DIR/Qwen3.6-35B-A3B-MTP-BF16"
    echo "✓ 35B-A3B MTP downloaded"
fi
echo ""

echo "=== Summary ==="
echo "Current (with vision): $MODEL_DIR/BF16/Qwen3.6-35B-A3B-BF16-*"
echo "27B MTP (dense, no vision): $MODEL_DIR/Qwen3.6-27B-MTP-BF16/BF16/Qwen3.6-27B-BF16-*"
echo "35B-A3B MTP (MoE, no vision): $MODEL_DIR/Qwen3.6-35B-A3B-MTP-BF16/BF16/Qwen3.6-35B-A3B-BF16-*"
echo ""
echo "Done!"
