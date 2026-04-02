#!/bin/bash
# Pull all round-table models into Ollama container
# Works with both Docker and Podman

set -e

# Detect container runtime
if command -v docker &> /dev/null && docker ps &> /dev/null 2>&1; then
    CONTAINER_CMD="docker"
elif command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
else
    echo "❌ Neither Docker nor Podman found."
    exit 1
fi

echo "📥 Pulling Ollama models into container..."
echo ""

# Array of models to pull
models=(
    "gemma2:2b"
    "gemma3:12b"
    "qwen3-coder"
    "qwen3.5:0.8b"
    "qwen3.5:2b"
    "qwen3.5:4b"
    "qwen3.5:9b"
)

total=${#models[@]}
current=0

for model in "${models[@]}"; do
    current=$((current + 1))
    echo "[$current/$total] Pulling $model..."
    $CONTAINER_CMD exec ollama ollama pull "$model"
    echo ""
done

echo "✅ All models pulled successfully!"
echo ""
echo "📊 Installed models:"
$CONTAINER_CMD exec ollama ollama list
