#!/bin/bash
# Download Qwen3-Coder-Next (Q4_K_M or Q8_0) from bartowski
# Usage: ./download-qwen3-coder-next.sh [q4|q8]  (default: q8)
set -eu

# MUST set this BEFORE any Python import
export HF_HUB_DISABLE_XET=1

python3 - "$@" <<'PYEOF'
import sys
import os
os.environ["HF_HUB_DISABLE_XET"] = "1"

from pathlib import Path
from huggingface_hub import hf_hub_download

# Double-check xet is disabled
from huggingface_hub.utils._runtime import is_xet_available
if is_xet_available():
    print("WARNING: xet is still available despite HF_HUB_DISABLE_XET=1", file=sys.stderr)
    print("This will likely cause downloads to stall. Continuing anyway...", file=sys.stderr)

variant = sys.argv[1].lower() if len(sys.argv) > 1 else "q8"
repo = "bartowski/Qwen_Qwen3-Coder-Next-GGUF"

configs = {
    "q4": {
        "dir": "qwen3-coder-next-q4",
        "subdir": "Qwen_Qwen3-Coder-Next-Q4_K_M",
        "files": [
            "Qwen_Qwen3-Coder-Next-Q4_K_M-00001-of-00002.gguf",
            "Qwen_Qwen3-Coder-Next-Q4_K_M-00002-of-00002.gguf",
        ],
        "label": "Q4_K_M (~49 GB, 2 shards)",
    },
    "q8": {
        "dir": "qwen3-coder-next-q8",
        "subdir": "Qwen_Qwen3-Coder-Next-Q8_0",
        "files": [
            "Qwen_Qwen3-Coder-Next-Q8_0-00001-of-00003.gguf",
            "Qwen_Qwen3-Coder-Next-Q8_0-00002-of-00003.gguf",
            "Qwen_Qwen3-Coder-Next-Q8_0-00003-of-00003.gguf",
        ],
        "label": "Q8_0 (~85 GB, 3 shards)",
    },
}

if variant not in configs:
    print(f"Unknown variant '{variant}'. Use q4 or q8.", file=sys.stderr)
    sys.exit(1)

cfg = configs[variant]
target = Path.home() / "models" / "bartowski" / cfg["dir"]

# Check already done - count actual GGUF files, not cache
current_gguf_count = len(list(target.glob("*.gguf")))
expected_count = len(cfg["files"])

if current_gguf_count == expected_count:
    print(f"[SKIP] Qwen3-Coder-Next {cfg['label']} already at {target}")
    sys.exit(0)

print(f"=== Downloading Qwen3-Coder-Next {cfg['label']} ===")
print(f"Target: {target}")
target.mkdir(parents=True, exist_ok=True)

# Only clean if we have some GGUF files but not all (partial download)
if current_gguf_count > 0 and current_gguf_count < expected_count:
    cache_dir = target / ".cache"
    if cache_dir.exists():
        import shutil
        shutil.rmtree(cache_dir)
        print(f"Cleaned partial cache at {cache_dir} (will resume)")

for i, fname in enumerate(cfg["files"], 1):
    print(f"\nShard {i}/{len(cfg['files'])}: {fname}")
    hf_hub_download(
        repo_id=repo,
        filename=fname,
        subfolder=cfg["subdir"],
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
