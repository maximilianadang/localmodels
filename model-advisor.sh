#!/bin/bash
# Model Advisor - recommends which models can be loaded based on current GPU/RAM usage
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

# Check Ollama is running
if ! $CONTAINER_CMD exec ollama ollama list &> /dev/null; then
    echo "❌ Ollama container not running. Start with: ./docker-deploy.sh"
    exit 1
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}📊 Model Advisor${NC}"
echo "================================"
echo ""

# --- GPU Info ---
if command -v nvidia-smi &> /dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
    GPU_TOTAL=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')
    GPU_USED=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')
    GPU_FREE=$(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')
    GPU_FREE_GB=$(awk "BEGIN {printf \"%.1f\", $GPU_FREE / 1024}")
    GPU_USED_GB=$(awk "BEGIN {printf \"%.1f\", $GPU_USED / 1024}")
    GPU_TOTAL_GB=$(awk "BEGIN {printf \"%.1f\", $GPU_TOTAL / 1024}")
    GPU_UTIL=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')

    echo -e "${BOLD}GPU:${NC} $GPU_NAME"
    echo -e "${BOLD}VRAM:${NC} ${GPU_USED_GB}GB used / ${GPU_TOTAL_GB}GB total (${GREEN}${GPU_FREE_GB}GB free${NC})"
    echo -e "${BOLD}GPU Util:${NC} ${GPU_UTIL}%"
    HAS_GPU=true
else
    echo -e "${YELLOW}⚠ No NVIDIA GPU detected — models will run on CPU/RAM${NC}"
    GPU_FREE=0
    GPU_FREE_GB="0"
    HAS_GPU=false
fi

# --- RAM Info ---
RAM_TOTAL=$(free -m | awk '/^Mem:/ {print $2}')
RAM_AVAIL=$(free -m | awk '/^Mem:/ {print $7}')
RAM_AVAIL_GB=$(awk "BEGIN {printf \"%.1f\", $RAM_AVAIL / 1024}")
RAM_TOTAL_GB=$(awk "BEGIN {printf \"%.1f\", $RAM_TOTAL / 1024}")

echo -e "${BOLD}RAM:${NC}  ${RAM_AVAIL_GB}GB available / ${RAM_TOTAL_GB}GB total"
echo ""

# --- Currently loaded models ---
echo -e "${BOLD}🔄 Currently Loaded Models${NC}"
echo "--------------------------------"
LOADED=$($CONTAINER_CMD exec ollama ollama ps 2>/dev/null)
LOADED_LINES=$(echo "$LOADED" | tail -n +2)

if [ -z "$LOADED_LINES" ]; then
    echo -e "  ${CYAN}(none)${NC}"
else
    echo "$LOADED_LINES" | while IFS= read -r line; do
        echo "  $line"
    done
fi
echo ""

# --- Installed models with fit assessment ---
echo -e "${BOLD}📦 Installed Models${NC}"
echo "--------------------------------"
printf "  ${BOLD}%-28s %8s   %s${NC}\n" "MODEL" "SIZE" "STATUS"
echo "  ---------------------------------------------------"

# Parse installed models
$CONTAINER_CMD exec ollama ollama list 2>/dev/null | tail -n +2 | while IFS= read -r line; do
    MODEL_NAME=$(echo "$line" | awk '{print $1}')
    MODEL_SIZE=$(echo "$line" | awk '{print $3, $4}')

    # Parse size to MB for comparison
    SIZE_NUM=$(echo "$MODEL_SIZE" | awk '{print $1}')
    SIZE_UNIT=$(echo "$MODEL_SIZE" | awk '{print $2}')
    SIZE_MB=0
    if [ "$SIZE_UNIT" = "GB" ]; then
        SIZE_MB=$(awk "BEGIN {printf \"%.0f\", $SIZE_NUM * 1024}")
    elif [ "$SIZE_UNIT" = "MB" ]; then
        SIZE_MB=$(awk "BEGIN {printf \"%.0f\", $SIZE_NUM}")
    fi

    # Check if currently loaded
    IS_LOADED=$(echo "$LOADED_LINES" | grep -c "^$MODEL_NAME" 2>/dev/null || true)

    # Determine fit (model needs ~10-20% overhead for KV cache on top of weights)
    VRAM_NEEDED=$(awk "BEGIN {printf \"%.0f\", $SIZE_MB * 1.15}")

    if [ "$IS_LOADED" -gt 0 ]; then
        STATUS="${CYAN}● loaded${NC}"
    elif [ "$HAS_GPU" = true ] && [ "$VRAM_NEEDED" -le "$GPU_FREE" ]; then
        STATUS="${GREEN}✓ fits in VRAM${NC}"
    elif [ "$SIZE_MB" -le "$RAM_AVAIL" ]; then
        if [ "$HAS_GPU" = true ]; then
            STATUS="${YELLOW}~ CPU/RAM only (too large for free VRAM)${NC}"
        else
            STATUS="${GREEN}✓ fits in RAM${NC}"
        fi
    else
        STATUS="${RED}✗ insufficient memory${NC}"
    fi

    printf "  %-28s %8s   " "$MODEL_NAME" "$MODEL_SIZE"
    echo -e "$STATUS"
done

echo ""
echo "--------------------------------"
if [ "$HAS_GPU" = true ]; then
    echo -e "  ${GREEN}✓${NC} fits in VRAM    ${YELLOW}~${NC} CPU/RAM fallback    ${RED}✗${NC} won't fit    ${CYAN}●${NC} loaded"
else
    echo -e "  ${GREEN}✓${NC} fits in RAM    ${RED}✗${NC} won't fit"
fi
echo ""

# --- Top GPU processes (if GPU present and something is using it) ---
if [ "$HAS_GPU" = true ] && [ "$GPU_USED" -gt 500 ]; then
    echo -e "${BOLD}🖥  GPU Processes${NC}"
    echo "--------------------------------"
    nvidia-smi --query-compute-apps=pid,process_name,used_gpu_memory --format=csv,noheader 2>/dev/null | while IFS=, read -r pid pname pmem; do
        pid=$(echo "$pid" | tr -d ' ')
        pname=$(echo "$pname" | xargs basename 2>/dev/null || echo "$pname")
        pmem=$(echo "$pmem" | tr -d ' ')
        printf "  PID %-8s %-20s %s\n" "$pid" "$pname" "$pmem"
    done
    echo ""
fi
