#!/bin/bash

set -euo pipefail

SCRIPT_NAME=$(basename "$0")
LOG_FILE="/var/log/user_management.log"
BACKUP_DIR="/var/backups/user_management"
CONFIG_DIR="/etc/user_management"

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
        echo "Usage: sudo $0 [OPTIONS]" >&2
        exit 1
    fi
    log_message "INFO" "Root privileges validated"
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -b, --backup [USERNAME]    Backup user(s) configuration"
    echo "  -r, --restore BACKUP_FILE  Restore user configuration from backup"
    echo "  -l, --list                 List available backups"
    echo "  -c, --cleanup [DAYS]       Clean up old backups (default: 30 days)"
    echo "  -f, --full                 Perform full backup including home directories"
    echo "  -i, --incremental          Perform incremental backup"
    echo "  -v, --verify               Verify backup integrity"
    echo "  -h, --help                 Show this help message"
    echo
    echo "Examples:"
    echo "  $0 --backup john"
    echo "  $0 --backup --full"
    echo "  $0 --restore backup_20240101_120000.tar.gz"
    echo "  $0 --list"
    echo "  $0 --cleanup 7"
}

setup_backup_environment() {
    log_message "INFO" "Setting up backup environment"
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        chmod 700 "$BACKUP_DIR"
        log_message "INFO" "Created backup directory: $BACKUP_DIR"
    fi
    
    if [[ ! -d "$CONFIG_DIR" ]]; then
        mkdir -p "$CONFIG_DIR"
        chmod 700 "$CONFIG_DIR"
        log_message "INFO" "Created config directory: $CONFIG_DIR"
    fi
}

get_user_list() {
    local specific_user="$1"
    
    if [[ -n "$specific_user" ]]; then
        if id "$specific_user" &>/dev/null; then
            echo "$specific_user"
        else
            log_message "ERROR" "User does not exist: $specific_user"
            echo "Error: User '$specific_user' does not exist" >&2
            exit 1
        fi
    else
        getent passwd | awk -F: '$3 >= 1000 && $3 != 65534 {print $1}'
    fi
}

create_backup_filename() {
    local username="$1"
    local backup_type="$2"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    
    if [[ -n "$username" ]]; then
        echo "user_${username}_${backup_type}_${timestamp}.tar.gz"
    else
        echo "users_${backup_type}_${timestamp}.tar.gz"
    fi
}

