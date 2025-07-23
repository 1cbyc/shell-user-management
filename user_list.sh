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

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -a, --all           Show all users (including system users)"
    echo "  -s, --system        Show only system users"
    echo "  -u, --user          Show only regular users (default)"
    echo "  -f, --format FORMAT Output format: table, json, csv, list"
    echo "  -g, --group GROUP   Filter by group membership"
    echo "  -i, --uid-range MIN-MAX Filter by UID range"
    echo "  -l, --locked        Show only locked accounts"
    echo "  -e, --expired       Show only expired accounts"
    echo "  -v, --verbose       Show detailed information"
    echo "  -h, --help          Show this help message"
    echo
    echo "Examples:"
    echo "  $0"
    echo "  $0 --format json --verbose"
    echo "  $0 --group sudo --format table"
    echo "  $0 --uid-range 1000-2000"
}

get_user_list() {
    local show_all="$1"
    local show_system="$2"
    
    if [[ "$show_all" == "true" ]]; then
        getent passwd | cut -d: -f1
    elif [[ "$show_system" == "true" ]]; then
        getent passwd | awk -F: '$3 < 1000 {print $1}'
    else
        getent passwd | awk -F: '$3 >= 1000 && $3 != 65534 {print $1}'
    fi
}

filter_by_group() {
    local users="$1"
    local group="$2"
    
    if [[ -z "$group" ]]; then
        echo "$users"
        return
    fi
    
    local filtered_users=""
    while IFS= read -r user; do
        if groups "$user" 2>/dev/null | grep -q "\b$group\b"; then
            filtered_users+="$user"$'\n'
        fi
    done <<< "$users"
    
    echo "$filtered_users"
}

filter_by_uid_range() {
    local users="$1"
    local uid_range="$2"
    
    if [[ -z "$uid_range" ]]; then
        echo "$users"
        return
    fi
    
    local min_uid=$(echo "$uid_range" | cut -d- -f1)
    local max_uid=$(echo "$uid_range" | cut -d- -f2)
    
    local filtered_users=""
    while IFS= read -r user; do
        local uid=$(id -u "$user" 2>/dev/null)
        if [[ "$uid" -ge "$min_uid" && "$uid" -le "$max_uid" ]]; then
            filtered_users+="$user"$'\n'
        fi
    done <<< "$users"
    
    echo "$filtered_users"
}

filter_locked_accounts() {
    local users="$1"
    local show_locked="$2"
    
    if [[ "$show_locked" != "true" ]]; then
        echo "$users"
        return
    fi
    
    local filtered_users=""
    while IFS= read -r user; do
        if passwd -S "$user" 2>/dev/null | grep -q "L"; then
            filtered_users+="$user"$'\n'
        fi
    done <<< "$users"
    
    echo "$filtered_users"
}

filter_expired_accounts() {
    local users="$1"
    local show_expired="$2"
    
    if [[ "$show_expired" != "true" ]]; then
        echo "$users"
        return
    fi
    
    local filtered_users=""
    while IFS= read -r user; do
        if chage -l "$user" 2>/dev/null | grep -q "Account expires.*:.*expired"; then
            filtered_users+="$user"$'\n'
        fi
    done <<< "$users"
    
    echo "$filtered_users"
}

