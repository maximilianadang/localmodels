#!/bin/bash
# Quick deployment script for Ollama + Open WebUI
# Works with both Docker and Podman

set -e

echo "🐳 Deploying Ollama + Open WebUI"
echo ""

# Detect if running in Distrobox
if [ -f /run/.containerenv ] && command -v distrobox-host-exec &> /dev/null; then
    PREFIX="distrobox-host-exec"
else
    PREFIX=""
fi

# Detect container runtime (Docker or Podman)
if $PREFIX docker ps &> /dev/null 2>&1; then
    CONTAINER_CMD="$PREFIX docker"
    echo "ℹ️  Using Docker"
elif $PREFIX podman ps &> /dev/null 2>&1; then
    CONTAINER_CMD="$PREFIX podman"
    echo "ℹ️  Using Podman"
else
    echo "❌ Neither Docker nor Podman found. Please install one:"
    echo "  Docker: curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh"
    echo "  Podman: sudo dnf install podman (Fedora) or sudo apt install podman (Ubuntu 20.10+)"
    exit 1
fi

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ docker-compose.yml not found in current directory"
    exit 1
fi

# Start services
echo "→ Starting services with Docker Compose..."
$CONTAINER_CMD compose up -d

echo ""
echo "⏳ Waiting for services to start..."
sleep 5

# Check if services are running
if $CONTAINER_CMD compose ps | grep -q "ollama.*Up"; then
    echo "✓ Ollama container running"
else
    echo "❌ Ollama container failed to start"
    $CONTAINER_CMD compose logs ollama
    exit 1
fi

if $CONTAINER_CMD compose ps | grep -q "open-webui.*Up"; then
    echo "✓ Open WebUI container running"
else
    echo "❌ Open WebUI container failed to start"
    $CONTAINER_CMD compose logs open-webui
    exit 1
fi

echo ""
echo "📊 Service Status:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
$CONTAINER_CMD compose ps

echo ""
echo "📝 Next Steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Access Open WebUI: http://localhost:8080"
echo "2. Pull models:"
echo "   docker exec ollama ollama pull gemma2:2b"
echo "   docker exec ollama ollama pull deepseek-r1:14b"
echo "   # ... etc"
echo ""
echo "3. Or pull all models at once:"
echo "   ./docker-pull-models.sh"
echo ""
echo "💡 Useful commands:"
echo "  • View logs: $CONTAINER_CMD compose logs -f"
echo "  • Stop services: $CONTAINER_CMD compose stop"
echo "  • Restart: $CONTAINER_CMD compose restart"
echo "  • Remove (keeps data): $CONTAINER_CMD compose down"
echo ""
