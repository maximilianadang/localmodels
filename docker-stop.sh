#!/bin/bash
# Stop Ollama + Open WebUI Docker containers
# Works with both Docker and Podman

set -e

echo "🛑 Stopping Ollama + Open WebUI containers..."
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

# Stop containers
echo "→ Stopping services..."
$CMD compose stop

echo ""
echo "✅ Containers stopped"
echo ""
echo "💡 Useful commands:"
echo "  • Start again: ./docker-deploy.sh"
echo "  • Remove containers (keeps data): $CMD compose down"
echo "  • Remove everything (DESTRUCTIVE): $CMD compose down -v"
echo ""
