#!/bin/bash
# Download Muse-Glimmer-30B quantized variants from Unsloth
# Usage: ./download-muse-glimmer-30b.sh [q4|q8|ud8|bf16|mmproj|dflash|all]  (default: q8)
set -eu

export HF_HUB_DISABLE_XET=1

python3 - "$@" <<'PYEOF'
import sys
import os
os.environ["HF_HUB_DISABLE_XET"] = "1"

from pathlib import Path
from huggingface_hub import hf_hub_download

quant = sys.argv[1].lower() if len(sys.argv) > 1 else "q8"
repo = "unsloth/Muse-Glimmer-30B-GGUF"
base = Path.home() / "models" / "unsloth"

configs = {
    "q4":     {"target": "Muse-Glimmer-30B-GGUF", "file": "Muse-Glimmer-30B-UD-Q4_K_XL.gguf"},
    "q8":     {"target": "Muse-Glimmer-30B-GGUF", "file": "Muse-Glimmer-30B-Q8_0.gguf"},
    "ud8":    {"target": "Muse-Glimmer-30B-GGUF", "file": "Muse-Glimmer-30B-UD-Q8_K_XL.gguf"},
    "ud6":    {"target": "Muse-Glimmer-30B-GGUF", "file": "Muse-Glimmer-30B-UD-Q6_K_XL.gguf"},
    "ud5":    {"target": "Muse-Glimmer-30B-GGUF", "file": "Muse-Glimmer-30B-UD-Q5_K_XL.gguf"},
    "ud3":    {"target": "Muse-Glimmer-30B-GGUF", "file": "Muse-Glimmer-30B-UD-Q3_K_XL.gguf"},
    "ud2":    {"target": "Muse-Glimmer-30B-GGUF", "file": "Muse-Glimmer-30B-UD-Q2_K_XL.gguf"},
    "bf16":   {"target": "Muse-Glimmer-30B-GGUF/BF16", "files": [
                    "BF16/Muse-Glimmer-30B-BF16-00001-of-00002.gguf",
                    "BF16/Muse-Glimmer-30B-BF16-00002-of-00002.gguf",
                ]},
    "mmproj": {"target": "Muse-Glimmer-30B-GGUF", "files": [
                    "mmproj-Muse-Glimmer-30B-Q8_0.gguf",
                    "mmproj-Muse-Glimmer-30B-BF16.gguf",
                ]},
    "dflash": {"target": "Muse-Glimmer-30B-GGUF", "file": "dflash-kquant.gguf"},
    "all":    None,
}

if quant not in configs:
    print(f"Usage: {sys.argv[0]} [q4|q8|ud8|ud6|ud5|ud3|ud2|bf16|mmproj|dflash|all]", file=sys.stderr)
    sys.exit(1)

if quant == "all":
    for q in ["q8", "mmproj"]:
        os.execvp("python3", ["python3", "-"] + [q])

cfg = configs[quant]
target = base / cfg["target"]

current_gguf_count = len(list(target.glob("*.gguf")))
expected_count = len(cfg.get("files", []))
if expected_count == 0:
    expected_count = 1

if current_gguf_count >= expected_count:
    print(f"[SKIP] Muse-Glimmer-30B {quant} already at {target}")
    sys.exit(0)

sizes = {
    "q4":   "~17 GB", "q8":   "~30 GB", "ud8":  "~30 GB",
    "ud6":  "~22 GB", "ud5":  "~19 GB", "ud3":  "~14 GB",
    "ud2":  "~12 GB", "bf16": "~58 GB (2 shards)", "mmproj": "~1.8 GB (2 files)",
    "dflash": "~1.2 GB",
}
print(f"=== Downloading Muse-Glimmer-30B {quant} ({sizes.get(quant, '?')}) ===")
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
    label = f"File {i}/{len(files)}: " if len(files) > 1 else ""
    print(f"\n{label}{fname}")
    hf_hub_download(
        repo_id=repo,
        filename=fname,
        local_dir=str(target),
    )

print("\nDone:")
for f in sorted(target.glob("*.gguf")):
    print(f"  {f.name} ({f.stat().st_size / 1e9:.1f} GB)")
PYEOF