backup_user_config() {
    local username="$1"
    local backup_file="$2"
    local full_backup="$3"
    
    log_message "INFO" "Backing up user configuration: $username"
    
    local temp_dir=$(mktemp -d)
    local user_info_file="$temp_dir/user_info.txt"
    local passwd_entry=$(getent passwd "$username")
    local shadow_entry=$(getent shadow "$username")
    local group_info=$(groups "$username")
    
    echo "User Information Backup" > "$user_info_file"
    echo "=======================" >> "$user_info_file"
    echo "Backup Date: $(date)" >> "$user_info_file"
    echo "Username: $username" >> "$user_info_file"
    echo "Passwd Entry: $passwd_entry" >> "$user_info_file"
    echo "Shadow Entry: $shadow_entry" >> "$user_info_file"
    echo "Group Membership: $group_info" >> "$user_info_file"
    echo "Home Directory: $(eval echo ~"$username")" >> "$user_info_file"
    echo "Shell: $(getent passwd "$username" | cut -d: -f7)" >> "$user_info_file"
    echo "UID: $(id -u "$username")" >> "$user_info_file"
    echo "GID: $(id -g "$username")" >> "$user_info_file"
    echo "Account Status: $(passwd -S "$username" | awk '{print $2}')" >> "$user_info_file"
    
    if [[ "$full_backup" == "true" ]]; then
        local home_dir=$(eval echo ~"$username")
        if [[ -d "$home_dir" ]]; then
            log_message "INFO" "Including home directory in backup: $home_dir"
            cp -r "$home_dir" "$temp_dir/"
        fi
    fi
    
    local cron_file="/var/spool/cron/crontabs/$username"
    if [[ -f "$cron_file" ]]; then
        cp "$cron_file" "$temp_dir/"
        log_message "INFO" "Backed up cron file for user: $username"
    fi
    
    local mail_spool="/var/spool/mail/$username"
    if [[ -f "$mail_spool" ]]; then
        cp "$mail_spool" "$temp_dir/"
        log_message "INFO" "Backed up mail spool for user: $username"
    fi
    
    chage -l "$username" > "$temp_dir/account_expiry.txt" 2>/dev/null || true
    
    cd "$temp_dir"
    tar -czf "$backup_file" ./*
    cd - > /dev/null
    
    rm -rf "$temp_dir"
    
    log_message "INFO" "User configuration backup completed: $username"
}

backup_all_users() {
    local backup_file="$1"
    local full_backup="$2"
    
    log_message "INFO" "Starting backup of all users"
    
    local temp_dir=$(mktemp -d)
    local users_file="$temp_dir/users.txt"
    local passwd_file="$temp_dir/passwd"
    local shadow_file="$temp_dir/shadow"
    local group_file="$temp_dir/group"
    local gshadow_file="$temp_dir/gshadow"
    
    getent passwd > "$passwd_file"
    getent shadow > "$shadow_file"
    getent group > "$group_file"
    getent gshadow > "$gshadow_file"
    
    echo "System Users Backup" > "$users_file"
    echo "===================" >> "$users_file"
    echo "Backup Date: $(date)" >> "$users_file"
    echo "Total Users: $(getent passwd | wc -l)" >> "$users_file"
    echo "Regular Users: $(getent passwd | awk -F: '$3 >= 1000 && $3 != 65534' | wc -l)" >> "$users_file"
    echo "System Users: $(getent passwd | awk -F: '$3 < 1000' | wc -l)" >> "$users_file"
    
    if [[ "$full_backup" == "true" ]]; then
        log_message "INFO" "Including home directories in full backup"
        cp -r /home "$temp_dir/" 2>/dev/null || true
    fi
    
    cp -r /etc/skel "$temp_dir/" 2>/dev/null || true
    cp /etc/login.defs "$temp_dir/" 2>/dev/null || true
    cp /etc/default/useradd "$temp_dir/" 2>/dev/null || true
    
    cd "$temp_dir"
    tar -czf "$backup_file" ./*
    cd - > /dev/null
    
    rm -rf "$temp_dir"
    
    log_message "INFO" "All users backup completed"
}

verify_backup() {
    local backup_file="$1"
    
    log_message "INFO" "Verifying backup file: $backup_file"
    
    if [[ ! -f "$backup_file" ]]; then
        log_message "ERROR" "Backup file does not exist: $backup_file"
        echo "Error: Backup file '$backup_file' does not exist" >&2
        exit 1
    fi
    
    if ! tar -tzf "$backup_file" &>/dev/null; then
        log_message "ERROR" "Backup file is corrupted: $backup_file"
        echo "Error: Backup file '$backup_file' is corrupted" >&2
        exit 1
    fi
    
    local file_size=$(stat -c%s "$backup_file")
    if [[ "$file_size" -eq 0 ]]; then
        log_message "ERROR" "Backup file is empty: $backup_file"
        echo "Error: Backup file '$backup_file' is empty" >&2
        exit 1
    fi
    
    log_message "INFO" "Backup file verification passed: $backup_file"
    echo "Backup file verification passed: $backup_file"
}

list_backups() {
    log_message "INFO" "Listing available backups"
    
    if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        echo "No backups found in $BACKUP_DIR"
        return
    fi
    
    echo "Available Backups:"
    echo "=================="
    printf "%-50s %-15s %-10s\n" "Filename" "Size" "Date"
    printf "%-50s %-15s %-10s\n" "--------" "----" "----"
    
    for backup_file in "$BACKUP_DIR"/*.tar.gz; do
        if [[ -f "$backup_file" ]]; then
            local filename=$(basename "$backup_file")
            local size=$(du -h "$backup_file" | cut -f1)
            local date=$(stat -c%y "$backup_file" | cut -d' ' -f1)
            printf "%-50s %-15s %-10s\n" "$filename" "$size" "$date"
        fi
    done
}

cleanup_old_backups() {
    local days="$1"
    
    log_message "INFO" "Cleaning up backups older than $days days"
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo "No backup directory found"
        return
    fi
    
    local deleted_count=0
    local current_time=$(date +%s)
    local cutoff_time=$((current_time - days * 24 * 60 * 60))
    
    for backup_file in "$BACKUP_DIR"/*.tar.gz; do
        if [[ -f "$backup_file" ]]; then
            local file_time=$(stat -c%Y "$backup_file")
            if [[ "$file_time" -lt "$cutoff_time" ]]; then
                rm -f "$backup_file"
                log_message "INFO" "Deleted old backup: $(basename "$backup_file")"
                ((deleted_count++))
            fi
        fi
    done
    
    echo "Cleaned up $deleted_count old backup(s)"
    log_message "INFO" "Cleanup completed: $deleted_count files deleted"
}

restore_user_config() {
    local backup_file="$1"
    local username="$2"
    
    log_message "INFO" "Restoring user configuration from: $backup_file"
    
    verify_backup "$backup_file"
    
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    tar -xzf "$backup_file"
    
    if [[ -f "user_info.txt" ]]; then
        echo "Restoring user configuration..."
        cat "user_info.txt"
        
        if [[ -d "$username" ]]; then
            local home_dir="/home/$username"
            if [[ -d "$home_dir" ]]; then
                mv "$home_dir" "${home_dir}.backup.$(date +%Y%m%d_%H%M%S)"
            fi
            mv "$username" "$home_dir"
            chown -R "$username:$username" "$home_dir"
            log_message "INFO" "Restored home directory for user: $username"
        fi
        
        if [[ -f "crontabs/$username" ]]; then
            cp "crontabs/$username" "/var/spool/cron/crontabs/"
            chown "$username" "/var/spool/cron/crontabs/$username"
            log_message "INFO" "Restored cron file for user: $username"
        fi
        
        if [[ -f "mail/$username" ]]; then
            cp "mail/$username" "/var/spool/mail/"
            chown "$username" "/var/spool/mail/$username"
            log_message "INFO" "Restored mail spool for user: $username"
        fi
        
        echo "User configuration restored successfully"
    else
        echo "System-wide user configuration restore..."
        
        if [[ -d "home" ]]; then
            cp -r "home"/* /home/ 2>/dev/null || true
            log_message "INFO" "Restored home directories"
        fi
        
        if [[ -d "skel" ]]; then
            cp -r "skel"/* /etc/skel/ 2>/dev/null || true
            log_message "INFO" "Restored skeleton directory"
        fi
        
        if [[ -f "login.defs" ]]; then
            cp "login.defs" /etc/ 2>/dev/null || true
            log_message "INFO" "Restored login.defs"
        fi
        
        if [[ -f "useradd" ]]; then
            cp "useradd" /etc/default/ 2>/dev/null || true
            log_message "INFO" "Restored useradd defaults"
        fi
        
        echo "System-wide user configuration restored successfully"
    fi
    
    cd - > /dev/null
    rm -rf "$temp_dir"
    
    log_message "INFO" "User configuration restore completed"
}

main() {
    local action=""
    local username=""
    local backup_file=""
    local full_backup=false
    local incremental=false
    local verify=false
    local cleanup_days=30
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -b|--backup)
                action="backup"
                if [[ $# -gt 1 && ! "$2" =~ ^- ]]; then
                    username="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            -r|--restore)
                action="restore"
                backup_file="$2"
                shift 2
                ;;
            -l|--list)
                action="list"
                shift
                ;;
            -c|--cleanup)
                action="cleanup"
                if [[ $# -gt 1 && ! "$2" =~ ^- ]]; then
                    cleanup_days="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            -f|--full)
                full_backup=true
                shift
                ;;
            -i|--incremental)
                incremental=true
                shift
                ;;
            -v|--verify)
                verify=true
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
    
    log_message "INFO" "Starting user backup operation: $action"
    
    validate_root_privileges
    setup_backup_environment
    
    case "$action" in
        "backup")
            local backup_type="config"
            if [[ "$full_backup" == "true" ]]; then
                backup_type="full"
            elif [[ "$incremental" == "true" ]]; then
                backup_type="incremental"
            fi
            
            local backup_filename=$(create_backup_filename "$username" "$backup_type")
            local backup_path="$BACKUP_DIR/$backup_filename"
            
            if [[ -n "$username" ]]; then
                backup_user_config "$username" "$backup_path" "$full_backup"
            else
                backup_all_users "$backup_path" "$full_backup"
            fi
            
            if [[ "$verify" == "true" ]]; then
                verify_backup "$backup_path"
            fi
            
            echo "Backup completed: $backup_path"
            ;;
        "restore")
            if [[ -z "$backup_file" ]]; then
                echo "Error: Backup file not specified" >&2
                exit 1
            fi
            
            if [[ ! "$backup_file" =~ ^/ ]]; then
                backup_file="$BACKUP_DIR/$backup_file"
            fi
            
            restore_user_config "$backup_file" "$username"
            ;;
        "list")
            list_backups
            ;;
        "cleanup")
            cleanup_old_backups "$cleanup_days"
            ;;
    esac
    
    log_message "INFO" "User backup operation completed: $action"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 