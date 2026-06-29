#!/bin/bash
# Download Qwen3.6-27B quantized variants from bartowski
# Usage: ./download-qwen3.6-27b.sh [q4|q8|bf16|mmproj]  (default: q8)
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

quant = sys.argv[1].lower() if len(sys.argv) > 1 else "q8"
repo = "bartowski/Qwen_Qwen3.6-27B-GGUF"
base = Path.home() / "models" / "bartowski"

configs = {
    "q4":     {"target": "qwen3.6-27b-q4",   "file": "Qwen_Qwen3.6-27B-Q4_K_M.gguf"},
    "q8":     {"target": "qwen3.6-27b-q8",   "file": "Qwen_Qwen3.6-27B-Q8_0.gguf"},
    "bf16":   {"target": "qwen3.6-27b-bf16", "subdir": "Qwen_Qwen3.6-27B-bf16",
               "files": [
                   "Qwen_Qwen3.6-27B-bf16-00001-of-00002.gguf",
                   "Qwen_Qwen3.6-27B-bf16-00002-of-00002.gguf",
               ]},
    "mmproj": {"target": "mmproj",           "file": "mmproj-Qwen_Qwen3.6-27B-f16.gguf"},
}

if quant not in configs:
    print(f"Usage: {sys.argv[0]} [q4|q8|bf16|mmproj]", file=sys.stderr)
    sys.exit(1)

cfg = configs[quant]
target = base / cfg["target"]

# Check already done - count actual GGUF files, not cache
current_gguf_count = len(list(target.glob("*.gguf")))
expected_count = len(cfg.get("files", []))
if expected_count == 0:
    expected_count = 1  # single file case has 'file' key

if current_gguf_count == expected_count:
    print(f"[SKIP] Qwen3.6-27B {quant} already at {target}")
    sys.exit(0)

sizes = {"q4": "~18 GB", "q8": "~29 GB", "bf16": "~55 GB (2 shards)", "mmproj": "~0.9 GB"}
print(f"=== Downloading Qwen3.6-27B {quant} ({sizes[quant]}) ===")
print(f"Target: {target}")
target.mkdir(parents=True, exist_ok=True)

# Only clean if we have some GGUF files but not all (partial download)
if current_gguf_count > 0 and current_gguf_count < expected_count:
    cache_dir = target / ".cache"
    if cache_dir.exists():
        import shutil
        shutil.rmtree(cache_dir)
        print(f"Cleaned partial cache at {cache_dir} (will resume)")

files = cfg.get("files", None)
if files is None:
    files = [cfg["file"]]
subdir = cfg.get("subdir")

for i, fname in enumerate(files, 1):
    label = f"Shard {i}/{len(files)}: " if len(files) > 1 else ""
    print(f"\n{label}{fname}")
    hf_hub_download(
        repo_id=repo,
        filename=fname,
        subfolder=subdir,
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
