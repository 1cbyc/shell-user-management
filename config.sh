#!/bin/bash

set -euo pipefail

SCRIPT_NAME=$(basename "$0")
CONFIG_FILE="/etc/user_management/user_management.conf"
DEFAULT_CONFIG_FILE="/etc/user_management/user_management.conf.default"

log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S %Z')
    echo "[$timestamp] [$level] [$SCRIPT_NAME] $message" >> "/var/log/user_management.log"
}

validate_root_privileges() {
    if [[ "${UID}" -ne 0 ]]; then
        log_message "ERROR" "Script executed without root privileges"
        echo "Error: This script must be executed with root privileges" >&2
        exit 1
    fi
    log_message "INFO" "Root privileges validated"
}

create_default_config() {
    cat > "$DEFAULT_CONFIG_FILE" << 'EOF'
# User Management System Configuration
# ===================================

# Logging Configuration
# ---------------------
LOG_LEVEL=INFO
LOG_FILE=/var/log/user_management.log
LOG_MAX_SIZE=10MB
LOG_RETENTION_DAYS=30
LOG_ROTATION_ENABLED=true

# Security Configuration
# ----------------------
DEFAULT_PASSWORD_LENGTH=12
PASSWORD_COMPLEXITY=true
PASSWORD_EXPIRY_DAYS=90
PASSWORD_WARNING_DAYS=7
ACCOUNT_LOCKOUT_ATTEMPTS=5
ACCOUNT_LOCKOUT_DURATION=30
SESSION_TIMEOUT_MINUTES=30

# User Creation Configuration
# ---------------------------
DEFAULT_SHELL=/bin/bash
DEFAULT_HOME_DIR=/home
DEFAULT_GROUP=users
UID_MIN=1000
UID_MAX=60000
GID_MIN=1000
GID_MAX=60000
CREATE_HOME_DIR=true
COPY_SKELETON_FILES=true
FORCE_PASSWORD_CHANGE=true

# Backup Configuration
# --------------------
BACKUP_DIR=/var/backups/user_management
BACKUP_RETENTION_DAYS=30
BACKUP_COMPRESSION=true
BACKUP_ENCRYPTION=false
BACKUP_VERIFICATION=true
INCREMENTAL_BACKUP_ENABLED=true

# System Integration
# ------------------
LDAP_INTEGRATION=false
LDAP_SERVER=
LDAP_BASE_DN=
LDAP_BIND_DN=
LDAP_BIND_PASSWORD=
ACTIVE_DIRECTORY_INTEGRATION=false
AD_SERVER=
AD_DOMAIN=
AD_USERNAME=
AD_PASSWORD=

# Notification Configuration
# --------------------------
EMAIL_NOTIFICATIONS=false
SMTP_SERVER=
SMTP_PORT=587
SMTP_USERNAME=
SMTP_PASSWORD=
NOTIFICATION_EMAIL=
SLACK_WEBHOOK_URL=
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=

# Monitoring Configuration
# ------------------------
MONITORING_ENABLED=true
METRICS_COLLECTION=true
HEALTH_CHECK_INTERVAL=300
ALERT_THRESHOLDS=80
PERFORMANCE_MONITORING=true

# API Configuration
# -----------------
API_ENABLED=false
API_PORT=8080
API_HOST=localhost
API_AUTHENTICATION=true
API_RATE_LIMITING=true
API_RATE_LIMIT=100
API_TIMEOUT=30

# Database Configuration
# ----------------------
DATABASE_ENABLED=false
DATABASE_TYPE=sqlite
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=user_management
DATABASE_USERNAME=
DATABASE_PASSWORD=
DATABASE_SSL_MODE=require

# Compliance Configuration
# ------------------------
AUDIT_TRAIL_ENABLED=true
COMPLIANCE_REPORTING=true
SOX_COMPLIANCE=false
HIPAA_COMPLIANCE=false
GDPR_COMPLIANCE=false
ISO_27001_COMPLIANCE=false

# Performance Configuration
# -------------------------
MAX_CONCURRENT_OPERATIONS=10
OPERATION_TIMEOUT=300
CACHE_ENABLED=true
CACHE_SIZE=100MB
CACHE_TTL=3600
ASYNC_OPERATIONS=true

# Development Configuration
# -------------------------
DEBUG_MODE=false
VERBOSE_LOGGING=false
TEST_MODE=false
DRY_RUN=false
SIMULATION_MODE=false
EOF

    log_message "INFO" "Default configuration file created: $DEFAULT_CONFIG_FILE"
}

load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        if [[ -f "$DEFAULT_CONFIG_FILE" ]]; then
            cp "$DEFAULT_CONFIG_FILE" "$CONFIG_FILE"
            log_message "INFO" "Configuration file created from default: $CONFIG_FILE"
        else
            create_default_config
            cp "$DEFAULT_CONFIG_FILE" "$CONFIG_FILE"
            log_message "INFO" "Configuration file created: $CONFIG_FILE"
        fi
    fi
    
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        log_message "INFO" "Configuration loaded from: $CONFIG_FILE"
    else
        log_message "ERROR" "Failed to load configuration file: $CONFIG_FILE"
        exit 1
    fi
}

