#!/bin/bash
#
# Run a MLX model for Qwen3.6.
# This is a generalized runner that supports multiple Qwen3.6 models via MLX.
#
# Usage:
#   ./run-mlx.sh <model> [options]
#
# Environment variables:
#   PYTHON        - path to python (default: python3)
#
# Supported models:
#   qwen3.6-mxfp8        Qwen3.6-35B-A3B (MXFP8) - 38GB, text+image
#   qwen3.6-27b-mxfp8    Qwen3.6-27B (MXFP8) - ~27GB, text only
#   qwen3.6-27b-bf16     Qwen3.6-27B (BF16) - 55GB, text only
#   qwen3.6-27b-vl       Qwen3.6-27B (MXFP8) with vision - ~27GB, text+image
#   qwen3.6-35b-vl       Qwen3.6-35B-A3B (MXFP8) with vision - 38GB, text+image
#
# Examples:
#   ./run-mlx.sh qwen3.6-mxfp8 --server --port 8090
#   ./run-mlx.sh qwen3.6-27b-bf16 --temp 0.7 --max-tokens 500
#   ./run-mlx.sh qwen3.6-27b-bf16 --chat
#   ./run-mlx.sh qwen3.6-mxfp8 --server --port 8090 --temp 0.7
#

set -eu

PYTHON="${PYTHON:-python3}"

DEFAULT_TEMP=0.7
DEFAULT_MAX_TOKENS=512
DEFAULT_PORT=8080
TEMP="$DEFAULT_TEMP"
MAX_TOKENS="$DEFAULT_MAX_TOKENS"
PORT="$DEFAULT_PORT"
PORT_SET=0
CHAT_MODE=0
SERVER_MODE=0
PROMPT=""
EXTRA_FLAGS=""

resolve_model() {
    case "$1" in
        qwen3.6-mxfp8|qwen3.6-35b-mxfp8) echo "mlx-community/Qwen3.6-35B-A3B-mxfp8" ;;
        qwen3.6-27b-mxfp8) echo "mlx-community/Qwen3.6-27B-mxfp8" ;;
        qwen3.6-27b-bf16|qwen3.6-27b) echo "Qwen/Qwen3.6-27B" ;;
        qwen3.6-27b-vl|qwen3.6-27b-vision) echo "mlx-community/Qwen3.6-27B-mxfp8" ;;
        qwen3.6-35b-vl|qwen3.6-35b-a3b-vision) echo "mlx-community/Qwen3.6-35B-A3B-mxfp8" ;;
        *) return 1 ;;
    esac
}

resolve_server_extra() {
    case "$1" in
        qwen3.6-mxfp8|qwen3.6-35b-mxfp8)
            echo "--max-tokens 2048 --prefill-step-size 8192 --prompt-concurrency 8 --decode-concurrency 16"
            ;;
        qwen3.6-27b-mxfp8)
            echo "--max-tokens 2048 --prefill-step-size 8192 --prompt-concurrency 8 --decode-concurrency 16"
            ;;
        qwen3.6-27b-bf16|qwen3.6-27b)
            echo "--max-tokens 2048 --prefill-step-size 8192 --prompt-concurrency 8 --decode-concurrency 16"
            ;;
        qwen3.6-27b-vl|qwen3.6-27b-vision)
            echo "--max-tokens 2048 --prefill-step-size 8192 --prompt-concurrency 8 --decode-concurrency 16"
            ;;
        qwen3.6-35b-vl|qwen3.6-35b-a3b-vision)
            echo "--max-tokens 2048 --prefill-step-size 8192 --prompt-concurrency 8 --decode-concurrency 16"
            ;;
        *) return 1 ;;
    esac
}

