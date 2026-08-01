#!/bin/bash
# Download Gemma 4 QAT variants from Unsloth or HuggingFace
# Usage: ./download-gemma4-qat.sh [e2b|e4b|12b|26b-a4b|31b]  (default: e4b)
set -eu

# MUST set this BEFORE any Python import
export HF_HUB_DISABLE_XET=1

python3 - "$@" <<'PYEOF'
# Import sys first, then set env var before anything else
import sys
import os
os.environ["HF_HUB_DISABLE_XET"] = "1"

# Now import huggingface_hub - must be after env var is set
from pathlib import Path
from huggingface_hub import hf_hub_download

# Double-check xet is disabled
from huggingface_hub.utils._runtime import is_xet_available
if is_xet_available():
    print("WARNING: xet is still available despite HF_HUB_DISABLE_XET=1", file=sys.stderr)
    print("This will likely cause downloads to stall. Continuing anyway...", file=sys.stderr)

quant = sys.argv[1].lower() if len(sys.argv) > 1 else "e4b"

configs = {
    "e2b":      {"repo": "unsloth/gemma-4-E2B-it-GGUF", "include": "*UD-Q4_K_XL*", "target": "gemma4-qat-e2b"},
    "e4b":      {"repo": "unsloth/gemma-4-E4B-it-qat-GGUF", "include": "*UD-Q4_K_XL*", "target": "gemma4-qat-e4b"},
    "12b":      {"repo": "unsloth/gemma-4-12B-it-qat-GGUF", "include": "*UD-Q4_K_XL*", "target": "gemma4-qat-12b"},
    "26b-a4b":  {"repo": "unsloth/gemma-4-26B-A4B-it-qat-GGUF", "include": "*UD-Q4_K_XL*", "target": "gemma4-qat-26b-a4b"},
    "31b":      {"repo": "unsloth/gemma-4-31B-it-qat-GGUF", "include": "*UD-Q4_K_XL*", "target": "gemma4-qat-31b"},
}

if quant not in configs:
    print(f"Usage: {sys.argv[0]} [e2b|e4b|12b|26b-a4b|31b]", file=sys.stderr)
    sys.exit(1)

cfg = configs[quant]
base = Path.home() / "models" / "gemma4-qat"
target = base / cfg["target"]

# Check already done - count actual GGUF files, not cache
current_gguf_count = len(list(target.glob("*.gguf")))
expected_count = 1  # single file case has 'file' key

if current_gguf_count == expected_count:
    print(f"[SKIP] Gemma 4 QAT {quant} already at {target}")
    sys.exit(0)

sizes = {"e2b": "~2 GB", "e4b": "~4 GB", "12b": "~12 GB", "26b-a4b": "~26 GB", "31b": "~31 GB"}
print(f"=== Downloading Gemma 4 QAT {quant} ({sizes[quant]}) ===")
print(f"Target: {target}")
target.mkdir(parents=True, exist_ok=True)

# Only clean if we have some GGUF files but not all (partial download)
if current_gguf_count > 0 and current_gguf_count < expected_count:
    cache_dir = target / ".cache"
    if cache_dir.exists():
        import shutil
        shutil.rmtree(cache_dir)
        print(f"Cleaned partial cache at {cache_dir} (will resume)")

print(f"\nDownloading from {cfg['repo']} with include pattern {cfg['include']}")
# Use huggingface-cli download for filtered downloads
import subprocess
result = subprocess.run([
    "huggingface-cli", "download", cfg["repo"],
    "--include", cfg["include"],
    "--local-dir", str(target)
], capture_output=True, text=True)

if result.returncode != 0:
    print(f"Error downloading model: {result.stderr}", file=sys.stderr)
    sys.exit(1)

# Clean up cache after successful download
cache_dir = target / ".cache"
if cache_dir.exists():
    import shutil
    shutil.rmtree(cache_dir)
    print(f"\nCleaned cache at {cache_dir}")

print("\nDone:")
for f in sorted(target.glob("*.gguf")):
    print(f"  {f.name} ({f.stat().st_size / 1e9:.1f} GB)")
PYEOF
