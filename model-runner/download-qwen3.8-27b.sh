#!/bin/bash
# Download Qwen3.8-27B quantized variants from Unsloth
# Usage: ./download-qwen3.8-27b.sh [ud8|ud6|ud5|ud4|ud3|ud2|q8|bf16|mmproj|all]  (default: ud8)
set -eu

export HF_HUB_DISABLE_XET=1

python3 - "$@" <<'PYEOF'
import sys
import os
os.environ["HF_HUB_DISABLE_XET"] = "1"

from pathlib import Path
from huggingface_hub import hf_hub_download

quant = sys.argv[1].lower() if len(sys.argv) > 1 else "ud8"
repo = "unsloth/Qwen3.8-27B-GGUF"
base = Path.home() / "models" / "unsloth"

configs = {
    "ud8":    {"target": "Qwen3.8-27B-GGUF", "file": "Qwen3.8-27B-UD-Q8_K_XL.gguf"},
    "ud6":    {"target": "Qwen3.8-27B-GGUF", "file": "Qwen3.8-27B-UD-Q6_K_XL.gguf"},
    "ud5":    {"target": "Qwen3.8-27B-GGUF", "file": "Qwen3.8-27B-UD-Q5_K_XL.gguf"},
    "ud4":    {"target": "Qwen3.8-27B-GGUF", "file": "Qwen3.8-27B-UD-Q4_K_XL.gguf"},
    "ud3":    {"target": "Qwen3.8-27B-GGUF", "file": "Qwen3.8-27B-UD-Q3_K_XL.gguf"},
    "ud2":    {"target": "Qwen3.8-27B-GGUF", "file": "Qwen3.8-27B-UD-Q2_K_XL.gguf"},
    "q8":     {"target": "Qwen3.8-27B-GGUF", "file": "Qwen3.8-27B-Q8_0.gguf"},
    "q4":     {"target": "Qwen3.8-27B-GGUF", "file": "Qwen3.8-27B-Q4_K_M.gguf"},
    "bf16":   {"target": "Qwen3.8-27B-GGUF/BF16", "files": [
                    "BF16/Qwen3.8-27B-BF16-00001-of-00002.gguf",
                    "BF16/Qwen3.8-27B-BF16-00002-of-00002.gguf",
                ]},
    "mmproj": {"target": "Qwen3.8-27B-GGUF", "files": [
                    "mmproj-BF16.gguf",
                    "mmproj-F16.gguf",
                ]},
    "all":    None,
}

if quant not in configs:
    print(f"Usage: {sys.argv[0]} [ud8|ud6|ud5|ud4|ud3|ud2|q8|q4|bf16|mmproj|all]", file=sys.stderr)
    sys.exit(1)

if quant == "all":
    for q in ["ud8", "mmproj"]:
        os.execvp("python3", ["python3", "-"] + [q])

cfg = configs[quant]
target = base / cfg["target"]

files = cfg.get("files", None)
if files is None:
    files = [cfg["file"]]

# Check if the specific file(s) already exist
missing = [f for f in files if not (target / f).exists()]
if not missing:
    print(f"[SKIP] Qwen3.8-27B {quant} already at {target}")
    sys.exit(0)

sizes = {
    "ud8":  "~31.5 GB", "ud6":  "~25.9 GB", "ud5":  "~20.2 GB",
    "ud4":  "~17.9 GB", "ud3":  "~13.4 GB", "ud2":  "~10.7 GB",
    "q8":   "~29 GB",   "q4":   "~17.1 GB", "bf16": "~55 GB (2 shards)",
    "mmproj": "~1.8 GB (2 files)",
}
print(f"=== Downloading Qwen3.8-27B {quant} ({sizes.get(quant, '?')}) ===")
print(f"Target: {target}")
target.mkdir(parents=True, exist_ok=True)

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
