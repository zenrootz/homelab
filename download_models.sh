#!/bin/bash
# Model download script for Qwen Multimodal Agent
set -e

VAULT_DIR="./vault"
MODELS_DIR="${VAULT_DIR}/models"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - DOWNLOAD: $1"
}

error_exit() {
    echo "ERROR: $1"
    exit 1
}

# Create models directory
mkdir -p "$MODELS_DIR"
cd "$MODELS_DIR"

log "Starting model downloads..."
log "This may take several hours depending on your internet connection"

# Check if huggingface-cli is available
if ! command -v huggingface-cli &> /dev/null; then
    log "Installing huggingface-hub..."
    pip3 install huggingface_hub
fi

# Download models
log "Downloading Qwen3-4B-Instruct (Agent)..."
huggingface-cli download Qwen/Qwen3-4B-GGUF qwen3-4b-instruct-q5_k_m.gguf --local-dir .

log "Downloading Qwen2.5-Coder-7B-Instruct (Coder)..."
huggingface-cli download Qwen/Qwen2.5-Coder-7B-Instruct-GGUF qwen2.5-coder-7b-instruct-q5_k_m.gguf --local-dir .

log "Downloading Qwen2-VL-7B-Instruct (Vision)..."
huggingface-cli download bartowski/Qwen2-VL-7B-Instruct-GGUF Qwen2-VL-7B-Instruct-Q5_K_M.gguf --local-dir .
huggingface-cli download bartowski/Qwen2-VL-7B-Instruct-GGUF mmproj-model-f16.gguf --local-dir .

log "Models downloaded successfully!"
log "You can now run: ./master_deploy.sh"