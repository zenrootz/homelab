#!/bin/bash
# Comprehensive cleanup script for Qwen Multimodal Agent
# Ensures no duplicate containers or orphaned resources
set -e

VAULT_DIR="./vault"
LOGS_DIR="${VAULT_DIR}/logs"
CLEANUP_LOG="${LOGS_DIR}/cleanup.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
exec > >(tee -a "$CLEANUP_LOG") 2>&1

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

# Create logs directory
mkdir -p "$LOGS_DIR"

log "Starting comprehensive cleanup..."

# Stop and remove all qwen-related containers
cleanup_containers() {
    log "Cleaning up containers..."

    local containers=$(podman ps -a --format "{{.Names}}" | grep "^qwen-" || true)
    if [ -n "$containers" ]; then
        log "Found containers to clean: $containers"
        echo "$containers" | xargs podman stop 2>/dev/null || true
        echo "$containers" | xargs podman rm -f 2>/dev/null || true
        success "Containers cleaned up"
    else
        success "No containers to clean"
    fi
}

# Stop systemd services
cleanup_systemd_services() {
    log "Checking systemd services..."

    local services=("qwen-agent" "qwen-coder" "qwen-vision" "qwen-voice" "qwen-router" "qwen-network")
    local stopped_services=()

    for service in "${services[@]}"; do
        if systemctl is-active --quiet "${service}.service" 2>/dev/null; then
            log "Stopping systemd service: ${service}.service"
            sudo systemctl stop "${service}.service" || true
            stopped_services+=("$service")
        fi
    done

    if [ ${#stopped_services[@]} -gt 0 ]; then
        success "Stopped systemd services: ${stopped_services[*]}"
    else
        success "No systemd services were running"
    fi
}

# Clean up old images (keep only latest)
cleanup_images() {
    log "Cleaning up old container images..."

    local image_names=("qwen-base" "qwen-agent" "qwen-coder" "qwen-vision" "qwen-voice" "qwen-router")

    for image_name in "${image_names[@]}"; do
        log "Cleaning up $image_name images..."

        # Get all images for this service
        local images=$(podman images --format "{{.Repository}}:{{.Tag}}" | grep "^${image_name}:" | sort -V || true)

        if [ -n "$images" ]; then
            # Count images
            local image_count=$(echo "$images" | wc -l)

            if [ $image_count -gt 1 ]; then
                # Keep latest, remove others
                local latest_image=$(echo "$images" | tail -1)
                local old_images=$(echo "$images" | head -n $((image_count - 1)))

                log "Keeping: $latest_image"
                log "Removing: $old_images"

                echo "$old_images" | xargs podman rmi -f 2>/dev/null || true
            else
                log "Only one $image_name image found, keeping it"
            fi
        else
            warning "No $image_name images found"
        fi
    done

    success "Image cleanup completed"
}

# Clean up networks
cleanup_networks() {
    log "Cleaning up networks..."

    # Remove qwen-network if it exists
    if podman network ls --format "{{.Name}}" | grep -q "^qwen-network$"; then
        log "Removing qwen-network..."
        podman network rm qwen-network 2>/dev/null || true
        success "Network cleaned up"
    else
        success "No networks to clean"
    fi
}

# Clean up orphaned resources
cleanup_orphaned() {
    log "Cleaning up orphaned resources..."

    # Remove dangling images
    local dangling=$(podman images --filter "dangling=true" -q 2>/dev/null || true)
    if [ -n "$dangling" ]; then
        log "Removing dangling images..."
        echo "$dangling" | xargs podman rmi -f 2>/dev/null || true
    fi

    # Remove unused volumes (be careful with this)
    warning "Skipping volume cleanup - manual inspection recommended"

    success "Orphaned resource cleanup completed"
}

# Clean up old log files
cleanup_logs() {
    log "Cleaning up old log files..."

    # Keep only last 10 deployment logs
    if [ -d "$LOGS_DIR" ]; then
        local log_files=$(ls -t "${LOGS_DIR}"/deploy*.log 2>/dev/null | tail -n +11 || true)
        if [ -n "$log_files" ]; then
            log "Removing old deployment logs: $log_files"
            echo "$log_files" | xargs rm -f || true
        fi

        # Keep only last 5 cleanup logs
        local cleanup_logs=$(ls -t "${LOGS_DIR}"/cleanup*.log 2>/dev/null | tail -n +6 || true)
        if [ -n "$cleanup_logs" ]; then
            log "Removing old cleanup logs: $cleanup_logs"
            echo "$cleanup_logs" | xargs rm -f || true
        fi
    fi

    success "Log cleanup completed"
}

# Clean up old backups (keep last 5)
cleanup_backups() {
    log "Cleaning up old backups..."

    local backups_dir="${VAULT_DIR}/backups"
    if [ -d "$backups_dir" ]; then
        local old_backups=$(ls -t "${backups_dir}"/*.tar.gz 2>/dev/null | tail -n +6 || true)
        if [ -n "$old_backups" ]; then
            log "Removing old backups: $old_backups"
            echo "$old_backups" | xargs rm -f || true
        fi
    fi

    success "Backup cleanup completed"
}

# Verify cleanup
verify_cleanup() {
    log "Verifying cleanup..."

    local issues_found=0

    # Check for remaining qwen containers
    local remaining_containers=$(podman ps -a --format "{{.Names}}" | grep "^qwen-" || true)
    if [ -n "$remaining_containers" ]; then
        warning "Remaining containers found: $remaining_containers"
        ((issues_found++))
    fi

    # Check for running qwen services
    local services=("qwen-agent" "qwen-coder" "qwen-vision" "qwen-voice" "qwen-router" "qwen-network")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "${service}.service" 2>/dev/null; then
            warning "Service still running: ${service}.service"
            ((issues_found++))
        fi
    done

    if [ $issues_found -eq 0 ]; then
        success "Cleanup verification passed - no issues found"
    else
        warning "Cleanup verification found $issues_found issues"
    fi
}

# Main cleanup function
main() {
    log "Starting comprehensive cleanup process"

    # Run cleanup steps
    cleanup_systemd_services
    cleanup_containers
    cleanup_networks
    cleanup_images
    cleanup_orphaned
    cleanup_logs
    cleanup_backups
    verify_cleanup

    success "Comprehensive cleanup completed successfully"
    log "System is now ready for fresh deployment"
}

# Run cleanup
main "$@"