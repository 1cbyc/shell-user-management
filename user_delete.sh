#!/bin/bash

set -euo pipefail

SCRIPT_NAME=$(basename "$0")
LOG_FILE="/var/log/user_management.log"

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
        echo "Usage: sudo $0 USERNAME [OPTIONS]" >&2
        exit 1
    fi
    log_message "INFO" "Root privileges validated"
}

show_usage() {
    echo "Usage: $0 USERNAME [OPTIONS]"
    echo "Options:"
    echo "  -f, --force     Force deletion without confirmation"
    echo "  -r, --remove-home Remove home directory and mail spool"
    echo "  -h, --help      Show this help message"
    echo
    echo "Examples:"
    echo "  $0 john"
    echo "  $0 john --force --remove-home"
}

validate_arguments() {
    if [[ "${#}" -lt 1 ]]; then
        log_message "ERROR" "No username provided"
        echo "Error: Username is required" >&2
        show_usage
        exit 1
    fi
}

check_user_exists() {
    local username="$1"
    
    if ! id "$username" &>/dev/null; then
        log_message "ERROR" "User does not exist: $username"
        echo "Error: User '$username' does not exist" >&2
        exit 1
    fi
    
    log_message "INFO" "User exists: $username"
}

get_user_info() {
    local username="$1"
    local user_info=$(id "$username" 2>/dev/null)
    local home_dir=$(eval echo ~"$username")
    local groups=$(groups "$username" 2>/dev/null | cut -d: -f2-)
    
    echo "User Information:"
    echo "  Username: $username"
    echo "  User ID: $(id -u "$username")"
    echo "  Group ID: $(id -g "$username")"
    echo "  Home Directory: $home_dir"
    echo "  Groups: $groups"
    echo "  Shell: $(getent passwd "$username" | cut -d: -f7)"
    echo
}

confirm_deletion() {
    local username="$1"
    local remove_home="$2"
    
    echo "WARNING: You are about to delete user '$username'"
    if [[ "$remove_home" == "true" ]]; then
        echo "This will also remove the user's home directory and mail spool"
    fi
    echo
    echo "This action cannot be undone!"
    echo
    read -p "Are you sure you want to continue? (yes/no): " confirmation
    
    if [[ "$confirmation" != "yes" ]]; then
        log_message "INFO" "User deletion cancelled by user: $username"
        echo "User deletion cancelled"
        exit 0
    fi
}

delete_user_account() {
    local username="$1"
    local remove_home="$2"
    
    log_message "INFO" "Deleting user account: $username"
    
    local userdel_args="-r"
    if [[ "$remove_home" != "true" ]]; then
        userdel_args=""
    fi
    
    if ! userdel $userdel_args "$username" 2>/dev/null; then
        log_message "ERROR" "Failed to delete user account: $username"
        echo "Error: Failed to delete user account '$username'" >&2
        exit 1
    fi
    
    log_message "INFO" "User account deleted successfully: $username"
}

cleanup_remaining_files() {
    local username="$1"
    local home_dir="/home/$username"
    
    if [[ -d "$home_dir" ]]; then
        log_message "INFO" "Removing remaining home directory: $home_dir"
        rm -rf "$home_dir"
    fi
    
    local mail_spool="/var/spool/mail/$username"
    if [[ -f "$mail_spool" ]]; then
        log_message "INFO" "Removing mail spool: $mail_spool"
        rm -f "$mail_spool"
    fi
    
    local cron_file="/var/spool/cron/crontabs/$username"
    if [[ -f "$cron_file" ]]; then
        log_message "INFO" "Removing cron file: $cron_file"
        rm -f "$cron_file"
    fi
}

display_deletion_summary() {
    local username="$1"
    local hostname=$(hostname)
    
    echo
    echo "=========================================="
    echo "User Account Deleted Successfully"
    echo "=========================================="
    echo "Username: $username"
    echo "Host: $hostname"
    echo "Deletion Time: $(date)"
    echo "=========================================="
    echo
    
    log_message "INFO" "User deletion completed successfully: $username"
}

main() {
    local username=""
    local force=false
    local remove_home=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force)
                force=true
                shift
                ;;
            -r|--remove-home)
                remove_home=true
                shift
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
                if [[ -z "$username" ]]; then
                    username="$1"
                else
                    echo "Error: Multiple usernames provided" >&2
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    if [[ -z "$username" ]]; then
        echo "Error: Username is required" >&2
        show_usage
        exit 1
    fi
    
    log_message "INFO" "Starting user deletion process for: $username"
    
    validate_root_privileges
    check_user_exists "$username"
    
    get_user_info "$username"
    
    if [[ "$force" != "true" ]]; then
        confirm_deletion "$username" "$remove_home"
    fi
    
    delete_user_account "$username" "$remove_home"
    cleanup_remaining_files "$username"
    
    display_deletion_summary "$username"
    
    log_message "INFO" "User deletion process completed successfully: $username"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 