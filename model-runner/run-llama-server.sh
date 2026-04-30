#!/bin/bash
#
# Run a llama.cpp server for any model.
# This is a generalized runner that supports multiple models.
#
# Usage:
#   ./run-llama-server.sh <model> [--port PORT] [llama-server flags...]
#
# Environment variables:
#   LLAMA_SERVER  - path to llama-server binary (default: /Users/kodep/Code/llama.cpp/build/bin/llama-server)
#   MODEL_DIR     - path to models directory (default: ~/models)
#   OLLAMA_DIR    - path to Ollama data dir (default: ~/.ollama)
#   GENERATORS_DIR - path to generators scripts (default: /Users/kodep/Ideas/generators/scripts)

set -eu

# Enable tensor API on Apple Silicon (M4/M5 chips) even if auto-detection fails
export GGML_METAL_TENSOR_ENABLE=1

LLAMA_SERVER="${LLAMA_SERVER:-/Users/kodep/Code/llama.cpp/build/bin/llama-server}"
MODEL_DIR="${MODEL_DIR:-$HOME/models}"
OLLAMA_DIR="${OLLAMA_DIR:-$HOME/.ollama}"
GENERATORS_DIR="${GENERATORS_DIR:-/Users/kodep/Ideas/generators/scripts}"

DEFAULT_PORT=8080
PORT="$DEFAULT_PORT"
PORT_SET=0
EXTRA_FLAGS=""

# --- Model path resolution functions (copied from generators/llamacpp-run.sh) ---
resolve_alias() {
    case "$1" in
        qwen3-coder-next|qwen3-coder-next-q8_k|qwen3-coder-next-q8) echo "${MODEL_DIR}/Qwen3-Coder-Next-Q8_0/Qwen3-Coder-Next-Q8_0/Qwen3-Coder-Next-Q8_0-00001-of-00004.gguf" ;;
        qwen3-embed)       echo "${MODEL_DIR}/Qwen3-Embedding-4B/Qwen3-Embedding-4B-Q4_K_M.gguf" ;;
        qwen3.6|qwen3.6-35b|qwen3.6:35b) echo "${MODEL_DIR}/BF16/Qwen3.6-35B-A3B-BF16-00001-of-00002.gguf" ;;
        qwen3.6-bf16|qwen3.6-35b-bf16|qwen3.6:35b-bf16|qwen3.6-coding-bf16) echo "${MODEL_DIR}/BF16/Qwen3.6-35B-A3B-BF16-00001-of-00002.gguf" ;;
        qwen3.6-27b-q8|qwen3.6-27b-q8_0) echo "${MODEL_DIR}/Qwen3.6-27B-Q8_0.gguf" ;;
        nemotron|nemotron-3) echo "${MODEL_DIR}/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-Q8_0.gguf" ;;
        *)                 return 1 ;;
    esac
}

resolve_model() {
    spec="$1"
    
    # 1. Direct path to a .gguf file
    case "$spec" in
        *.gguf)
            if [ ! -f "$spec" ]; then
                echo "ERROR: File not found: ${spec}" >&2
                exit 1
            fi
            echo "$spec"
            return
            ;;
    esac
    
    # 2. Known alias
    resolved=$(resolve_alias "$spec" 2>/dev/null) && {
        if [ -f "$resolved" ]; then
            echo "$resolved"
            return
        else
            echo "ERROR: Alias '${spec}' -> ${resolved} but file not found" >&2
            exit 1
        fi
    }
    
    # 3. Try generators script if available
    if [ -f "$GENERATORS_DIR/llamacpp-run.sh" ]; then
        resolved=$(bash -c "
            source \"$GENERATORS_DIR/llamacpp-run.sh\"
            resolve_model \"$spec\"
        " 2>/dev/null) || true
        if [ -n "$resolved" ]; then
            echo "$resolved"
            return
        fi
    fi
    
    echo "ERROR: Cannot resolve model: $spec" >&2
    echo "Tried: direct path, known aliases, and generators script" >&2
    exit 1
}

resolve_alias_extra() {
    case "$1" in
  qwen3-coder-next-q8_k)
             echo "-np 2 -fa on -ngl 99 --jinja -c 262144"
             ;;
        qwen3-embed)
            echo "--embedding -np 2 -c 262144"
            ;;
  qwen3.6|qwen3.6-35b|qwen3.6:35b|qwen3.6-bf16|qwen3.6-35b-bf16|qwen3.6-coding-bf16)
              echo "--mmproj ${MODEL_DIR}/mmproj-qwen3.6-35b.gguf -np 2 -fa on -ngl 99 --jinja -c 262144"
              ;;
  qwen3.6-27b-q8|qwen3.6-27b-q8_0)
              echo "--mmproj ${MODEL_DIR}/mmproj-qwen3.6-27b.gguf -np 2 -fa on -ngl 99 --jinja -c 262144"
              ;;
        nemotron|nemotron-3)
              echo "--mmproj ${MODEL_DIR}/mmproj-Nemotron-3-Nano-Omni-30B-A3B-Reasoning-BF16.gguf -np 2 -fa on -ngl 99 --jinja -c 262144"
              ;;
        *)           return 1 ;;
    esac
}