validate_config() {
    local errors=0
    
    if [[ ! "$LOG_LEVEL" =~ ^(DEBUG|INFO|WARN|ERROR)$ ]]; then
        echo "Error: Invalid LOG_LEVEL: $LOG_LEVEL" >&2
        ((errors++))
    fi
    
    if [[ ! "$DEFAULT_PASSWORD_LENGTH" =~ ^[0-9]+$ ]] || [[ "$DEFAULT_PASSWORD_LENGTH" -lt 8 ]] || [[ "$DEFAULT_PASSWORD_LENGTH" -gt 32 ]]; then
        echo "Error: Invalid DEFAULT_PASSWORD_LENGTH: $DEFAULT_PASSWORD_LENGTH" >&2
        ((errors++))
    fi
    
    if [[ ! "$UID_MIN" =~ ^[0-9]+$ ]] || [[ ! "$UID_MAX" =~ ^[0-9]+$ ]] || [[ "$UID_MIN" -ge "$UID_MAX" ]]; then
        echo "Error: Invalid UID range: $UID_MIN-$UID_MAX" >&2
        ((errors++))
    fi
    
    if [[ ! "$GID_MIN" =~ ^[0-9]+$ ]] || [[ ! "$GID_MAX" =~ ^[0-9]+$ ]] || [[ "$GID_MIN" -ge "$GID_MAX" ]]; then
        echo "Error: Invalid GID range: $GID_MIN-$GID_MAX" >&2
        ((errors++))
    fi
    
    if [[ ! "$PASSWORD_EXPIRY_DAYS" =~ ^[0-9]+$ ]] || [[ "$PASSWORD_EXPIRY_DAYS" -lt 1 ]]; then
        echo "Error: Invalid PASSWORD_EXPIRY_DAYS: $PASSWORD_EXPIRY_DAYS" >&2
        ((errors++))
    fi
    
    if [[ ! "$ACCOUNT_LOCKOUT_ATTEMPTS" =~ ^[0-9]+$ ]] || [[ "$ACCOUNT_LOCKOUT_ATTEMPTS" -lt 1 ]]; then
        echo "Error: Invalid ACCOUNT_LOCKOUT_ATTEMPTS: $ACCOUNT_LOCKOUT_ATTEMPTS" >&2
        ((errors++))
    fi
    
    if [[ ! "$BACKUP_RETENTION_DAYS" =~ ^[0-9]+$ ]] || [[ "$BACKUP_RETENTION_DAYS" -lt 1 ]]; then
        echo "Error: Invalid BACKUP_RETENTION_DAYS: $BACKUP_RETENTION_DAYS" >&2
        ((errors++))
    fi
    
    if [[ ! "$API_PORT" =~ ^[0-9]+$ ]] || [[ "$API_PORT" -lt 1 ]] || [[ "$API_PORT" -gt 65535 ]]; then
        echo "Error: Invalid API_PORT: $API_PORT" >&2
        ((errors++))
    fi
    
    if [[ ! "$MAX_CONCURRENT_OPERATIONS" =~ ^[0-9]+$ ]] || [[ "$MAX_CONCURRENT_OPERATIONS" -lt 1 ]]; then
        echo "Error: Invalid MAX_CONCURRENT_OPERATIONS: $MAX_CONCURRENT_OPERATIONS" >&2
        ((errors++))
    fi
    
    if [[ "$errors" -gt 0 ]]; then
        log_message "ERROR" "Configuration validation failed with $errors error(s)"
        exit 1
    fi
    
    log_message "INFO" "Configuration validation passed"
}

get_config_value() {
    local key="$1"
    local default_value="$2"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        local value=$(grep "^${key}=" "$CONFIG_FILE" | cut -d'=' -f2-)
        if [[ -n "$value" ]]; then
            echo "$value"
        else
            echo "$default_value"
        fi
    else
        echo "$default_value"
    fi
}

set_config_value() {
    local key="$1"
    local value="$2"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        load_config
    fi
    
    if grep -q "^${key}=" "$CONFIG_FILE"; then
        sed -i "s/^${key}=.*/${key}=${value}/" "$CONFIG_FILE"
    else
        echo "${key}=${value}" >> "$CONFIG_FILE"
    fi
    
    log_message "INFO" "Configuration updated: $key=$value"
}

