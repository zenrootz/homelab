#!/bin/bash
# Secrets management script for Qwen Multimodal Agent
# Provides encrypted storage and retrieval of sensitive data
set -e

VAULT_DIR="./vault"
SECRETS_DIR="${VAULT_DIR}/secrets"
KEY_FILE="${VAULT_DIR}/secrets.key"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

error() {
    echo -e "${RED}✗ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Generate or load encryption key
ensure_key() {
    if [ ! -f "$KEY_FILE" ]; then
        log "Generating new encryption key..."
        openssl rand -base64 32 > "$KEY_FILE"
        chmod 600 "$KEY_FILE"
        success "Encryption key generated"
    fi
    echo "$KEY_FILE"
}

# Encrypt a secret
encrypt_secret() {
    local secret_name="$1"
    local secret_value="$2"
    local key_file=$(ensure_key)

    log "Encrypting secret: $secret_name"

    # Create temporary file with secret
    local temp_file=$(mktemp)
    echo -n "$secret_value" > "$temp_file"

    # Encrypt the secret
    openssl enc -aes-256-cbc -salt -in "$temp_file" -out "${SECRETS_DIR}/${secret_name}.enc" -kfile "$key_file"

    # Clean up
    rm -f "$temp_file"

    success "Secret encrypted: $secret_name"
}

# Decrypt a secret
decrypt_secret() {
    local secret_name="$1"
    local key_file=$(ensure_key)

    if [ ! -f "${SECRETS_DIR}/${secret_name}.enc" ]; then
        error "Secret not found: $secret_name"
        return 1
    fi

    log "Decrypting secret: $secret_name"
    openssl enc -d -aes-256-cbc -in "${SECRETS_DIR}/${secret_name}.enc" -kfile "$key_file"
}

# List all secrets
list_secrets() {
    log "Available secrets:"
    if [ -d "$SECRETS_DIR" ]; then
        for secret_file in "${SECRETS_DIR}"/*.enc; do
            if [ -f "$secret_file" ]; then
                local secret_name=$(basename "$secret_file" .enc)
                echo "  - $secret_name"
            fi
        done
    else
        warning "No secrets directory found"
    fi
}

# Delete a secret
delete_secret() {
    local secret_name="$1"

    if [ ! -f "${SECRETS_DIR}/${secret_name}.enc" ]; then
        error "Secret not found: $secret_name"
        return 1
    fi

    log "Deleting secret: $secret_name"
    rm -f "${SECRETS_DIR}/${secret_name}.enc"
    success "Secret deleted: $secret_name"
}

# Initialize secrets vault
init_vault() {
    log "Initializing secrets vault..."

    mkdir -p "$SECRETS_DIR"
    ensure_key

    # Set proper permissions
    chmod 700 "$VAULT_DIR"
    chmod 700 "$SECRETS_DIR"
    chmod 600 "$KEY_FILE"

    success "Secrets vault initialized"
}

# Backup secrets
backup_secrets() {
    local backup_file="${VAULT_DIR}/backups/secrets_backup_$(date +%Y%m%d_%H%M%S).tar.gz"

    log "Creating secrets backup..."

    mkdir -p "${VAULT_DIR}/backups"
    tar -czf "$backup_file" -C "$VAULT_DIR" secrets/ secrets.key

    success "Secrets backup created: $backup_file"
}

# Restore secrets from backup
restore_secrets() {
    local backup_file="$1"

    if [ ! -f "$backup_file" ]; then
        error "Backup file not found: $backup_file"
        return 1
    fi

    log "Restoring secrets from backup..."

    # Create backup of current secrets
    if [ -d "$SECRETS_DIR" ]; then
        backup_secrets
    fi

    # Extract backup
    mkdir -p "$SECRETS_DIR"
    tar -xzf "$backup_file" -C "$VAULT_DIR"

    success "Secrets restored from backup"
}

# Generate API keys
generate_api_key() {
    local service_name="$1"
    local key_length="${2:-32}"

    log "Generating API key for $service_name..."

    local api_key=$(openssl rand -hex "$key_length")
    encrypt_secret "${service_name}_api_key" "$api_key"

    echo "Generated API key for $service_name (encrypted)"
}

# Setup common secrets
setup_common_secrets() {
    log "Setting up common secrets..."

    # Generate API keys for services
    generate_api_key "openai"
    generate_api_key "anthropic"
    generate_api_key "huggingface"
    generate_api_key "github"

    # Database credentials
    read -p "Enter database password (leave empty to skip): " -s db_password
    echo
    if [ -n "$db_password" ]; then
        encrypt_secret "database_password" "$db_password"
    fi

    # Email credentials for alerts
    read -p "Enter SMTP username (leave empty to skip): " smtp_user
    if [ -n "$smtp_user" ]; then
        read -p "Enter SMTP password: " -s smtp_pass
        echo
        encrypt_secret "smtp_username" "$smtp_user"
        encrypt_secret "smtp_password" "$smtp_pass"
    fi

    success "Common secrets setup completed"
}

# Main command dispatcher
main() {
    local command="$1"
    shift

    case "$command" in
        init)
            init_vault
            ;;
        set)
            local secret_name="$1"
            local secret_value="$2"
            if [ -z "$secret_name" ] || [ -z "$secret_value" ]; then
                error "Usage: $0 set <name> <value>"
                exit 1
            fi
            encrypt_secret "$secret_name" "$secret_value"
            ;;
        get)
            local secret_name="$1"
            if [ -z "$secret_name" ]; then
                error "Usage: $0 get <name>"
                exit 1
            fi
            decrypt_secret "$secret_name"
            ;;
        list)
            list_secrets
            ;;
        delete)
            local secret_name="$1"
            if [ -z "$secret_name" ]; then
                error "Usage: $0 delete <name>"
                exit 1
            fi
            delete_secret "$secret_name"
            ;;
        backup)
            backup_secrets
            ;;
        restore)
            local backup_file="$1"
            if [ -z "$backup_file" ]; then
                error "Usage: $0 restore <backup_file>"
                exit 1
            fi
            restore_secrets "$backup_file"
            ;;
        setup)
            setup_common_secrets
            ;;
        help|*)
            echo "Qwen Secrets Management Tool"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  init                    Initialize secrets vault"
            echo "  set <name> <value>      Store a secret"
            echo "  get <name>              Retrieve a secret"
            echo "  list                    List all secrets"
            echo "  delete <name>           Delete a secret"
            echo "  backup                  Create secrets backup"
            echo "  restore <file>          Restore from backup"
            echo "  setup                   Setup common secrets interactively"
            echo "  help                    Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 init"
            echo "  $0 set api_key 'my-secret-key'"
            echo "  $0 get api_key"
            echo "  $0 setup"
            ;;
    esac
}

# Run main function
main "$@"