get_user_details() {
    local username="$1"
    local verbose="$2"
    
    local uid=$(id -u "$username" 2>/dev/null)
    local gid=$(id -g "$username" 2>/dev/null)
    local home_dir=$(eval echo ~"$username")
    local shell=$(getent passwd "$username" | cut -d: -f7)
    local groups=$(groups "$username" 2>/dev/null | cut -d: -f2-)
    local account_status=$(passwd -S "$username" 2>/dev/null | awk '{print $2}')
    local last_login=$(lastlog -u "$username" 2>/dev/null | tail -n +2 | awk '{print $4, $5, $6, $7}')
    
    if [[ "$verbose" == "true" ]]; then
        local comment=$(getent passwd "$username" | cut -d: -f5)
        local account_expiry=$(chage -l "$username" 2>/dev/null | grep "Account expires" | cut -d: -f2)
        local password_expiry=$(chage -l "$username" 2>/dev/null | grep "Password expires" | cut -d: -f2)
        
        echo "Username: $username"
        echo "  UID: $uid"
        echo "  GID: $gid"
        echo "  Comment: $comment"
        echo "  Home Directory: $home_dir"
        echo "  Shell: $shell"
        echo "  Groups: $groups"
        echo "  Account Status: $account_status"
        echo "  Last Login: $last_login"
        echo "  Account Expires: $account_expiry"
        echo "  Password Expires: $password_expiry"
        echo
    else
        echo "$username:$uid:$gid:$home_dir:$shell:$groups:$account_status"
    fi
}

format_output() {
    local users="$1"
    local format="$2"
    local verbose="$3"
    
    case "$format" in
        "json")
            format_json "$users" "$verbose"
            ;;
        "csv")
            format_csv "$users" "$verbose"
            ;;
        "list")
            format_list "$users"
            ;;
        "table"|*)
            format_table "$users" "$verbose"
            ;;
    esac
}

format_json() {
    local users="$1"
    local verbose="$2"
    
    echo "["
    local first=true
    while IFS= read -r user; do
        if [[ -n "$user" ]]; then
            if [[ "$first" == "true" ]]; then
                first=false
            else
                echo ","
            fi
            
            local uid=$(id -u "$user" 2>/dev/null)
            local gid=$(id -g "$user" 2>/dev/null)
            local home_dir=$(eval echo ~"$user")
            local shell=$(getent passwd "$user" | cut -d: -f7)
            local groups=$(groups "$user" 2>/dev/null | cut -d: -f2-)
            local account_status=$(passwd -S "$user" 2>/dev/null | awk '{print $2}')
            
            echo "  {"
            echo "    \"username\": \"$user\","
            echo "    \"uid\": $uid,"
            echo "    \"gid\": $gid,"
            echo "    \"home_directory\": \"$home_dir\","
            echo "    \"shell\": \"$shell\","
            echo "    \"groups\": \"$groups\","
            echo "    \"account_status\": \"$account_status\""
            
            if [[ "$verbose" == "true" ]]; then
                local comment=$(getent passwd "$user" | cut -d: -f5)
                local last_login=$(lastlog -u "$user" 2>/dev/null | tail -n +2 | awk '{print $4, $5, $6, $7}')
                echo ","
                echo "    \"comment\": \"$comment\","
                echo "    \"last_login\": \"$last_login\""
            fi
            
            echo "  }"
        fi
    done <<< "$users"
    echo "]"
}

format_csv() {
    local users="$1"
    local verbose="$2"
    
    if [[ "$verbose" == "true" ]]; then
        echo "Username,UID,GID,Home Directory,Shell,Groups,Account Status,Comment,Last Login"
    else
        echo "Username,UID,GID,Home Directory,Shell,Groups,Account Status"
    fi
    
    while IFS= read -r user; do
        if [[ -n "$user" ]]; then
            local uid=$(id -u "$user" 2>/dev/null)
            local gid=$(id -g "$user" 2>/dev/null)
            local home_dir=$(eval echo ~"$user")
            local shell=$(getent passwd "$user" | cut -d: -f7)
            local groups=$(groups "$user" 2>/dev/null | cut -d: -f2-)
            local account_status=$(passwd -S "$user" 2>/dev/null | awk '{print $2}')
            
            if [[ "$verbose" == "true" ]]; then
                local comment=$(getent passwd "$user" | cut -d: -f5)
                local last_login=$(lastlog -u "$user" 2>/dev/null | tail -n +2 | awk '{print $4, $5, $6, $7}')
                echo "$user,$uid,$gid,\"$home_dir\",\"$shell\",\"$groups\",$account_status,\"$comment\",\"$last_login\""
            else
                echo "$user,$uid,$gid,\"$home_dir\",\"$shell\",\"$groups\",$account_status"
            fi
        fi
    done <<< "$users"
}

