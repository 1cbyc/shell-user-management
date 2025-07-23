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
    echo "  -c, --comment COMMENT    Set user comment/full name"
    echo "  -s, --shell SHELL        Set user shell"
    echo "  -g, --group GROUP        Set primary group"
    echo "  -G, --groups GROUPS      Set supplementary groups (comma-separated)"
    echo "  -u, --uid UID            Set user ID"
    echo "  -d, --home-dir DIR       Set home directory"
    echo "  -m, --move-home          Move home directory to new location"
    echo "  -e, --expired-date DATE  Set account expiration date (YYYY-MM-DD)"
    echo "  -p, --password PASSWORD  Set new password"
    echo "  -l, --lock               Lock user account"
    echo "  -U, --unlock             Unlock user account"
    echo "  -f, --force              Force operation without confirmation"
    echo "  -h, --help               Show this help message"
    echo
    echo "Examples:"
    echo "  $0 john --comment 'John Doe' --shell /bin/zsh"
    echo "  $0 john --groups sudo,docker --lock"
    echo "  $0 john --password newpass123 --expired-date 2024-12-31"
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
    
    echo "Current User Information:"
    echo "  Username: $username"
    echo "  UID: $(id -u "$username")"
    echo "  GID: $(id -g "$username")"
    echo "  Comment: $(getent passwd "$username" | cut -d: -f5)"
    echo "  Home Directory: $(eval echo ~"$username")"
    echo "  Shell: $(getent passwd "$username" | cut -d: -f7)"
    echo "  Groups: $(groups "$username" | cut -d: -f2-)"
    echo "  Account Status: $(passwd -S "$username" | awk '{print $2}')"
    echo
}

validate_shell() {
    local shell="$1"
    
    if [[ ! -f "$shell" ]]; then
        log_message "ERROR" "Shell does not exist: $shell"
        echo "Error: Shell '$shell' does not exist" >&2
        exit 1
    fi
    
    if [[ ! -x "$shell" ]]; then
        log_message "ERROR" "Shell is not executable: $shell"
        echo "Error: Shell '$shell' is not executable" >&2
        exit 1
    fi
    
    if ! grep -q "$shell" /etc/shells 2>/dev/null; then
        log_message "WARN" "Shell not in /etc/shells: $shell"
        echo "Warning: Shell '$shell' is not listed in /etc/shells" >&2
    fi
}

validate_group() {
    local group="$1"
    
    if ! getent group "$group" &>/dev/null; then
        log_message "ERROR" "Group does not exist: $group"
        echo "Error: Group '$group' does not exist" >&2
        exit 1
    fi
}

validate_uid() {
    local uid="$1"
    
    if [[ ! "$uid" =~ ^[0-9]+$ ]]; then
        log_message "ERROR" "Invalid UID format: $uid"
        echo "Error: UID must be a positive integer" >&2
        exit 1
    fi
    
    if [[ "$uid" -lt 0 ]]; then
        log_message "ERROR" "UID cannot be negative: $uid"
        echo "Error: UID cannot be negative" >&2
        exit 1
    fi
    
    if getent passwd "$uid" &>/dev/null; then
        log_message "ERROR" "UID already in use: $uid"
        echo "Error: UID '$uid' is already in use" >&2
        exit 1
    fi
}

