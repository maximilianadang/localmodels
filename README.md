# Ollama + Open WebUI Docker Deployment

Containerized deployment of Ollama and Open WebUI for running local LLMs with a web interface.

**Compatible with both Docker and Podman** - scripts automatically detect which runtime is available.

---

## Quick Start

### Prerequisites

**Option 1: Docker**
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

**Option 2: Podman** (Fedora/RHEL default)
```bash
# Fedora
sudo dnf install podman

# Ubuntu 20.10+
sudo apt install podman
```

**GPU Support (NVIDIA)**
```bash
# Install NVIDIA Container Toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### Deploy

```bash
# 1. Clone this repository or copy files
git clone <your-repo-url>
cd workspaces

# 2. Start services
./docker-deploy.sh

# 3. Pull models
./docker-pull-models.sh

# 4. Access Open WebUI
# Open http://localhost:8080 in your browser
```

---

## Files

- **docker-compose.yml** - Service definitions (Ollama + Open WebUI)
- **docker-deploy.sh** - Automated deployment script
- **docker-pull-models.sh** - Bulk model downloader (7 models)
- **.notes/** - Local documentation (not tracked in git)

---

## Model Collection

The `docker-pull-models.sh` script pulls these models:

### Coding (18.1 GB)
- `starcoder2:15b` - Code completion expert
- `qwen2.5-coder:14b` - Instruction-following coder

### Reasoning (18.1 GB)
- `deepseek-r1:14b` - Chain-of-thought specialist
- `phi4:14b` - Microsoft's reasoning model

### General (19.0 GB)
- `qwen3:14b` - Orchestration and agentic tasks
- `gemma3:12b` - Balanced general-purpose model
- `gemma2:2b` - Small, fast model

**Total**: ~55 GB

---

## Usage

### Management Commands

```bash
# Start services
./docker-deploy.sh
# or manually:
docker compose up -d    # or: podman compose up -d

# Stop services
docker compose stop

# View logs
docker compose logs -f
docker compose logs ollama

# Restart
docker compose restart

# Remove containers (keeps data)
docker compose down

# Remove everything including data (DESTRUCTIVE)
docker compose down -v
```

### Model Management

```bash
# List models
docker exec ollama ollama list

# Pull a specific model
docker exec ollama ollama pull llama3.2:3b

# Remove a model
docker exec ollama ollama rm gemma2:2b

# Run model interactively
docker exec -it ollama ollama run gemma2:2b
```

### API Usage

```bash
# Test Ollama API
curl -X POST http://localhost:11434/api/generate -d '{
  "model": "gemma2:2b",
  "prompt": "Hello!",
  "stream": false
}'

# List available models
curl http://localhost:11434/api/tags
```

---

## Ports

- **8080** - Open WebUI interface
- **11434** - Ollama API (internal, can expose if needed)

---

## Data Persistence

All data is stored in Docker/Podman volumes:

- **ollama-data** - Model files (~55 GB for full collection)
- **open-webui-data** - User accounts, chats, documents

### Backup

```bash
# Backup models
docker run --rm -v workspaces_ollama-data:/data \
  -v $(pwd):/backup ubuntu \
  tar czf /backup/ollama-backup.tar.gz /data

# Backup Open WebUI data
docker run --rm -v workspaces_open-webui-data:/data \
  -v $(pwd):/backup ubuntu \
  tar czf /backup/openwebui-backup.tar.gz /data
```

### Restore

```bash
# Restore models
docker run --rm -v workspaces_ollama-data:/data \
  -v $(pwd):/backup ubuntu \
  tar xzf /backup/ollama-backup.tar.gz -C /

# Restore Open WebUI data
docker run --rm -v workspaces_open-webui-data:/data \
  -v $(pwd):/backup ubuntu \
  tar xzf /backup/openwebui-backup.tar.gz -C /
```

---

## Deployment Scenarios

### Local Development
```bash
./docker-deploy.sh
# Access at http://localhost:8080
```

### Headless Server
```bash
# SSH to server
ssh user@server

# Deploy
./docker-deploy.sh

# Access from your machine
# http://server-ip:8080
```

### Behind Reverse Proxy (Production)

Example NGINX config:
```nginx
server {
    listen 80;
    server_name ai.yourdomain.com;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

---

## Troubleshooting

### GPU not detected

```bash
# Verify NVIDIA runtime
docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi

# Check Docker daemon config
cat /etc/docker/daemon.json
# Should contain nvidia runtime configuration
```

### Open WebUI can't connect to Ollama

```bash
# Check network
docker compose exec open-webui ping ollama

# Check Ollama is responding
docker compose exec open-webui curl http://ollama:11434/api/tags
```

### Podman-specific: Permission denied on volumes

```bash
# Run rootless
podman-compose up -d

# Or configure subuid/subgid
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER
```

---

## Platform Compatibility

| Platform | Docker | Podman | Notes |
|----------|--------|--------|-------|
| Ubuntu 20.04+ | ✅ | ✅ | Both work |
| Fedora 35+ | ✅ | ✅ | Podman default |
| RHEL 8+ | ✅ | ✅ | Podman default |
| Debian 11+ | ✅ | ⚠️ | Docker recommended |
| macOS | ✅ | ⚠️ | Docker Desktop recommended |
| Windows | ✅ | ⚠️ | Docker Desktop or WSL2 |

**Scripts automatically detect and use the available runtime.**

---

## Security Considerations

- Don't expose Ollama API (port 11434) to the internet
- Use reverse proxy with SSL for production
- Enable authentication in Open WebUI settings
- Keep containers updated: `docker compose pull && docker compose up -d`
- Consider using Docker secrets for sensitive configuration

---

## License

This deployment configuration is provided as-is.

Ollama and Open WebUI have their own respective licenses.

---

## Support

For issues related to:
- **Ollama**: https://github.com/ollama/ollama/issues
- **Open WebUI**: https://github.com/open-webui/open-webui/issues
- **This deployment**: [Your issue tracker]