format_list() {
    local users="$1"
    
    while IFS= read -r user; do
        if [[ -n "$user" ]]; then
            echo "$user"
        fi
    done <<< "$users"
}

format_table() {
    local users="$1"
    local verbose="$2"
    
    if [[ "$verbose" == "true" ]]; then
        printf "%-15s %-8s %-8s %-20s %-15s %-20s %-10s %-20s %-20s\n" \
               "Username" "UID" "GID" "Home Directory" "Shell" "Groups" "Status" "Comment" "Last Login"
        printf "%-15s %-8s %-8s %-20s %-15s %-20s %-10s %-20s %-20s\n" \
               "-------" "---" "---" "--------------" "-----" "------" "------" "-------" "----------"
    else
        printf "%-15s %-8s %-8s %-20s %-15s %-20s %-10s\n" \
               "Username" "UID" "GID" "Home Directory" "Shell" "Groups" "Status"
        printf "%-15s %-8s %-8s %-20s %-15s %-20s %-10s\n" \
               "-------" "---" "---" "--------------" "-----" "------" "------"
    fi
    
    while IFS= read -r user; do
        if [[ -n "$user" ]]; then
            local uid=$(id -u "$user" 2>/dev/null)
            local gid=$(id -g "$user" 2>/dev/null)
            local home_dir=$(eval echo ~"$user")
            local shell=$(basename "$(getent passwd "$user" | cut -d: -f7)")
            local groups=$(groups "$user" 2>/dev/null | cut -d: -f2- | cut -d' ' -f1-3)
            local account_status=$(passwd -S "$user" 2>/dev/null | awk '{print $2}')
            
            if [[ "$verbose" == "true" ]]; then
                local comment=$(getent passwd "$user" | cut -d: -f5 | cut -c1-18)
                local last_login=$(lastlog -u "$user" 2>/dev/null | tail -n +2 | awk '{print $4, $5, $6}' | cut -c1-18)
                printf "%-15s %-8s %-8s %-20s %-15s %-20s %-10s %-20s %-20s\n" \
                       "$user" "$uid" "$gid" "$home_dir" "$shell" "$groups" "$account_status" "$comment" "$last_login"
            else
                printf "%-15s %-8s %-8s %-20s %-15s %-20s %-10s\n" \
                       "$user" "$uid" "$gid" "$home_dir" "$shell" "$groups" "$account_status"
            fi
        fi
    done <<< "$users"
}

main() {
    local show_all=false
    local show_system=false
    local format="table"
    local group_filter=""
    local uid_range=""
    local show_locked=false
    local show_expired=false
    local verbose=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--all)
                show_all=true
                shift
                ;;
            -s|--system)
                show_system=true
                shift
                ;;
            -u|--user)
                show_all=false
                show_system=false
                shift
                ;;
            -f|--format)
                format="$2"
                shift 2
                ;;
            -g|--group)
                group_filter="$2"
                shift 2
                ;;
            -i|--uid-range)
                uid_range="$2"
                shift 2
                ;;
            -l|--locked)
                show_locked=true
                shift
                ;;
            -e|--expired)
                show_expired=true
                shift
                ;;
            -v|--verbose)
                verbose=true
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
    
    log_message "INFO" "Starting user listing process"
    
    local users=$(get_user_list "$show_all" "$show_system")
    users=$(filter_by_group "$users" "$group_filter")
    users=$(filter_by_uid_range "$users" "$uid_range")
    users=$(filter_locked_accounts "$users" "$show_locked")
    users=$(filter_expired_accounts "$users" "$show_expired")
    
    if [[ -z "$users" ]]; then
        echo "No users found matching the specified criteria"
        log_message "INFO" "No users found matching criteria"
        exit 0
    fi
    
    format_output "$users" "$format" "$verbose"
    
    log_message "INFO" "User listing process completed"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 