validate_date() {
    local date="$1"
    
    if [[ ! "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        log_message "ERROR" "Invalid date format: $date"
        echo "Error: Date must be in YYYY-MM-DD format" >&2
        exit 1
    fi
    
    if ! date -d "$date" &>/dev/null; then
        log_message "ERROR" "Invalid date: $date"
        echo "Error: Invalid date '$date'" >&2
        exit 1
    fi
}

modify_user_comment() {
    local username="$1"
    local comment="$2"
    
    log_message "INFO" "Modifying comment for user: $username"
    
    if ! usermod -c "$comment" "$username"; then
        log_message "ERROR" "Failed to modify comment for user: $username"
        echo "Error: Failed to modify comment for user '$username'" >&2
        exit 1
    fi
    
    log_message "INFO" "Comment modified successfully for user: $username"
}

modify_user_shell() {
    local username="$1"
    local shell="$2"
    
    log_message "INFO" "Modifying shell for user: $username"
    
    if ! usermod -s "$shell" "$username"; then
        log_message "ERROR" "Failed to modify shell for user: $username"
        echo "Error: Failed to modify shell for user '$username'" >&2
        exit 1
    fi
    
    log_message "INFO" "Shell modified successfully for user: $username"
}

modify_user_group() {
    local username="$1"
    local group="$2"
    
    log_message "INFO" "Modifying primary group for user: $username"
    
    if ! usermod -g "$group" "$username"; then
        log_message "ERROR" "Failed to modify primary group for user: $username"
        echo "Error: Failed to modify primary group for user '$username'" >&2
        exit 1
    fi
    
    log_message "INFO" "Primary group modified successfully for user: $username"
}

modify_user_groups() {
    local username="$1"
    local groups="$2"
    
    log_message "INFO" "Modifying supplementary groups for user: $username"
    
    if ! usermod -G "$groups" "$username"; then
        log_message "ERROR" "Failed to modify supplementary groups for user: $username"
        echo "Error: Failed to modify supplementary groups for user '$username'" >&2
        exit 1
    fi
    
    log_message "INFO" "Supplementary groups modified successfully for user: $username"
}

modify_user_uid() {
    local username="$1"
    local uid="$2"
    
    log_message "INFO" "Modifying UID for user: $username"
    
    if ! usermod -u "$uid" "$username"; then
        log_message "ERROR" "Failed to modify UID for user: $username"
        echo "Error: Failed to modify UID for user '$username'" >&2
        exit 1
    fi
    
    log_message "INFO" "UID modified successfully for user: $username"
}

modify_user_home() {
    local username="$1"
    local home_dir="$2"
    local move_home="$3"
    
    log_message "INFO" "Modifying home directory for user: $username"
    
    local usermod_args="-d $home_dir"
    if [[ "$move_home" == "true" ]]; then
        usermod_args="-m -d $home_dir"
    fi
    
    if ! usermod $usermod_args "$username"; then
        log_message "ERROR" "Failed to modify home directory for user: $username"
        echo "Error: Failed to modify home directory for user '$username'" >&2
        exit 1
    fi
    
    log_message "INFO" "Home directory modified successfully for user: $username"
}

modify_user_expiry() {
    local username="$1"
    local expiry_date="$2"
    
    log_message "INFO" "Modifying account expiry for user: $username"
    
    if ! chage -E "$expiry_date" "$username"; then
        log_message "ERROR" "Failed to modify account expiry for user: $username"
        echo "Error: Failed to modify account expiry for user '$username'" >&2
        exit 1
    fi
    
    log_message "INFO" "Account expiry modified successfully for user: $username"
}

modify_user_password() {
    local username="$1"
    local password="$2"
    
    log_message "INFO" "Modifying password for user: $username"
    
    if ! echo "$password" | passwd --stdin "$username" &>/dev/null; then
        log_message "ERROR" "Failed to modify password for user: $username"
        echo "Error: Failed to modify password for user '$username'" >&2
        exit 1
    fi
    
    log_message "INFO" "Password modified successfully for user: $username"
}

lock_user_account() {
    local username="$1"
    
    log_message "INFO" "Locking user account: $username"
    
    if ! passwd -l "$username" &>/dev/null; then
        log_message "ERROR" "Failed to lock user account: $username"
        echo "Error: Failed to lock user account '$username'" >&2
        exit 1
    fi
    
    log_message "INFO" "User account locked successfully: $username"
}

unlock_user_account() {
    local username="$1"
    
    log_message "INFO" "Unlocking user account: $username"
    
    if ! passwd -u "$username" &>/dev/null; then
        log_message "ERROR" "Failed to unlock user account: $username"
        echo "Error: Failed to unlock user account '$username'" >&2
        exit 1
    fi
    
    log_message "INFO" "User account unlocked successfully: $username"
}

confirm_modification() {
    local username="$1"
    local modifications="$2"
    
    echo "You are about to modify user '$username' with the following changes:"
    echo "$modifications"
    echo
    read -p "Are you sure you want to continue? (yes/no): " confirmation
    
    if [[ "$confirmation" != "yes" ]]; then
        log_message "INFO" "User modification cancelled by user: $username"
        echo "User modification cancelled"
        exit 0
    fi
}

display_modification_summary() {
    local username="$1"
    local hostname=$(hostname)
    
    echo
    echo "=========================================="
    echo "User Account Modified Successfully"
    echo "=========================================="
    echo "Username: $username"
    echo "Host: $hostname"
    echo "Modification Time: $(date)"
    echo "=========================================="
    echo
    
    log_message "INFO" "User modification completed successfully: $username"
}

main() {
    local username=""
    local comment=""
    local shell=""
    local group=""
    local groups=""
    local uid=""
    local home_dir=""
    local move_home=false
    local expiry_date=""
    local password=""
    local lock_account=false
    local unlock_account=false
    local force=false
    local modifications=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--comment)
                comment="$2"
                modifications+="- Comment: $comment"$'\n'
                shift 2
                ;;
            -s|--shell)
                shell="$2"
                modifications+="- Shell: $shell"$'\n'
                shift 2
                ;;
            -g|--group)
                group="$2"
                modifications+="- Primary Group: $group"$'\n'
                shift 2
                ;;
            -G|--groups)
                groups="$2"
                modifications+="- Supplementary Groups: $groups"$'\n'
                shift 2
                ;;
            -u|--uid)
                uid="$2"
                modifications+="- UID: $uid"$'\n'
                shift 2
                ;;
            -d|--home-dir)
                home_dir="$2"
                modifications+="- Home Directory: $home_dir"$'\n'
                shift 2
                ;;
            -m|--move-home)
                move_home=true
                modifications+="- Move Home Directory: yes"$'\n'
                shift
                ;;
            -e|--expired-date)
                expiry_date="$2"
                modifications+="- Account Expiry: $expiry_date"$'\n'
                shift 2
                ;;
            -p|--password)
                password="$2"
                modifications+="- Password: [HIDDEN]"$'\n'
                shift 2
                ;;
            -l|--lock)
                lock_account=true
                modifications+="- Lock Account: yes"$'\n'
                shift
                ;;
            -U|--unlock)
                unlock_account=true
                modifications+="- Unlock Account: yes"$'\n'
                shift
                ;;
            -f|--force)
                force=true
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
    
    if [[ -z "$modifications" ]]; then
        echo "Error: No modifications specified" >&2
        show_usage
        exit 1
    fi
    
    log_message "INFO" "Starting user modification process for: $username"
    
    validate_root_privileges
    check_user_exists "$username"
    
    get_user_info "$username"
    
    if [[ -n "$shell" ]]; then
        validate_shell "$shell"
    fi
    
    if [[ -n "$group" ]]; then
        validate_group "$group"
    fi
    
    if [[ -n "$groups" ]]; then
        IFS=',' read -ra GROUP_ARRAY <<< "$groups"
        for g in "${GROUP_ARRAY[@]}"; do
            validate_group "$g"
        done
    fi
    
    if [[ -n "$uid" ]]; then
        validate_uid "$uid"
    fi
    
    if [[ -n "$expiry_date" ]]; then
        validate_date "$expiry_date"
    fi
    
    if [[ "$force" != "true" ]]; then
        confirm_modification "$username" "$modifications"
    fi
    
    if [[ -n "$comment" ]]; then
        modify_user_comment "$username" "$comment"
    fi
    
    if [[ -n "$shell" ]]; then
        modify_user_shell "$username" "$shell"
    fi
    
    if [[ -n "$group" ]]; then
        modify_user_group "$username" "$group"
    fi
    
    if [[ -n "$groups" ]]; then
        modify_user_groups "$username" "$groups"
    fi
    
    if [[ -n "$uid" ]]; then
        modify_user_uid "$username" "$uid"
    fi
    
    if [[ -n "$home_dir" ]]; then
        modify_user_home "$username" "$home_dir" "$move_home"
    fi
    
    if [[ -n "$expiry_date" ]]; then
        modify_user_expiry "$username" "$expiry_date"
    fi
    
    if [[ -n "$password" ]]; then
        modify_user_password "$username" "$password"
    fi
    
    if [[ "$lock_account" == "true" ]]; then
        lock_user_account "$username"
    fi
    
    if [[ "$unlock_account" == "true" ]]; then
        unlock_user_account "$username"
    fi
    
    display_modification_summary "$username"
    
    log_message "INFO" "User modification process completed successfully: $username"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 