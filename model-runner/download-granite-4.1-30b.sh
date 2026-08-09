#!/bin/bash
# Download IBM Granite 4.1 30B quantized variants from ibm-granite
# Usage: ./download-granite-4.1-30b.sh [q4|q8|bf16|all]  (default: q8)
set -eu

# MUST set this BEFORE any Python import
export HF_HUB_DISABLE_XET=1

python3 - "$@" <<'PYEOF'
import sys
import os
os.environ["HF_HUB_DISABLE_XET"] = "1"

from pathlib import Path
from huggingface_hub import hf_hub_download

quant = sys.argv[1].lower() if len(sys.argv) > 1 else "q8"
repo = "ibm-granite/granite-4.1-30b-GGUF"
base = Path.home() / "models" / "ibm-granite"

configs = {
    "q4":     {"target": "granite-4.1-30b-q4",   "file": "granite-4.1-30b-Q4_K_M.gguf"},
    "q8":     {"target": "granite-4.1-30b-q8",   "file": "granite-4.1-30b-Q8_0.gguf"},
    "bf16":   {"target": "granite-4.1-30b-bf16", "files": [
                    "granite-4.1-30b-bf16-00001-of-00005.gguf",
                    "granite-4.1-30b-bf16-00002-of-00005.gguf",
                    "granite-4.1-30b-bf16-00003-of-00005.gguf",
                    "granite-4.1-30b-bf16-00004-of-00005.gguf",
                    "granite-4.1-30b-bf16-00005-of-00005.gguf",
                ]},
    "all":    None,
}

if quant not in configs:
    print(f"Usage: {sys.argv[0]} [q4|q8|bf16|all]", file=sys.stderr)
    sys.exit(1)

if quant == "all":
    for q in ["q4", "q8", "bf16"]:
        os.execvp("python3", ["python3", "-"] + [q])

cfg = configs[quant]
target = base / cfg["target"]

current_gguf_count = len(list(target.glob("*.gguf")))
expected_count = len(cfg.get("files", []))
if expected_count == 0:
    expected_count = 1

if current_gguf_count == expected_count:
    print(f"[SKIP] Granite 4.1 30B {quant} already at {target}")
    sys.exit(0)

sizes = {"q4": "~17.5 GB", "q8": "~30.7 GB", "bf16": "~57.7 GB (5 shards)"}
print(f"=== Downloading Granite 4.1 30B {quant} ({sizes[quant]}) ===")
print(f"Target: {target}")
target.mkdir(parents=True, exist_ok=True)

if current_gguf_count > 0 and current_gguf_count < expected_count:
    cache_dir = target / ".cache"
    if cache_dir.exists():
        import shutil
        shutil.rmtree(cache_dir)
        print(f"Cleaned partial cache at {cache_dir} (will resume)")

files = cfg.get("files", None)
if files is None:
    files = [cfg["file"]]

for i, fname in enumerate(files, 1):
    label = f"Shard {i}/{len(files)}: " if len(files) > 1 else ""
    print(f"\n{label}{fname}")
    hf_hub_download(
        repo_id=repo,
        filename=fname,
        local_dir=str(target),
    )

cache_dir = target / ".cache"
if cache_dir.exists():
    import shutil
    shutil.rmtree(cache_dir)
    print(f"\nCleaned cache at {cache_dir}")

print("\nDone:")
for f in sorted(target.glob("*.gguf")):
    print(f"  {f.name} ({f.stat().st_size / 1e9:.1f} GB)")
PYEOF