show_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Configuration file not found: $CONFIG_FILE"
        return 1
    fi
    
    echo "User Management System Configuration"
    echo "===================================="
    echo "Configuration File: $CONFIG_FILE"
    echo "Last Modified: $(stat -c%y "$CONFIG_FILE")"
    echo
    
    while IFS='=' read -r key value; do
        if [[ ! "$key" =~ ^# ]] && [[ -n "$key" ]]; then
            if [[ "$key" == *"PASSWORD"* ]] || [[ "$key" == *"TOKEN"* ]]; then
                echo "$key=[HIDDEN]"
            else
                echo "$key=$value"
            fi
        fi
    done < "$CONFIG_FILE"
}

edit_config() {
    local editor="${EDITOR:-nano}"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        load_config
    fi
    
    if command -v "$editor" &>/dev/null; then
        "$editor" "$CONFIG_FILE"
        validate_config
        log_message "INFO" "Configuration edited using $editor"
    else
        echo "Error: Editor '$editor' not found" >&2
        exit 1
    fi
}

reset_config() {
    if [[ -f "$DEFAULT_CONFIG_FILE" ]]; then
        cp "$DEFAULT_CONFIG_FILE" "$CONFIG_FILE"
        log_message "INFO" "Configuration reset to default values"
        echo "Configuration reset to default values"
    else
        create_default_config
        cp "$DEFAULT_CONFIG_FILE" "$CONFIG_FILE"
        log_message "INFO" "Configuration reset to default values"
        echo "Configuration reset to default values"
    fi
}

backup_config() {
    local backup_file="$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        cp "$CONFIG_FILE" "$backup_file"
        log_message "INFO" "Configuration backed up to: $backup_file"
        echo "Configuration backed up to: $backup_file"
    else
        echo "No configuration file to backup"
    fi
}

restore_config() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        echo "Error: Backup file not found: $backup_file" >&2
        exit 1
    fi
    
    cp "$backup_file" "$CONFIG_FILE"
    validate_config
    log_message "INFO" "Configuration restored from: $backup_file"
    echo "Configuration restored from: $backup_file"
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -l, --load                 Load configuration"
    echo "  -v, --validate             Validate configuration"
    echo "  -s, --show                 Show current configuration"
    echo "  -e, --edit                 Edit configuration file"
    echo "  -r, --reset                Reset to default configuration"
    echo "  -b, --backup               Backup current configuration"
    echo "  -R, --restore BACKUP_FILE  Restore from backup file"
    echo "  -g, --get KEY [DEFAULT]    Get configuration value"
    echo "  -S, --set KEY VALUE        Set configuration value"
    echo "  -h, --help                 Show this help message"
    echo
    echo "Examples:"
    echo "  $0 --load"
    echo "  $0 --show"
    echo "  $0 --edit"
    echo "  $0 --get LOG_LEVEL"
    echo "  $0 --set DEFAULT_PASSWORD_LENGTH 16"
    echo "  $0 --backup"
    echo "  $0 --restore config.backup.20240101_120000"
}

main() {
    local action=""
    local key=""
    local value=""
    local backup_file=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -l|--load)
                action="load"
                shift
                ;;
            -v|--validate)
                action="validate"
                shift
                ;;
            -s|--show)
                action="show"
                shift
                ;;
            -e|--edit)
                action="edit"
                shift
                ;;
            -r|--reset)
                action="reset"
                shift
                ;;
            -b|--backup)
                action="backup"
                shift
                ;;
            -R|--restore)
                action="restore"
                backup_file="$2"
                shift 2
                ;;
            -g|--get)
                action="get"
                key="$2"
                value="$3"
                shift 3
                ;;
            -S|--set)
                action="set"
                key="$2"
                value="$3"
                shift 3
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                echo "Error: Unknown option $1" >&2
                show_usage
                exit 1
                ;;
            *)
                echo "Error: Unexpected argument $1" >&2
                show_usage
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$action" ]]; then
        echo "Error: No action specified" >&2
        show_usage
        exit 1
    fi
    
    validate_root_privileges
    
    case "$action" in
        "load")
            load_config
            validate_config
            echo "Configuration loaded and validated"
            ;;
        "validate")
            load_config
            validate_config
            echo "Configuration validation passed"
            ;;
        "show")
            show_config
            ;;
        "edit")
            edit_config
            ;;
        "reset")
            reset_config
            ;;
        "backup")
            backup_config
            ;;
        "restore")
            if [[ -z "$backup_file" ]]; then
                echo "Error: Backup file not specified" >&2
                exit 1
            fi
            restore_config "$backup_file"
            ;;
        "get")
            if [[ -z "$key" ]]; then
                echo "Error: Configuration key not specified" >&2
                exit 1
            fi
            local config_value=$(get_config_value "$key" "$value")
            echo "$config_value"
            ;;
        "set")
            if [[ -z "$key" ]] || [[ -z "$value" ]]; then
                echo "Error: Both key and value must be specified" >&2
                exit 1
            fi
            set_config_value "$key" "$value"
            echo "Configuration updated: $key=$value"
            ;;
    esac
    
    log_message "INFO" "Configuration operation completed: $action"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 