# --- Parse args --------------------------------------------------------------
if [ $# -lt 1 ]; then
    echo "Usage: $0 <model> [options]"
    echo ""
    echo "Supported models:"
    echo "  qwen3.6-mxfp8        Qwen3.6-35B-A3B (MXFP8) - 38GB, text+image"
    echo "  qwen3.6-27b-mxfp8    Qwen3.6-27B (MXFP8) - ~27GB, text only"
    echo "  qwen3.6-27b-bf16     Qwen3.6-27B (BF16) - 55GB, text only"
    echo "  qwen3.6-27b-vl       Qwen3.6-27B (MXFP8) with vision - ~27GB, text+image"
    echo "  qwen3.6-35b-vl       Qwen3.6-35B-A3B (MXFP8) with vision - 38GB, text+image"
    echo ""
    echo "Options:"
    echo "  --port PORT          Port for server mode (default: 8080)"
    echo "  --temp TEMPERATURE   Sampling temperature (default: 0.7)"
    echo "  --max-tokens N       Max tokens to generate (default: 512)"
    echo "  --prompt TEXT        Initial prompt"
    echo "  --chat               Enable chat mode (interactive)"
    echo "  --server             Start OpenAI-compatible API server"
    echo ""
    echo "Examples:"
    echo "  $0 qwen3.6-mxfp8 --server --port 8090"
    echo "  $0 qwen3.6-27b-bf16 --temp 0.7 --max-tokens 500"
    echo "  $0 qwen3.6-27b-bf16 --chat"
    echo "  $0 qwen3.6-27b-bf16 --server --port 8090"
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
        --temp)
            TEMP="$2"
            shift 2
            ;;
        --max-tokens)
            MAX_TOKENS="$2"
            shift 2
            ;;
        --prompt)
            PROMPT="$2"
            shift 2
            ;;
        --chat)
            CHAT_MODE=1
            shift
            ;;
        --server)
            SERVER_MODE=1
            shift
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

# --- Resolve model -----------------------------------------------------------
MODEL_ID=$(resolve_model "$MODEL_SPEC")

if [ -z "$MODEL_ID" ]; then
    echo "ERROR: Unknown model: $MODEL_SPEC" >&2
    echo "Supported models:" >&2
    echo "  qwen3.6-mxfp8        Qwen3.6-35B-A3B (MXFP8) - 38GB, text+image" >&2
    echo "  qwen3.6-27b-mxfp8    Qwen3.6-27B (MXFP8) - ~27GB, text only" >&2
    echo "  qwen3.6-27b-bf16     Qwen3.6-27B (BF16) - 55GB, text only" >&2
    echo "  qwen3.6-27b-vl       Qwen3.6-27B (MXFP8) with vision - ~27GB, text+image" >&2
    echo "  qwen3.6-35b-vl       Qwen3.6-35B-A3B (MXFP8) with vision - 38GB, text+image" >&2
    exit 1
fi

# --- Get extra flags for this model ------------------------------------------
SERVER_EXTRA=$(resolve_server_extra "$MODEL_SPEC" 2>/dev/null) || true
if [ -n "$SERVER_EXTRA" ]; then
    EXTRA_FLAGS="${EXTRA_FLAGS} ${SERVER_EXTRA}"
fi

if [ "$SERVER_MODE" -eq 1 ]; then
    # --- Server mode -----------------------------------------------------------
    if [ "$PORT_SET" -eq 0 ]; then
        PORT=8090
    fi

    echo "model:  $MODEL_SPEC"
    echo "hf repo: $MODEL_ID"
    echo "port:   $PORT"
    echo "temp:   $TEMP"
    echo "max-tokens: $MAX_TOKENS"
    echo "mode:   server (OpenAI-compatible API)"
    echo ""

    # Check Metal
    $PYTHON -c "
import mlx.core as mx
if not mx.metal.is_available():
    print('ERROR: Metal GPU not available. MLX requires Apple Silicon.', file=__import__('sys').stderr)
    exit(1)
print('Metal GPU: OK')
" 2>&1

    echo "Downloading model $MODEL_ID (first run downloads ~38-55GB)..."
    $PYTHON -c "
