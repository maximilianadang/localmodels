#!/bin/bash
# Quick status check for Ollama + Open WebUI

# Detect if running in Distrobox
if [ -f /run/.containerenv ] && command -v distrobox-host-exec &> /dev/null; then
    PREFIX="distrobox-host-exec"
else
    PREFIX=""
fi

# Detect container runtime
if $PREFIX docker ps &> /dev/null 2>&1; then
    CMD="$PREFIX docker"
elif $PREFIX podman ps &> /dev/null 2>&1; then
    CMD="$PREFIX podman"
else
    echo "❌ No container runtime found"
    exit 1
fi

echo "🐳 Container Status:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
$CMD ps --filter "name=ollama" --filter "name=open-webui" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "📊 Services:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check Ollama
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    MODEL_COUNT=$(curl -s http://localhost:11434/api/tags | grep -o '"name"' | wc -l)
    echo "✓ Ollama API: http://localhost:11434 ($MODEL_COUNT models)"
else
    echo "✗ Ollama API: Not responding"
fi

# Check Open WebUI
if curl -s http://localhost:8080 > /dev/null 2>&1; then
    echo "✓ Open WebUI: http://localhost:8080"
else
    echo "✗ Open WebUI: Not responding"
fi

echo ""
