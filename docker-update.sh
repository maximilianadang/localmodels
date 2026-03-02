#!/bin/bash
# Update Ollama + Open WebUI to latest versions
# Works with both Docker and Podman

set -e

echo "⬆️  Updating Ollama + Open WebUI..."
echo ""

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

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ docker-compose.yml not found in current directory"
    echo "Run this script from the localmodels directory"
    exit 1
fi

# Pull latest images
echo "→ Pulling latest images..."
$CMD compose pull
echo ""

# Recreate containers with new images
echo "→ Recreating containers..."
$CMD compose up -d
echo ""

echo "⏳ Waiting for services to start..."
sleep 5

echo ""
echo "✅ Update complete"
echo ""
./status.sh
