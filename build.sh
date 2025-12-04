#!/bin/bash
# Optimized build script for Qwen Multimodal Agent containers
# Ensures no duplicate images and proper cleanup
set -e

VAULT_DIR="./vault"
LOGS_DIR="${VAULT_DIR}/logs"
LOG_FILE="${LOGS_DIR}/build.log"
BUILD_TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Logging
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - BUILD: $*"
}

error_exit() {
    log "ERROR: $1"
    exit 1
}

# Create logs directory if it doesn't exist
mkdir -p "$LOGS_DIR"

log "Starting optimized container build process..."

# Function to safely remove old images
cleanup_old_images() {
    local image_name="$1"
    log "Cleaning up old $image_name images..."

    # Get all images with this name (excluding latest if it exists)
    local old_images=$(podman images --format "{{.Repository}}:{{.Tag}}" | grep "${image_name}:" | grep -v ":latest$" || true)

    if [ -n "$old_images" ]; then
        log "Removing old $image_name images: $old_images"
        echo "$old_images" | xargs podman rmi -f 2>/dev/null || true
    fi
}

# Function to build container with duplicate prevention
build_container() {
    local dockerfile="$1"
    local image_name="$2"
    local service_name="$3"

    log "Building $service_name container..."

    # Tag current latest as previous before building
    if podman images --format "{{.Repository}}:{{.Tag}}" | grep -q "${image_name}:latest$"; then
        log "Tagging current $image_name:latest as previous..."
        # Find the full image name with localhost prefix
        local full_image_name=$(podman images --format "{{.Repository}}:{{.Tag}}" | grep "${image_name}:latest$" | head -1)
        if [ -n "$full_image_name" ]; then
            podman tag "$full_image_name" "${image_name}:previous_${BUILD_TIMESTAMP}" 2>/dev/null || true
        fi
    fi

    # Build new image
    if [ "$dockerfile" = "Dockerfile" ]; then
        podman build -t "${image_name}:latest" .
    else
        podman build -f "$dockerfile" -t "${image_name}:latest" .
    fi

    # Verify build succeeded
    if ! podman images --format "{{.Repository}}:{{.Tag}}" | grep -q "${image_name}:latest$"; then
        error_exit "Failed to build $service_name container"
    fi

    # Clean up old images (keep only latest and one previous)
    cleanup_old_images "$image_name"

    log "$service_name container built successfully"
}

# Check if we're in the right directory
if [ ! -f "Dockerfile" ]; then
    error_exit "Dockerfile not found. Please run from project root directory."
fi

# Build base container first
build_container "Dockerfile" "qwen-base" "base llama.cpp"

# Build service-specific containers
build_container "Dockerfile.agent" "qwen-agent" "agent"
build_container "Dockerfile.coder" "qwen-coder" "coder"
build_container "Dockerfile.vision" "qwen-vision" "vision"
build_container "Dockerfile.voice" "qwen-voice" "voice"
build_container "Dockerfile.router" "qwen-router" "router"

# Final verification
log "Verifying all containers built successfully..."
expected_containers=("qwen-base:latest" "qwen-agent:latest" "qwen-coder:latest" "qwen-vision:latest" "qwen-voice:latest" "qwen-router:latest")
for container in "${expected_containers[@]}"; do
    if ! podman images --format "{{.Repository}}:{{.Tag}}" | grep -q "${container}$"; then
        error_exit "Container $container not found after build"
    fi
done

log "All containers built and verified successfully!"
log "Build timestamp: $BUILD_TIMESTAMP"