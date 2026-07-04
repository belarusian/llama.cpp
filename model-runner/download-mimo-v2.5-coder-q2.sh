#!/bin/bash
# Download MiMo-V2.5-coder-Q2 from jedisct1
# Usage: ./download-mimo-v2.5-coder-q2.sh
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

repo = "jedisct1/MiMo-V2.5-coder-Q2"
base = Path.home() / "models"
target = base / "mimo-v2.5-coder-q2"

files = [f"MiMo-V2.5-coder-Q2-{i:05d}-of-00016.gguf" for i in range(1, 17)]

current_gguf_count = len(list(target.glob("*.gguf")))
expected_count = len(files)

if current_gguf_count == expected_count:
    print(f"[SKIP] MiMo-V2.5-coder-Q2 already downloaded ({expected_count} shards at {target})")
    sys.exit(0)

print("=== Downloading MiMo-V2.5-coder-Q2 (~114 GB, 16 shards) ===")
print(f"Target: {target}")
target.mkdir(parents=True, exist_ok=True)

if current_gguf_count > 0 and current_gguf_count < expected_count:
    cache_dir = target / ".cache"
    if cache_dir.exists():
        import shutil
        shutil.rmtree(cache_dir)
        print(f"Cleaned partial cache at {cache_dir} (will resume)")

for i, fname in enumerate(files, 1):
    existing = list(target.glob(fname))
    if existing and existing[0].stat().st_size > 0:
        sz = existing[0].stat().st_size / 1e9
        print(f"\nShard {i}/{len(files)}: {fname} — already downloaded ({sz:.1f} GB), skipping")
        continue

    print(f"\nShard {i}/{len(files)}: {fname}")
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