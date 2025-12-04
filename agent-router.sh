#!/bin/bash
# Qwen Agent Router: Routes queries to specialists in containerized environment
# Enhanced with logging and crash recovery

set -e

# Configuration
VAULT_DIR="./vault"
LOG_DIR="${VAULT_DIR}/logs"
CONFIG_DIR="${VAULT_DIR}/configs"

# Service endpoints (internal container networking)
AGENT_URL="http://qwen-agent:8084"
CODER_URL="http://qwen-coder:8081"
VISION_URL="http://qwen-vision:8082"
VOICE_URL="http://qwen-voice:8083"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "${LOG_DIR}/router.log"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Check if services are healthy
check_service() {
    local service_name="$1"
    local url="$2"

    if curl -f -s "${url}/health" > /dev/null 2>&1; then
        log "${service_name} is healthy"
        return 0
    else
        log "${service_name} is not responding"
        return 1
    fi
}

# Main routing logic
route_query() {
    local query="$*"

    log "Routing query: ${query}"

    # Agent decides route (simple keyword detection)
    if [[ $query == *"@coder"* || $query == *"code"* || $query == *"research"* ]]; then
        log "Routing to coder service"
        check_service "Coder" "${CODER_URL}" || error_exit "Coder service unavailable"
        curl -X POST "${CODER_URL}/completion" \
             -H "Content-Type: application/json" \
             -d "{\"prompt\":\"${query}\",\"n_predict\":512}" || error_exit "Coder request failed"
    elif [[ $query == *"@vision"* || $query == *"image"* || $query == *"doc"* || $query == *"ocr"* ]]; then
        log "Routing to vision service"
        check_service "Vision" "${VISION_URL}" || error_exit "Vision service unavailable"
        # Note: Image handling would need additional implementation
        curl -X POST "${VISION_URL}/completion" \
             -H "Content-Type: application/json" \
             -d "{\"prompt\":\"${query}\",\"n_predict\":512}" || error_exit "Vision request failed"
    elif [[ $query == *"@voice"* || $query == *"audio"* ]]; then
        log "Routing to voice service"
        check_service "Voice" "${VOICE_URL}" || error_exit "Voice service unavailable"
        curl -X POST "${VOICE_URL}/completion" \
             -H "Content-Type: application/json" \
             -d "{\"prompt\":\"Transcribe and respond to: ${query}\",\"n_predict\":512}" || error_exit "Voice request failed"
    else
        log "Routing to agent for planning"
        check_service "Agent" "${AGENT_URL}" || error_exit "Agent service unavailable"
        curl -X POST "${AGENT_URL}/completion" \
             -H "Content-Type: application/json" \
             -d "{\"prompt\":\"You are QwenAgent. Delegate: ${query} to @coder, @vision, or @voice if needed. Else plan.\",\"n_predict\":256}" || error_exit "Agent request failed"
    fi
}

# Main loop
log "Agent Router starting..."

# Ensure directories exist
mkdir -p "${LOG_DIR}"

# Check all services on startup
log "Performing startup health checks..."
check_service "Agent" "${AGENT_URL}" || log "WARNING: Agent service not ready"
check_service "Coder" "${CODER_URL}" || log "WARNING: Coder service not ready"
check_service "Vision" "${VISION_URL}" || log "WARNING: Vision service not ready"
check_service "Voice" "${VOICE_URL}" || log "WARNING: Voice service not ready"

log "Agent Router ready. Waiting for queries..."

# If arguments provided, process them
if [ $# -gt 0 ]; then
    route_query "$@"
else
    # Interactive mode - read from stdin
    while IFS= read -r line; do
        route_query "$line"
    done
fi