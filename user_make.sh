#!/bin/bash

set -euo pipefail

SCRIPT_NAME=$(basename "$0")
LOG_FILE="/var/log/user_management.log"
CONFIG_FILE="/etc/user_management.conf"

log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S %Z')
    echo "[$timestamp] [$level] [$SCRIPT_NAME] $message" >> "$LOG_FILE"
}

validate_root_privileges() {
    if [[ "${UID}" -ne 0 ]]; then
        log_message "ERROR" "Script executed without root privileges"
        echo "Error: This script must be executed with root privileges" >&2
        echo "Usage: sudo $0 USERNAME [COMMENT]" >&2
        exit 1
    fi
    log_message "INFO" "Root privileges validated"
}

validate_arguments() {
    if [[ "${#}" -lt 1 ]]; then
        log_message "ERROR" "No username provided"
        echo "Error: Username is required" >&2
        echo "Usage: $0 USERNAME [COMMENT]" >&2
        echo "Example: $0 john 'John Doe'" >&2
        exit 1
    fi
    
    if [[ "${#}" -gt 10 ]]; then
        log_message "ERROR" "Too many arguments provided"
        echo "Error: Maximum 10 arguments allowed" >&2
        exit 1
    fi
}

validate_username() {
    local username="$1"
    
    if [[ -z "$username" ]]; then
        log_message "ERROR" "Username cannot be empty"
        echo "Error: Username cannot be empty" >&2
        exit 1
    fi
    
    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        log_message "ERROR" "Invalid username format: $username"
        echo "Error: Username must start with a letter or underscore and contain only lowercase letters, numbers, hyphens, and underscores" >&2
        exit 1
    fi
    
    if [[ ${#username} -lt 2 || ${#username} -gt 32 ]]; then
        log_message "ERROR" "Username length invalid: $username"
        echo "Error: Username must be between 2 and 32 characters" >&2
        exit 1
    fi
    
    if id "$username" &>/dev/null; then
        log_message "ERROR" "User already exists: $username"
        echo "Error: User '$username' already exists" >&2
        exit 1
    fi
    
    log_message "INFO" "Username validation passed: $username"
}

generate_secure_password() {
    local password
    local charset="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*"
    local password_length=12
    
    if [[ -r /dev/urandom ]]; then
        password=$(head -c 100 /dev/urandom | tr -dc "$charset" | head -c "$password_length")
    else
        password=$(date +%s%N | sha256sum | base64 | head -c "$password_length")
    fi
    
    if [[ ${#password} -lt 8 ]]; then
        password="${password}${charset:0:8}"
        password="${password:0:$password_length}"
    fi
    
    echo "$password"
}

create_user_account() {
    local username="$1"
    local comment="$2"
    local password="$3"
    
    log_message "INFO" "Creating user account: $username"
    
    if ! useradd -c "$comment" -m -s /bin/bash "$username"; then
        log_message "ERROR" "Failed to create user account: $username"
        echo "Error: Failed to create user account '$username'" >&2
        exit 1
    fi
    
    log_message "INFO" "User account created successfully: $username"
}

set_user_password() {
    local username="$1"
    local password="$2"
    
    log_message "INFO" "Setting password for user: $username"
    
    if ! echo "$password" | passwd --stdin "$username" &>/dev/null; then
        log_message "ERROR" "Failed to set password for user: $username"
        echo "Error: Failed to set password for user '$username'" >&2
        userdel -r "$username" 2>/dev/null || true
        exit 1
    fi
    
    log_message "INFO" "Password set successfully for user: $username"
}

force_password_change() {
    local username="$1"
    
    log_message "INFO" "Forcing password change on first login for user: $username"
    
    if ! passwd -e "$username" &>/dev/null; then
        log_message "WARN" "Failed to force password change for user: $username"
        echo "Warning: Failed to force password change on first login" >&2
    fi
}

setup_user_environment() {
    local username="$1"
    local home_dir="/home/$username"
    
    log_message "INFO" "Setting up user environment: $username"
    
    if [[ -d "$home_dir" ]]; then
        chmod 755 "$home_dir"
        chown "$username:$username" "$home_dir"
        
        if [[ ! -f "$home_dir/.bashrc" ]]; then
            cp /etc/skel/.bashrc "$home_dir/" 2>/dev/null || true
            chown "$username:$username" "$home_dir/.bashrc" 2>/dev/null || true
        fi
        
        if [[ ! -f "$home_dir/.profile" ]]; then
            cp /etc/skel/.profile "$home_dir/" 2>/dev/null || true
            chown "$username:$username" "$home_dir/.profile" 2>/dev/null || true
        fi
    fi
    
    log_message "INFO" "User environment setup completed: $username"
}

display_user_info() {
    local username="$1"
    local password="$2"
    local hostname=$(hostname)
    
    echo
    echo "=========================================="
    echo "User Account Created Successfully"
    echo "=========================================="
    echo "Username: $username"
    echo "Password: $password"
    echo "Host: $hostname"
    echo "Home Directory: /home/$username"
    echo "Shell: /bin/bash"
    echo "=========================================="
    echo
    
    log_message "INFO" "User creation completed successfully: $username"
}

main() {
    local username="$1"
    shift
    local comment="${*:-$username}"
    
    log_message "INFO" "Starting user creation process for: $username"
    
    validate_root_privileges
    validate_arguments "$@"
    validate_username "$username"
    
    local password=$(generate_secure_password)
    
    create_user_account "$username" "$comment" "$password"
    set_user_password "$username" "$password"
    force_password_change "$username"
    setup_user_environment "$username"
    
    display_user_info "$username" "$password"
    
    log_message "INFO" "User creation process completed successfully: $username"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

