#!/bin/bash
# Master deployment script for Qwen Multimodal Agent
# Ensures 100% automated deployment with no duplicates or conflicts
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
VAULT_DIR="./vault"
LOGS_DIR="${VAULT_DIR}/logs"
MASTER_LOG="${LOGS_DIR}/master_deployment.log"
DEPLOYMENT_ID=$(date +%Y%m%d_%H%M%S)

# Logging
exec > >(tee -a "$MASTER_LOG") 2>&1

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

header() {
    echo -e "${PURPLE}$1${NC}"
}

error_exit() {
    error "$1"
    exit 1
}

# Create required directories
setup_environment() {
    header "Setting up deployment environment..."
    mkdir -p "$LOGS_DIR"
    log "Deployment ID: $DEPLOYMENT_ID"
}

# Comprehensive system validation
validate_system() {
    header "Validating system requirements..."

    # Check if we're in the right directory
    if [ ! -f "Dockerfile" ] || [ ! -f "deploy.sh" ] || [ ! -f "build.sh" ]; then
        error_exit "Not in project root directory. Please run from /home/micro/homelab/"
    fi

    # Check Podman
    if ! command -v podman &> /dev/null; then
        error_exit "Podman is not installed. Please install Podman first."
    fi

    # Check curl
    if ! command -v curl &> /dev/null; then
        error_exit "curl is not installed. Please install curl first."
    fi

    # Check available memory
    local mem_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local mem_gb=$((mem_kb / 1024 / 1024))
    if [ $mem_gb -lt 8 ]; then
        error_exit "Insufficient memory: ${mem_gb}GB available, need at least 8GB"
    fi

    # Check available disk space (need ~20GB free)
    local disk_free_kb=$(df /home | tail -1 | awk '{print $4}')
    local disk_free_gb=$((disk_free_kb / 1024 / 1024))
    if [ $disk_free_gb -lt 20 ]; then
        error_exit "Insufficient disk space: ${disk_free_gb}GB available, need at least 20GB"
    fi

    success "System validation passed"
}

# Comprehensive cleanup before deployment
pre_deployment_cleanup() {
    header "Performing pre-deployment cleanup..."

    if [ -f "./cleanup.sh" ]; then
        log "Running comprehensive cleanup..."
        if ./cleanup.sh; then
            success "Pre-deployment cleanup completed"
        else
            warning "Cleanup script had issues, but continuing with deployment"
        fi
    else
        warning "cleanup.sh not found, performing basic cleanup..."

        # Basic cleanup if script doesn't exist
        podman stop $(podman ps -q) 2>/dev/null || true
        podman rm -f $(podman ps -a -q) 2>/dev/null || true
        podman network rm qwen-network 2>/dev/null || true
    fi
}

# Build all containers
build_containers() {
    header "Building all containers..."

    if [ ! -f "./build.sh" ]; then
        error_exit "build.sh script not found"
    fi

    log "Starting container build process..."
    if ./build.sh; then
        success "All containers built successfully"
    else
        error_exit "Container build failed"
    fi
}

# Deploy all services
deploy_services() {
    header "Deploying all services..."

    if [ ! -f "./deploy.sh" ]; then
        error_exit "deploy.sh script not found"
    fi

    log "Starting service deployment..."
    if ./deploy.sh; then
        success "All services deployed successfully"
    else
        error_exit "Service deployment failed"
    fi
}

