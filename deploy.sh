#!/bin/bash
# Optimized deployment script for Qwen Multimodal Agent
# Ensures 100% automated deployment with no container duplicates
set -e

VAULT_DIR="./vault"
MODELS_DIR="${VAULT_DIR}/models"
CONFIGS_DIR="${VAULT_DIR}/configs"
LOGS_DIR="${VAULT_DIR}/logs"
BACKUPS_DIR="${VAULT_DIR}/backups"
DEPLOY_LOG="${LOGS_DIR}/deploy.log"
DEPLOY_TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
exec > >(tee -a "$DEPLOY_LOG") 2>&1

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

error() {
    echo -e "${RED}✗ $1${NC}"
}

error_exit() {
    error "$1"
    exit 1
}

# Create required directories
setup_directories() {
    log "Setting up required directories..."
    mkdir -p "$MODELS_DIR" "$CONFIGS_DIR" "$LOGS_DIR" "$BACKUPS_DIR"
}

# Comprehensive container cleanup function
cleanup_containers() {
    local service_name="$1"
    log "Performing comprehensive cleanup for $service_name..."

    # Stop systemd service if running
    if systemctl is-active --quiet "qwen-${service_name}.service" 2>/dev/null; then
        log "Stopping systemd service qwen-${service_name}.service..."
        sudo systemctl stop "qwen-${service_name}.service" || true
    fi

    # Stop container if running (by name)
    if podman ps --format "{{.Names}}" | grep -q "^qwen-${service_name}$"; then
        log "Stopping running container qwen-${service_name}..."
        podman stop "qwen-${service_name}" || true
    fi

    # Remove container if exists
    if podman ps -a --format "{{.Names}}" | grep -q "^qwen-${service_name}$"; then
        log "Removing container qwen-${service_name}..."
        podman rm -f "qwen-${service_name}" || true
    fi

    # Remove any orphaned containers with similar names
    local orphaned=$(podman ps -a --format "{{.Names}}" | grep "^qwen-${service_name}" | grep -v "^qwen-${service_name}$" || true)
    if [ -n "$orphaned" ]; then
        log "Removing orphaned containers: $orphaned"
        echo "$orphaned" | xargs podman rm -f || true
    fi
}

# Check if container is healthy
check_container_health() {
    local container_name="$1"
    local port="$2"
    local max_attempts=30
    local attempt=1

    log "Checking health of $container_name on port $port..."

    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "http://localhost:$port/health" > /dev/null 2>&1; then
            success "$container_name is healthy"
            return 0
        fi

        log "Attempt $attempt/$max_attempts: $container_name not ready yet..."
        sleep 2
        ((attempt++))
    done

    error "$container_name failed health check after $max_attempts attempts"
    return 1
}

# Deploy single service with full lifecycle management
deploy_service() {
    local service_name="$1"
    local port="$2"
    local model_file="$3"
    local extra_args="$4"

    log "Deploying $service_name service..."

    # Comprehensive cleanup first
    cleanup_containers "$service_name"

    # Check if model exists (if required)
    if [ -n "$model_file" ] && [ ! -f "$model_file" ]; then
        warning "Model file $model_file not found, skipping $service_name deployment"
        return 0
    fi

    # Get absolute vault path
    local vault_abs_path=$(cd "$VAULT_DIR" && pwd)

    # Build container run command
    local run_cmd="podman run -d --name qwen-${service_name} --network qwen-network -v ${vault_abs_path}:/vault:z"

    # Add GPU device if available
    if [ -e /dev/dri ]; then
        run_cmd="$run_cmd --device /dev/dri:/dev/dri"
    fi

    # Add port mapping
    if [ -n "$port" ]; then
        run_cmd="$run_cmd -p $port:$port"
    fi

    # Add extra arguments
    if [ -n "$extra_args" ]; then
        run_cmd="$run_cmd $extra_args"
    fi

    # Add image name
    run_cmd="$run_cmd qwen-${service_name}:latest"

    log "Starting $service_name container..."
    log "Command: $run_cmd"

    if eval "$run_cmd"; then
        success "$service_name container started"

        # Health check if port is specified
        if [ -n "$port" ]; then
            if check_container_health "qwen-${service_name}" "$port"; then
                success "$service_name deployment completed successfully"
            else
                error "$service_name deployment failed - container unhealthy"
                # Attempt cleanup on failure
                cleanup_containers "$service_name"
                return 1
            fi
        else
            success "$service_name deployment completed (no health check required)"
        fi
    else
        error "Failed to start $service_name container"
        return 1
    fi
}

# System requirements check
check_requirements() {
    log "Checking system requirements..."

    # Check Podman
    if ! command -v podman &> /dev/null; then
        error_exit "Podman is not installed"
    fi

    # Check curl
    if ! command -v curl &> /dev/null; then
        error_exit "curl is not installed"
    fi

    # Check available memory
    local mem_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local mem_gb=$((mem_kb / 1024 / 1024))
    if [ $mem_gb -lt 8 ]; then
        error_exit "Insufficient memory: ${mem_gb}GB available, need at least 8GB"
    fi

    success "System requirements check passed"
}

