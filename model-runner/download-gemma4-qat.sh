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
repo = "unsloth/gemma-4-qat"
base = Path.home() / "models" / "gemma4-qat"

configs = {
    "e2b":      {"target": "gemma4-qat-e2b",     "file": "gemma-4-qat-e2b.gguf"},
    "e4b":      {"target": "gemma4-qat-e4b",     "file": "gemma-4-qat-e4b.gguf"},
    "12b":      {"target": "gemma4-qat-12b",     "file": "gemma-4-qat-12b.gguf"},
    "26b-a4b":  {"target": "gemma4-qat-26b-a4b", "file": "gemma-4-qat-26b-a4b.gguf"},
    "31b":      {"target": "gemma4-qat-31b",     "file": "gemma-4-qat-31b.gguf"},
}

if quant not in configs:
    print(f"Usage: {sys.argv[0]} [e2b|e4b|12b|26b-a4b|31b]", file=sys.stderr)
    sys.exit(1)

cfg = configs[quant]
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

fname = cfg["file"]
print(f"\n{fname}")
hf_hub_download(
    repo_id=repo,
    filename=fname,
    local_dir=str(target),
)

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