# --- Parse args --------------------------------------------------------------
if [ $# -lt 1 ]; then
    echo "Usage: $0 <model> [--port PORT] [llama-server flags...]"
    echo ""
    echo "Supported models:"
    echo "  qwen3-coder-next         Qwen3-Coder-Next (Q8_0) - GPU optimized with -np 2 (also: qwen3-coder-next-q8_k)"
    echo "  qwen3-embed              Qwen3-Embedding-4B"
    echo "  qwen3.6                  Qwen3.6-35B-A3B (BF16) - text+image, ~65GB"
    echo "  qwen3.6-bf16             Alias for qwen3.6 (same model)"
    echo "  qwen3.6-coding-bf16      Alias for qwen3.6 (same model)"
    echo "  qwen3.6-35b              Alias for qwen3.6 (same model)"
    echo "  qwen3.6-35b-bf16         Alias for qwen3.6 (same model)"
    echo "  qwen3.6-27b-q8           Qwen3.6-27B (Q8_0) - dense, ~27GB, text+image"
    echo "  nemotron                 NVIDIA Nemotron-3 30B-A3B (Q8_0) - text+image, ~31GB"
    echo "  gpt-oss-20b              GPT-OSS-20B (auto-download) - GPU optimized with -np 2"
    echo "  gpt-oss-120b             GPT-OSS-120B (auto-download) - GPU optimized with -np 2"
    echo ""
    echo "GPT-OSS models support --reasoning-effort (low|medium|high)"
    echo ""
    echo "Examples:"
    echo "  $0 qwen3-coder-next --port 8080"
    echo "  $0 gpt-oss-120b --port 8013"
    echo "  $0 gpt-oss-120b --reasoning-effort high --port 8013"
    echo "  $0 qwen3.6 --port 8090"
    echo "  $0 qwen3.6-27b-q8 --port 8092"
    echo "  $0 nemotron --port 8093"
    echo "  $0 ~/models/my-model.gguf --port 9000"
    exit 1
fi

MODEL_SPEC="$1"
shift

while [ $# -gt 0 ]; do
    case "$1" in
        --port)
            PORT="$2"
            PORT_SET=1
            shift 2
            ;;
        --reasoning-effort)
            case "$2" in
                low|minimal)
                    EXTRA_FLAGS="${EXTRA_FLAGS} --chat-template-kwargs {\"reasoning_effort\":\"low\"}"
                    ;;
                medium|default)
                    EXTRA_FLAGS="${EXTRA_FLAGS} --chat-template-kwargs {\"reasoning_effort\":\"medium\"}"
                    ;;
                high)
                    EXTRA_FLAGS="${EXTRA_FLAGS} --chat-template-kwargs {\"reasoning_effort\":\"high\"}"
                    ;;
                *)
                    echo "ERROR: Invalid reasoning_effort value: $2" >&2
                    echo "Valid values: low, minimal, medium, default, high" >&2
                    exit 1
                    ;;
            esac
            shift 2
            ;;
        --)
            shift
            EXTRA_FLAGS="$*"
            break
            ;;
        *)
            EXTRA_FLAGS="${EXTRA_FLAGS} $1"
            shift
            ;;
    esac
done

# --- Resolve aliases before processing ---
case "$MODEL_SPEC" in
    qwen3-coder-next-q8)
        # alias for qwen3-coder-next-q8_k
        MODEL_SPEC="qwen3-coder-next-q8_k"
        echo "Using alias: qwen3-coder-next-q8 -> qwen3-coder-next-q8_k"
        ;;
esac

# --- Resolve model path ---
MODEL_PATH=$(resolve_model "$MODEL_SPEC")

# --- Get extra flags for this model ---
ALIAS_EXTRA=$(resolve_alias_extra "$MODEL_SPEC" 2>/dev/null) || true
if [ -n "$ALIAS_EXTRA" ]; then
    EXTRA_FLAGS="${EXTRA_FLAGS} ${ALIAS_EXTRA}"
fi

# --- Check for built-in llama.cpp presets first (before generators) ---
case "$MODEL_SPEC" in
    gpt-oss-20b)
        echo "Using built-in llama.cpp preset: gpt-oss-20b (optimized for GPU)"
        if [ "$PORT_SET" -eq 0 ]; then
            PORT=8013
        fi
        echo "model:  gpt-oss-20b (auto-download)"
        echo "port:   $PORT"
        echo "config: -np 2 -fa on -ngl 99 -ctk q8_0 -ctv q8_0 --jinja -c 262144"
        echo ""
        exec "$LLAMA_SERVER" \
            --gpt-oss-20b-default \
            --host 0.0.0.0 \
            --port "$PORT" \
            $EXTRA_FLAGS
        ;;
    gpt-oss-120b)
        echo "Using built-in llama.cpp preset: gpt-oss-120b (optimized for GPU)"
        if [ "$PORT_SET" -eq 0 ]; then
            PORT=8013
        fi
        echo "model:  gpt-oss-120b (auto-download)"
        echo "port:   $PORT"
        echo "config: -np 2 -fa on -ngl 99 -ctk q8_0 -ctv q8_0 --jinja -c 262144"
        echo ""
        exec "$LLAMA_SERVER" \
            --gpt-oss-120b-default \
            --host 0.0.0.0 \
            --port "$PORT" \
            $EXTRA_FLAGS
        ;;
    *)
        echo "model:  $MODEL_SPEC"
        echo "file:   $MODEL_PATH"
        echo "port:   $PORT"
        if [ -n "$EXTRA_FLAGS" ]; then
            echo "extra:  $EXTRA_FLAGS"
        fi
        echo ""
        echo "config: $EXTRA_FLAGS"
        echo ""
        
        exec "$LLAMA_SERVER" \
            -m "$MODEL_PATH" \
            --host 0.0.0.0 \
            --port "$PORT" \
            $EXTRA_FLAGS
        ;;
esac
