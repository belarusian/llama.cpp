#!/bin/bash
# agentworld-q8-download.sh — Download Qwen-AgentWorld-35B-A3B Q8_0 GGUF
# Single file, ~37 GB. Much more disk-efficient than BF16 (~69 GB).
#

set -eu

MODEL_DIR="${MODEL_DIR:-$HOME/models/agentworld-q8}"
mkdir -p "$MODEL_DIR"
cd "$MODEL_DIR"

echo "Downloading Qwen-AgentWorld-35B-A3B Q8_0 to $MODEL_DIR (~37 GB)"
echo ""

hf download unsloth/Qwen-AgentWorld-35B-A3B-GGUF \
  --include "Qwen-AgentWorld-35B-A3B-Q8_0.gguf" \
  "--local-dir=." 2>&1

# hf puts files in subdirectories; flatten it
find . -name "*.gguf" -depth +2 -exec bash -c 'mv "$0" ./' {} \; 2>/dev/null
rm -rf ./main ./BF16 ./UD_Q4_K_M UD-IQ4_NL IQ3_XXS Q3_K_S Q3_K_M Q2_K_XL UD-IQ2_XXS UD-Q4_K_M 2>/dev/null

echo ""
ls -lh *.gguf 2>/dev/null || echo "No GGUF found — check hf download output above"
TOTAL=$(du -sh . | cut -f1)
echo "Total size: $TOTAL"