# Network setup
setup_network() {
    log "Setting up podman network..."

    # Remove existing network if it exists
    podman network rm qwen-network 2>/dev/null || true

    # Create new network
    if podman network create qwen-network; then
        success "Network qwen-network created"
    else
        error_exit "Failed to create network"
    fi
}

# Backup current state before deployment
create_deployment_backup() {
    log "Creating pre-deployment backup..."

    local backup_file="${BACKUPS_DIR}/pre_deployment_${DEPLOY_TIMESTAMP}.tar.gz"

    # Backup vault directory
    if [ -d "$VAULT_DIR" ]; then
        tar -czf "$backup_file" -C "$VAULT_DIR" . 2>/dev/null || true
        success "Pre-deployment backup created: $backup_file"
    else
        warning "No vault directory to backup"
    fi
}

# Rollback function
rollback_deployment() {
    local reason="$1"
    error "Deployment failed: $reason"
    error "Initiating rollback..."

    # Stop all containers
    log "Stopping all containers..."
    podman stop $(podman ps -q) 2>/dev/null || true

    # Remove all containers
    log "Removing all containers..."
    podman rm -f $(podman ps -a -q) 2>/dev/null || true

    # Try to restore from backup if available
    local latest_backup=$(ls -t "${BACKUPS_DIR}"/pre_deployment_*.tar.gz 2>/dev/null | head -1)
    if [ -n "$latest_backup" ]; then
        log "Attempting to restore from backup: $latest_backup"
        cd "$VAULT_DIR" && tar -xzf "$latest_backup" 2>/dev/null || warning "Backup restore failed"
    fi

    error_exit "Deployment rolled back due to failure"
}

# Main deployment function
main() {
    log "Starting optimized deployment - $DEPLOY_TIMESTAMP"
    log "Ensuring 100% automated deployment with no duplicates"

    # Setup
    setup_directories
    check_requirements
    create_deployment_backup

    # Build containers first
    log "Building all containers..."
    if ! ./build.sh; then
        rollback_deployment "Container build failed"
    fi

    # Setup network
    setup_network

    # Deploy services in order
    local deployment_success=true

    # Deploy router first (no model dependency)
    if ! deploy_service "router" "" "" "--user root"; then
        deployment_success=false
    fi

    # Deploy coder (has model available)
    if [ -f "${MODELS_DIR}/qwen2.5-coder-7b-instruct-q5_k_m.gguf" ]; then
        if ! deploy_service "coder" "8081" "" "--user root"; then
            deployment_success=false
        fi
    else
        warning "Coder model not available, skipping coder deployment"
    fi

    # Deploy vision (has model available)
    if [ -f "${MODELS_DIR}/Qwen2-VL-7B-Instruct-Q5_K_M.gguf" ]; then
        if ! deploy_service "vision" "8082" "" "--user root"; then
            deployment_success=false
        fi
    else
        warning "Vision model not available, skipping vision deployment"
    fi

    # Deploy voice (check for model)
    if [ -f "${MODELS_DIR}/qwen2-audio-7b-q5_k_m.gguf" ]; then
        if ! deploy_service "voice" "8083" "" "--user root"; then
            deployment_success=false
        fi
    else
        warning "Voice model not available, skipping voice deployment"
    fi

    # Deploy agent (check for model)
    if [ -f "${MODELS_DIR}/qwen3-4b-instruct-q5_k_m.gguf" ]; then
        if ! deploy_service "agent" "8084" "" "--user root"; then
            deployment_success=false
        fi
    else
        warning "Agent model not available, skipping agent deployment"
    fi

    # Final verification
    if [ "$deployment_success" = true ]; then
        log "Running final deployment verification..."

        # List all running containers
        log "Currently running containers:"
        podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

        # Test basic connectivity
        local running_services=$(podman ps --format "{{.Names}}" | grep "^qwen-" | wc -l)
        if [ $running_services -gt 0 ]; then
            success "Deployment completed successfully!"
            success "Services deployed: $running_services"
            success "Deployment timestamp: $DEPLOY_TIMESTAMP"

            # Create deployment marker
            echo "$DEPLOY_TIMESTAMP" > "${LOGS_DIR}/last_successful_deployment"

            log "Services available at:"
            podman ps --format "{{.Names}}" | grep "^qwen-" | while read -r service; do
                local port=$(podman inspect "$service" --format "{{.NetworkSettings.Ports}}" | grep -o '"[0-9]*"' | head -1 | tr -d '"' || echo "internal")
                if [ "$port" != "internal" ]; then
                    log "  $service: http://localhost:$port"
                else
                    log "  $service: Internal container networking"
                fi
            done
        else
            rollback_deployment "No services are running after deployment"
        fi
    else
        rollback_deployment "One or more services failed to deploy"
    fi
}

# Handle script interruption
trap 'error "Deployment interrupted by user"; rollback_deployment "User interruption"' INT TERM

# Run main deployment
main "$@"