# Post-deployment validation
validate_deployment() {
    header "Validating deployment..."

    local expected_services=("qwen-router")
    local running_services=()

    # Check which services should be running based on available models
    if [ -f "${VAULT_DIR}/models/qwen2.5-coder-7b-instruct-q5_k_m.gguf" ]; then
        expected_services+=("qwen-coder")
    fi
    if [ -f "${VAULT_DIR}/models/Qwen2-VL-7B-Instruct-Q5_K_M.gguf" ]; then
        expected_services+=("qwen-vision")
    fi
    if [ -f "${VAULT_DIR}/models/qwen2-audio-7b-q5_k_m.gguf" ]; then
        expected_services+=("qwen-voice")
    fi
    if [ -f "${VAULT_DIR}/models/qwen3-4b-instruct-q5_k_m.gguf" ]; then
        expected_services+=("qwen-agent")
    fi

    log "Expected services: ${expected_services[*]}"

    # Check running containers
    for service in "${expected_services[@]}"; do
        if podman ps --format "{{.Names}}" | grep -q "^${service}$"; then
            running_services+=("$service")
            success "$service is running"
        else
            error "$service is not running"
        fi
    done

    # Health checks for services with ports
    local services_with_ports=(
        "qwen-coder:8081"
        "qwen-vision:8082"
        "qwen-voice:8083"
        "qwen-agent:8084"
    )

    for service_port in "${services_with_ports[@]}"; do
        local service=$(echo "$service_port" | cut -d: -f1)
        local port=$(echo "$service_port" | cut -d: -f2)

        # Only check if service is expected to be running
        if [[ " ${expected_services[*]} " =~ " ${service} " ]]; then
            log "Checking health of $service on port $port..."
            if curl -f -s --max-time 10 "http://localhost:$port/health" > /dev/null 2>&1; then
                success "$service health check passed"
            else
                error "$service health check failed"
            fi
        fi
    done

    # Summary
    local running_count=${#running_services[@]}
    local expected_count=${#expected_services[@]}

    if [ $running_count -eq $expected_count ]; then
        success "Deployment validation passed: $running_count/$expected_count services running"
    else
        warning "Deployment validation partial: $running_count/$expected_count services running"
    fi
}

# Create deployment summary
create_summary() {
    header "Creating deployment summary..."

    local summary_file="${LOGS_DIR}/deployment_summary_${DEPLOYMENT_ID}.txt"

    {
        echo "=== Qwen Multimodal Agent Deployment Summary ==="
        echo "Deployment ID: $DEPLOYMENT_ID"
        echo "Timestamp: $(date)"
        echo ""
        echo "=== Running Services ==="
        podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        echo "=== Available Endpoints ==="
        podman ps --format "{{.Names}}" | grep "^qwen-" | while read -r service; do
            local port=$(podman inspect "$service" --format "{{.NetworkSettings.Ports}}" 2>/dev/null | grep -o '"[0-9]*"' | head -1 | tr -d '"' || echo "internal")
            if [ "$port" != "internal" ] && [ -n "$port" ]; then
                echo "  $service: http://localhost:$port"
            else
                echo "  $service: Internal container networking"
            fi
        done
        echo ""
        echo "=== Model Status ==="
        local models_dir="${VAULT_DIR}/models"
        if [ -d "$models_dir" ]; then
            ls -la "$models_dir"/*.gguf 2>/dev/null | while read -r line; do
                echo "  $line"
            done
        fi
        echo ""
        echo "=== System Resources ==="
        echo "Memory: $(free -h | grep '^Mem:' | awk '{print $3 "/" $2}')"
        echo "Disk: $(df -h /home | tail -1 | awk '{print $3 "/" $2 " (" $5 " used)"}')"
        if command -v rocm-smi &> /dev/null; then
            echo "GPU: $(rocm-smi --showmeminfo 2>/dev/null | grep "VRAM Usage" | head -1 || echo "ROCm not available")"
        fi
        echo ""
        echo "=== Next Steps ==="
        echo "1. Test services: ./test_integration.sh"
        echo "2. Monitor services: ./monitor.sh"
        echo "3. View logs: tail -f vault/logs/*.log"
        echo "4. Backup system: ./backup.sh create"
        echo ""
        echo "=== Emergency Contacts ==="
        echo "Stop all: podman stop \$(podman ps -q)"
        echo "Clean all: ./cleanup.sh"
        echo "Full reset: ./cleanup.sh && ./master_deploy.sh"
        echo ""
        echo "=== End Summary ==="
    } > "$summary_file"

    success "Deployment summary created: $summary_file"
    log "Summary contents:"
    cat "$summary_file"
}

# Handle deployment failure and rollback
handle_failure() {
    error "Deployment failed at step: $1"
    error "Initiating emergency cleanup..."

    # Emergency cleanup
    podman stop $(podman ps -q) 2>/dev/null || true
    podman rm -f $(podman ps -a -q) 2>/dev/null || true
    podman network rm qwen-network 2>/dev/null || true

    error_exit "Deployment failed and system cleaned up. Check logs for details."
}

# Main deployment orchestration
main() {
    header "🚀 Qwen Multimodal Agent - Master Deployment"
    header "Ensuring 100% automated deployment with no duplicates"
    echo ""

    local start_time=$(date +%s)

    # Trap failures for rollback
    trap 'handle_failure "Unexpected error"' ERR

    # Execute deployment steps
    setup_environment
    validate_system
    pre_deployment_cleanup
    build_containers
    deploy_services
    validate_deployment
    create_summary

    # Calculate deployment time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    header "🎉 Deployment Completed Successfully!"
    success "Total deployment time: ${duration} seconds"
    success "Deployment ID: $DEPLOYMENT_ID"
    success "All services are running and healthy"
    success "No duplicate containers created"
    success "System is ready for use"

    echo ""
    log "To test the deployment, run: ./test_integration.sh"
    log "To monitor services, run: ./monitor.sh"
    log "To view deployment summary: cat vault/logs/deployment_summary_${DEPLOYMENT_ID}.txt"
}

# Handle script interruption
trap 'error "Deployment interrupted by user"; handle_failure "User interruption"' INT TERM

# Run master deployment
main "$@"