import mlx_lm
model, tokenizer = mlx_lm.load('$MODEL_ID')
print('Model ready')
" 2>&1 || {
        echo "ERROR: Failed to download model" >&2
        exit 1
    }

    echo "Starting MLX server at http://127.0.0.1:$PORT"
    echo "OpenAI endpoint: http://127.0.0.1:$PORT/v1/chat/completions"
    echo ""

    exec $PYTHON -m mlx_lm server \
        --model "$MODEL_ID" \
        --port "$PORT" \
        --temp "$TEMP" \
        --max-tokens "$MAX_TOKENS" \
        --use-default-chat-template \
        $EXTRA_FLAGS

elif [ "$CHAT_MODE" -eq 1 ] || [ -n "$PROMPT" ]; then
    # --- Interactive mode ------------------------------------------------------
    echo "model:  $MODEL_SPEC"
    echo "hf repo: $MODEL_ID"
    echo "temp:   $TEMP"
    echo "max-tokens: $MAX_TOKENS"
    if [ -n "$PROMPT" ]; then
        echo "prompt: $PROMPT"
    fi
    if [ "$CHAT_MODE" -eq 1 ]; then
        echo "mode:   chat (interactive)"
    fi
    echo ""

    # Check Metal
    $PYTHON -c "
import mlx.core as mx
if not mx.metal.is_available():
    print('ERROR: Metal GPU not available. MLX requires Apple Silicon.', file=__import__('sys').stderr)
    exit(1)
print('Metal GPU: OK')
" 2>&1

    echo "Downloading model $MODEL_ID (first run downloads ~38-55GB)..."
    $PYTHON -c "
import mlx_lm
model, tokenizer = mlx_lm.load('$MODEL_ID')
print('Model ready')
" 2>&1 || {
        echo "ERROR: Failed to download model" >&2
        exit 1
    }

    # --- Create Python script for running ----------------------------------------
    run_script=$(mktemp /tmp/run-mlx-XXXXXX.py)
    trap "rm -f '$run_script'" EXIT

    cat > "$run_script" << 'PYTHON_SCRIPT'
import mlx_lm
import mlx.core as mx
import sys

def main():
    model_id = sys.argv[1]
    temp = float(sys.argv[2])
    max_tokens = int(sys.argv[3])
    chat_mode = sys.argv[4] == "1"
    prompt = sys.argv[5] if len(sys.argv) > 5 and sys.argv[5] else ""

    # Load model
    print(f"Loading model {model_id}...", file=sys.stderr)
    model, tokenizer = mlx_lm.load(model_id)
    print(f"Model loaded", file=sys.stderr)

    # Chat history for conversation mode
    if chat_mode:
        messages = []
        print("Chat mode started. Type 'quit' or 'exit' to stop.")
        print("=" * 50)

        while True:
            try:
                user_input = input("\nYou: ").strip()
            except (EOFError, KeyboardInterrupt):
                print("\nGoodbye!")
                break

            if user_input.lower() in ['quit', 'exit', 'q']:
                print("Goodbye!")
                break

            if not user_input:
                continue

            messages.append({'role': 'user', 'content': user_input})

            try:
                # Apply chat template to get the prompt string
                prompt_str = tokenizer.apply_chat_template(
                    messages,
                    tokenize=False,
                    add_generation_prompt=True
                )

                response = mlx_lm.generate(
                    model,
                    tokenizer,
                    prompt=prompt_str,
                    max_tokens=max_tokens,
                    temp=temp,
                    verbose=False
                )

                print(f"\nAssistant: {response}")
                messages.append({'role': 'assistant', 'content': response})
            except Exception as e:
                print(f"\nError: {e}", file=sys.stderr)
    else:
        # Single prompt mode
        if prompt:
            user_prompt = prompt
        else:
            user_prompt = "Hello, how are you?"

        messages = [{'role': 'user', 'content': user_prompt}]
        prompt_str = tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=True
        )

        response = mlx_lm.generate(
            model,
            tokenizer,
            prompt=prompt_str,
            max_tokens=max_tokens,
            temp=temp,
            verbose=False
        )
        print(response)

