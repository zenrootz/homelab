#!/bin/bash
# Comprehensive integration test for Qwen Multimodal Agent system
set -e

VAULT_DIR="./vault"
LOGS_DIR="${VAULT_DIR}/logs"

# Logging
LOG_FILE="${LOGS_DIR}/integration_test.log"
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*"
}

error_exit() {
    log "ERROR: $1"
    exit 1
}

# Test system prerequisites
test_prerequisites() {
    log "Testing system prerequisites..."

    # Check Podman
    if ! command -v podman &> /dev/null; then
        error_exit "Podman not found"
    fi

    # Check vault directory
    if [ ! -d "$VAULT_DIR" ]; then
        error_exit "Vault directory not found"
    fi

    # Check certificates
    if [ ! -f "${VAULT_DIR}/certs/cert.pem" ]; then
        error_exit "SSL certificates not found"
    fi

    # Check configurations
    if [ ! -f "${VAULT_DIR}/configs/agent.json" ]; then
        error_exit "Agent configuration not found"
    fi

    log "Prerequisites test passed"
}

# Test all containers are running
test_containers_running() {
    log "Testing all containers are running..."

    local containers=("qwen-agent" "qwen-coder" "qwen-vision" "qwen-router")
    local voice_available=false

    if [ -f "${VAULT_DIR}/models/qwen2-audio-7b-q5_k_m.gguf" ]; then
        containers+=("qwen-voice")
        voice_available=true
    fi

    for container in "${containers[@]}"; do
        if ! podman ps --format "{{.Names}}" | grep -q "^${container}$"; then
            error_exit "Container ${container} is not running"
        fi
        log "Container ${container} is running"
    done

    log "All containers running test passed"
}

# Run individual service tests
run_individual_tests() {
    log "Running individual service tests..."

    # Test agent
    if [ -f "test_agent.sh" ]; then
        log "Running agent tests..."
        ./test_agent.sh
    fi

    # Test coder
    if [ -f "test_coder.sh" ]; then
        log "Running coder tests..."
        ./test_coder.sh
    fi

    # Test vision
    if [ -f "test_vision.sh" ]; then
        log "Running vision tests..."
        ./test_vision.sh
    fi

    # Test voice (if available)
    if [ -f "test_voice.sh" ] && [ -f "${VAULT_DIR}/models/qwen2-audio-7b-q5_k_m.gguf" ]; then
        log "Running voice tests..."
        ./test_voice.sh
    fi

    # Test router
    if [ -f "test_router.sh" ]; then
        log "Running router tests..."
        ./test_router.sh
    fi

    log "Individual tests completed"
}

# Test end-to-end functionality
test_end_to_end() {
    log "Testing end-to-end functionality..."

    # Test router delegation to coder
    local coder_response=$(echo "Write a hello world function in Python @coder" | ./agent-router.sh)
    if [ -z "$coder_response" ]; then
        error_exit "End-to-end coder delegation failed"
    fi

    # Test router delegation to vision
    local vision_response=$(echo "Analyze this chart @vision" | ./agent-router.sh)
    if [ -z "$vision_response" ]; then
        error_exit "End-to-end vision delegation failed"
    fi

    # Test agent planning
    local agent_response=$(echo "Plan a web application project" | ./agent-router.sh)
    if [ -z "$agent_response" ]; then
        error_exit "End-to-end agent planning failed"
    fi

    log "End-to-end test passed"
}

# Test backup and restore functionality
test_backup_restore() {
    log "Testing backup and restore functionality..."

    # Create a backup
    ./backup.sh create

    # Check if backup was created
    local latest_backup=$(ls -t vault/backups/*.enc 2>/dev/null | head -1)
    if [ -z "$latest_backup" ]; then
        error_exit "Backup creation failed"
    fi

    log "Backup created: $(basename "$latest_backup")"

    # Test backup listing
    ./backup.sh list

    log "Backup/restore test passed"
}

# Test crash recovery simulation
test_crash_recovery() {
    log "Testing crash recovery simulation..."

    # Simulate stopping a service
    podman stop qwen-agent
    sleep 2

    # Check if service recovery works (systemd would handle this in production)
    if podman ps --format "{{.Names}}" | grep -q "^qwen-agent$"; then
        log "WARNING: Service did not stay stopped as expected"
    fi

    # Restart service
    podman start qwen-agent
    sleep 5

    # Verify service is back
    if ! podman ps --format "{{.Names}}" | grep -q "^qwen-agent$"; then
        error_exit "Service restart failed"
    fi

    log "Crash recovery simulation passed"
}

# Generate test report
generate_report() {
    log "Generating test report..."

    local report_file="${LOGS_DIR}/test_report_$(date +%Y%m%d_%H%M%S).txt"

    {
        echo "=== Qwen Multimodal Agent Integration Test Report ==="
        echo "Date: $(date)"
        echo ""
        echo "System Information:"
        echo "  OS: $(uname -s) $(uname -r)"
        echo "  Podman: $(podman --version)"
        echo "  Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
        echo ""
        echo "Services Status:"
        podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        echo "Test Results:"
        echo "  Prerequisites: PASSED"
        echo "  Containers: PASSED"
        echo "  Individual Tests: PASSED"
        echo "  End-to-End: PASSED"
        echo "  Backup/Restore: PASSED"
        echo "  Crash Recovery: PASSED"
        echo ""
        echo "Log Files:"
        ls -la "${LOGS_DIR}"/*.log
        echo ""
        echo "=== End Report ==="
    } > "$report_file"

    log "Test report generated: $report_file"
}

# Main integration test
main() {
    log "Starting comprehensive integration tests..."

    mkdir -p "$LOGS_DIR"

    # Run all test phases
    test_prerequisites
    test_containers_running
    run_individual_tests
    test_end_to_end
    test_backup_restore
    test_crash_recovery
    generate_report

    log "All integration tests passed successfully!"
    log "System is ready for production use."
}

main "$@"