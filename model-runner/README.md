# Model Runner Scripts

This directory contains scripts for running various LLM models with llama.cpp.

## Scripts

### `run-llama-server.sh`

A generalized runner that supports multiple models including:
- **Qwen3-Coder-Next** variants (Q4_K_M, Q6_K_M, Q8_0)
- **Qwen3-VL** (vision model)
- **Qwen3-Embedding** (embedding model)
- **GPT-OSS-20B** and **GPT-OSS-120B** (auto-download via llama.cpp presets)

## Usage

The script now supports the `--reasoning-effort` option for GPT-OSS models. Valid values are `low`, `medium` (default), and `high`. Example:

```bash
# Run GPT-OSS-120B with high reasoning effort
./run-llama-server.sh gpt-oss-120b --reasoning-effort high --port 8013
```

```bash
# Run Qwen3-Coder-Next on default port 8080
./run-llama-server.sh qwen3-coder-next

# Vision models (e.g., qwen3-vl) automatically receive safe defaults:
#   --temp 0.2         # lower randomness for more deterministic answers
#   You can still pass `--max-tokens N` on the command line if you need a hard token ceiling for a particular run.
# These flags are injected by the script’s resolve_alias_extra() function.

# Run on custom port
./run-llama-server.sh qwen3-coder-next --port 8080

# Run with additional llama-server flags
./run-llama-server.sh qwen3-coder-next --port 8080 -- -fa -ngl 99

# Run GPT-OSS-120B (auto-downloads from HF)
./run-llama-server.sh gpt-oss-120b --port 8013
```

## Environment Variables

- `LLAMA_SERVER` - Path to llama-server binary (default: `/Users/kodep/Code/llama.cpp/build/bin/llama-server`)
- `MODEL_DIR` - Path to models directory (default: `~/models`)
- `OLLAMA_DIR` - Path to Ollama data dir (default: `~/.ollama`)
- `GENERATORS_DIR` - Path to generators scripts (default: `/Users/kodep/Ideas/generators/scripts`)

## Model Aliases

| Alias | Model | Size | VRAM |
|-------|-------|------|------|
| `qwen3-coder-next` | Qwen3-Coder-Next Q4_K_M | 80B | 49GB |
| `qwen3-coder-next-q6_k` | Qwen3-Coder-Next Q6_K_M | 80B | 52GB |
| `qwen3-coder-next-q8_k` | Qwen3-Coder-Next Q8_0 | 80B | 76GB |
| `qwen3-coder-next-q8` (alias) | Qwen3-Coder-Next Q8_0 | 80B | 76GB |
| `qwen3-vl` | Qwen3-VL-30B vision | 30B | 19GB |
| `qwen3-embed` | Qwen3-Embedding-4B | 4B | 2.5GB |
| `gpt-oss-20b` | GPT-OSS-20B (auto-download) | 20B | ~20GB |
| `gpt-oss-120b` | GPT-OSS-120B (auto-download) | 120B | ~120GB |

## Integration with Generators

This script integrates with the generators project at `/Users/kodep/Ideas/generators/scripts/llamacpp-run.sh` for model resolution and aliases.

## Adding New Models

1. Add model alias to `resolve_alias()` function in the generators script
2. Add extra flags to `resolve_alias_extra()` if needed
3. Update this README with the new model