if __name__ == '__main__':
    main()
PYTHON_SCRIPT

    $PYTHON "$run_script" \
        "$MODEL_ID" \
        "$TEMP" \
        "$MAX_TOKENS" \
        "$CHAT_MODE" \
        "$PROMPT"
else
    # --- Default: single prompt ------------------------------------------------
    echo "model:  $MODEL_SPEC"
    echo "hf repo: $MODEL_ID"
    echo "temp:   $TEMP"
    echo "max-tokens: $MAX_TOKENS"
    echo "mode:   single prompt"
    echo ""

    # Check Metal
    $PYTHON -c "
import mlx.core as mx
if not mx.metal.is_available():
    print('ERROR: Metal GPU not available. MLX requires Apple Silicon.', file=__import__('sys').stderr)
    exit(1)
print('Metal GPU: OK')
" 2>&1

    echo "Downloading model $MODEL_ID (first run downloads ~38-55GB)..."
    $PYTHON -c "
import mlx_lm
model, tokenizer = mlx_lm.load('$MODEL_ID')
print('Model ready')
" 2>&1 || {
        echo "ERROR: Failed to download model" >&2
        exit 1
    }

    # --- Create Python script for running ----------------------------------------
    run_script=$(mktemp /tmp/run-mlx-XXXXXX.py)
    trap "rm -f '$run_script'" EXIT

    cat > "$run_script" << 'PYTHON_SCRIPT'
import mlx_lm
import mlx.core as mx
import sys

def main():
    model_id = sys.argv[1]
    temp = float(sys.argv[2])
    max_tokens = int(sys.argv[3])
    chat_mode = sys.argv[4] == "1"
    prompt = sys.argv[5] if len(sys.argv) > 5 and sys.argv[5] else ""

    # Load model
    print(f"Loading model {model_id}...", file=sys.stderr)
    model, tokenizer = mlx_lm.load(model_id)
    print(f"Model loaded", file=sys.stderr)

    # Chat history for conversation mode
    if chat_mode:
        messages = []
        print("Chat mode started. Type 'quit' or 'exit' to stop.")
        print("=" * 50)

        while True:
            try:
                user_input = input("\nYou: ").strip()
            except (EOFError, KeyboardInterrupt):
                print("\nGoodbye!")
                break

            if user_input.lower() in ['quit', 'exit', 'q']:
                print("Goodbye!")
                break

            if not user_input:
                continue

            messages.append({'role': 'user', 'content': user_input})

            try:
                # Apply chat template to get the prompt string
                prompt_str = tokenizer.apply_chat_template(
                    messages,
                    tokenize=False,
                    add_generation_prompt=True
                )

                response = mlx_lm.generate(
                    model,
                    tokenizer,
                    prompt=prompt_str,
                    max_tokens=max_tokens,
                    temp=temp,
                    verbose=False
                )

                print(f"\nAssistant: {response}")
                messages.append({'role': 'assistant', 'content': response})
            except Exception as e:
                print(f"\nError: {e}", file=sys.stderr)
    else:
        # Single prompt mode
        if prompt:
            user_prompt = prompt
        else:
            user_prompt = "Hello, how are you?"

        messages = [{'role': 'user', 'content': user_prompt}]
        prompt_str = tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=True
        )

        response = mlx_lm.generate(
            model,
            tokenizer,
            prompt=prompt_str,
            max_tokens=max_tokens,
            temp=temp,
            verbose=False
        )
        print(response)

if __name__ == '__main__':
    main()
PYTHON_SCRIPT

    $PYTHON "$run_script" \
        "$MODEL_ID" \
        "$TEMP" \
        "$MAX_TOKENS" \
        "0" \
        "$PROMPT"

fi
