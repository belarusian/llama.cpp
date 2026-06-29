#!/bin/bash
# Download Qwen3.6-35B-A3B MoE quantized variants from bartowski
# Usage: ./download-qwen3.6-moe.sh [q4|q8|mmproj]  (default: q8)
set -eu

export HF_HUB_DISABLE_XET=1

python3 - "$@" <<'PYEOF'
import sys
import os
os.environ["HF_HUB_DISABLE_XET"] = "1"

from pathlib import Path
from huggingface_hub import hf_hub_download

from huggingface_hub.utils._runtime import is_xet_available
if is_xet_available():
    print("WARNING: xet is still available despite HF_HUB_DISABLE_XET=1", file=sys.stderr)
    print("This will likely cause downloads to stall. Continuing anyway...", file=sys.stderr)

quant = sys.argv[1].lower() if len(sys.argv) > 1 else "q8"
repo = "bartowski/Qwen_Qwen3.6-35B-A3B-GGUF"
base = Path.home() / "models" / "bartowski"

configs = {
    "q4":     {"target": "qwen3.6-moe-q4",   "file": "Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf"},
    "q8":     {"target": "qwen3.6-moe-q8",   "file": "Qwen_Qwen3.6-35B-A3B-Q8_0.gguf"},
}

if quant not in configs:
    print(f"Usage: {sys.argv[0]} [q4|q8]", file=sys.stderr)
    sys.exit(1)

cfg = configs[quant]
target = base / cfg["target"]

current_gguf_count = len(list(target.glob("*.gguf")))

if current_gguf_count == 1:
    print(f"[SKIP] Qwen3.6-35B-A3B MoE {quant} already at {target}")
    sys.exit(0)

sizes = {"q4": "~22.3 GB", "q8": "~37.8 GB"}
print(f"=== Downloading Qwen3.6-35B-A3B MoE {quant} ({sizes[quant]}) ===")
print(f"Target: {target}")
target.mkdir(parents=True, exist_ok=True)

if current_gguf_count > 0:
    import shutil
    for f in target.glob("*.gguf"):
        f.unlink()
        print(f"Removed partial file: {f.name}")

fname = cfg["file"]
print(f"\n{fname}")
hf_hub_download(
    repo_id=repo,
    filename=fname,
    local_dir=str(target),
)

print("\nDone:")
for f in sorted(target.glob("*.gguf")):
    print(f"  {f.name} ({f.stat().st_size / 1e9:.1f} GB)")
PYEOF
