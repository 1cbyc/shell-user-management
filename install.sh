#!/bin/bash

set -euo pipefail

SCRIPT_NAME=$(basename "$0")
PROJECT_NAME="Shell User Management System"
VERSION="1.5.0"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/user_management"
LOG_DIR="/var/log/user_management"
BACKUP_DIR="/var/backups/user_management"

log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S %Z')
    echo "[$timestamp] [$level] [$SCRIPT_NAME] $message"
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -i, --install              Install the system"
    echo "  -u, --uninstall            Uninstall the system"
    echo "  -c, --check                Check installation status"
    echo "  -v, --version              Show version information"
    echo "  -h, --help                 Show this help message"
    echo
    echo "Examples:"
    echo "  $0 --install"
    echo "  $0 --check"
    echo "  $0 --uninstall"
}

validate_root_privileges() {
    if [[ "${UID}" -ne 0 ]]; then
        log_message "ERROR" "This script must be executed with root privileges"
        echo "Error: This script must be executed with root privileges" >&2
        echo "Usage: sudo $0 [OPTIONS]" >&2
        exit 1
    fi
    log_message "INFO" "Root privileges validated"
}

check_dependencies() {
    log_message "INFO" "Checking system dependencies"
    
    local missing_deps=()
    
    local required_commands=(
        "bash"
        "useradd"
        "userdel"
        "usermod"
        "passwd"
        "getent"
        "id"
        "groups"
        "chage"
        "tar"
        "gzip"
        "grep"
        "awk"
        "sed"
        "cut"
        "sort"
        "uniq"
        "wc"
        "stat"
        "du"
        "date"
        "head"
        "tail"
        "tr"
        "base64"
        "sha256sum"
    )
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_message "ERROR" "Missing dependencies: ${missing_deps[*]}"
        echo "Error: Missing required dependencies: ${missing_deps[*]}" >&2
        echo "Please install the missing packages and try again." >&2
        exit 1
    fi
    
    log_message "INFO" "All dependencies are available"
}

check_bash_version() {
    local required_version="4.0"
    local current_version=$(bash --version | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
    
    if [[ -z "$current_version" ]]; then
        log_message "ERROR" "Unable to determine Bash version"
        echo "Error: Unable to determine Bash version" >&2
        exit 1
    fi
    
    if [[ "$(printf '%s\n' "$required_version" "$current_version" | sort -V | head -n1)" != "$required_version" ]]; then
        log_message "ERROR" "Bash version $current_version is too old. Required: $required_version or higher"
        echo "Error: Bash version $current_version is too old. Required: $required_version or higher" >&2
        exit 1
    fi
    
    log_message "INFO" "Bash version $current_version is compatible"
}

create_directories() {
    log_message "INFO" "Creating system directories"
    
    local directories=(
        "$INSTALL_DIR"
        "$CONFIG_DIR"
        "$LOG_DIR"
        "$BACKUP_DIR"
    )
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_message "INFO" "Created directory: $dir"
        fi
    done
    
    chmod 755 "$INSTALL_DIR"
    chmod 700 "$CONFIG_DIR"
    chmod 755 "$LOG_DIR"
    chmod 700 "$BACKUP_DIR"
    
    log_message "INFO" "System directories created successfully"
}

install_scripts() {
    log_message "INFO" "Installing scripts to $INSTALL_DIR"
    
    local scripts=(
        "user_make.sh"
        "user_delete.sh"
        "user_list.sh"
        "user_modify.sh"
        "user_backup.sh"
        "config.sh"
        "logging.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            cp "$script" "$INSTALL_DIR/"
            chmod 755 "$INSTALL_DIR/$script"
            log_message "INFO" "Installed: $script"
        else
            log_message "ERROR" "Script not found: $script"
            echo "Error: Script not found: $script" >&2
            exit 1
        fi
    done
    
    log_message "INFO" "All scripts installed successfully"
}

setup_logging() {
    log_message "INFO" "Setting up logging system"
    
    if [[ -f "$INSTALL_DIR/logging.sh" ]]; then
        "$INSTALL_DIR/logging.sh" --setup
        log_message "INFO" "Logging system setup completed"
    else
        log_message "ERROR" "Logging script not found"
        echo "Error: Logging script not found" >&2
        exit 1
    fi
}

setup_configuration() {
    log_message "INFO" "Setting up configuration system"
    
    if [[ -f "$INSTALL_DIR/config.sh" ]]; then
        "$INSTALL_DIR/config.sh" --setup
        log_message "INFO" "Configuration system setup completed"
    else
        log_message "ERROR" "Configuration script not found"
        echo "Error: Configuration script not found" >&2
        exit 1
    fi
}

create_symlinks() {
    log_message "INFO" "Creating command symlinks"
    
    local commands=(
        "user-make"
        "user-delete"
        "user-list"
        "user-modify"
        "user-backup"
        "user-config"
        "user-logging"
    )
    
    local scripts=(
        "user_make.sh"
        "user_delete.sh"
        "user_list.sh"
        "user_modify.sh"
        "user_backup.sh"
        "config.sh"
        "logging.sh"
    )
    
    for i in "${!commands[@]}"; do
        local command="${commands[$i]}"
        local script="${scripts[$i]}"
        
        if [[ -f "$INSTALL_DIR/$script" ]]; then
            ln -sf "$INSTALL_DIR/$script" "$INSTALL_DIR/$command"
            log_message "INFO" "Created symlink: $command -> $script"
        fi
    done
    
    log_message "INFO" "Command symlinks created successfully"
}

create_man_pages() {
    log_message "INFO" "Creating manual pages"
    
    local man_dir="/usr/local/share/man/man1"
    
    if [[ ! -d "$man_dir" ]]; then
        mkdir -p "$man_dir"
    fi
    
    cat > "$man_dir/user-make.1" << 'EOF'
.TH USER-MAKE 1 "2024" "Shell User Management System" "User Commands"
.SH NAME
user-make \- Create system users with auto-generated passwords
.SH SYNOPSIS
.B user-make
.I username
.RI [ comment ]
.SH DESCRIPTION
Create a new system user with an auto-generated secure password.
.SH OPTIONS
.TP
.B username
The username for the new account
.TP
.B comment
Optional comment/full name for the user
.SH EXAMPLES
.TP
Create a user with full name:
.B user-make john "John Doe"
.TP
Create a user with just username:
.B user-make jane
.SH FILES
.TP
.I /var/log/user_management.log
Log file for user management operations
.SH AUTHOR
Shell User Management System
.SH "SEE ALSO"
user-delete(1), user-list(1), user-modify(1)
EOF

    log_message "INFO" "Manual pages created"
}

create_completion_scripts() {
    log_message "INFO" "Creating bash completion scripts"
    
    local completion_dir="/etc/bash_completion.d"
    
    if [[ ! -d "$completion_dir" ]]; then
        mkdir -p "$completion_dir"
    fi
    
    cat > "$completion_dir/user-management" << 'EOF'
_user_make() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    local prev=${COMP_WORDS[COMP_CWORD-1]}
    
    case $prev in
        user-make)
            if [[ $cur == -* ]]; then
                COMPREPLY=( $(compgen -W "--help" -- "$cur") )
            fi
            ;;
        *)
            COMPREPLY=( $(compgen -W "$(getent passwd | cut -d: -f1)" -- "$cur") )
            ;;
    esac
}

_user_list() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    local prev=${COMP_WORDS[COMP_CWORD-1]}
    
    case $prev in
        --format)
            COMPREPLY=( $(compgen -W "table json csv list" -- "$cur") )
            ;;
        --group)
            COMPREPLY=( $(compgen -W "$(getent group | cut -d: -f1)" -- "$cur") )
            ;;
        *)
            COMPREPLY=( $(compgen -W "--all --system --user --format --group --uid-range --locked --expired --verbose --help" -- "$cur") )
            ;;
    esac
}

complete -F _user_make user-make
complete -F _user_list user-list
complete -F _user_list user-delete
complete -F _user_list user-modify
complete -F _user_list user-backup
EOF

    log_message "INFO" "Bash completion scripts created"
}

check_installation() {
    log_message "INFO" "Checking installation status"
    
    local status=0
    local missing_files=()
    
    local required_files=(
        "$INSTALL_DIR/user_make.sh"
        "$INSTALL_DIR/user_delete.sh"
        "$INSTALL_DIR/user_list.sh"
        "$INSTALL_DIR/user_modify.sh"
        "$INSTALL_DIR/user_backup.sh"
        "$INSTALL_DIR/config.sh"
        "$INSTALL_DIR/logging.sh"
    )
    
    local required_dirs=(
        "$CONFIG_DIR"
        "$LOG_DIR"
        "$BACKUP_DIR"
    )
    
    echo "Installation Status Check"
    echo "========================"
    
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            echo "✓ $file"
        else
            echo "✗ $file (missing)"
            missing_files+=("$file")
            status=1
        fi
    done
    
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            echo "✓ $dir"
        else
            echo "✗ $dir (missing)"
            missing_files+=("$dir")
            status=1
        fi
    done
    
    if [[ -f "$CONFIG_DIR/user_management.conf" ]]; then
        echo "✓ Configuration file"
    else
        echo "✗ Configuration file (missing)"
        status=1
    fi
    
    if [[ -f "$LOG_DIR/user_management.log" ]]; then
        echo "✓ Log file"
    else
        echo "✗ Log file (missing)"
        status=1
    fi
    
    echo
    
    if [[ $status -eq 0 ]]; then
        echo "Installation Status: ✓ COMPLETE"
        log_message "INFO" "Installation check passed"
    else
        echo "Installation Status: ✗ INCOMPLETE"
        echo "Missing components: ${missing_files[*]}"
        log_message "ERROR" "Installation check failed"
    fi
    
    return $status
}

uninstall_system() {
    log_message "INFO" "Uninstalling system"
    
    echo "WARNING: This will remove all user management scripts and data."
    echo "This action cannot be undone!"
    echo
    read -p "Are you sure you want to continue? (yes/no): " confirmation
    
    if [[ "$confirmation" != "yes" ]]; then
        echo "Uninstallation cancelled"
        exit 0
    fi
    
    local files_to_remove=(
        "$INSTALL_DIR/user_make.sh"
        "$INSTALL_DIR/user_delete.sh"
        "$INSTALL_DIR/user_list.sh"
        "$INSTALL_DIR/user_modify.sh"
        "$INSTALL_DIR/user_backup.sh"
        "$INSTALL_DIR/config.sh"
        "$INSTALL_DIR/logging.sh"
        "$INSTALL_DIR/user-make"
        "$INSTALL_DIR/user-delete"
        "$INSTALL_DIR/user-list"
        "$INSTALL_DIR/user-modify"
        "$INSTALL_DIR/user-backup"
        "$INSTALL_DIR/user-config"
        "$INSTALL_DIR/user-logging"
        "/usr/local/share/man/man1/user-make.1"
        "/etc/bash_completion.d/user-management"
    )
    
    for file in "${files_to_remove[@]}"; do
        if [[ -f "$file" ]]; then
            rm -f "$file"
            log_message "INFO" "Removed: $file"
        fi
    done
    
    echo "System uninstalled successfully"
    log_message "INFO" "System uninstallation completed"
}

show_version() {
    echo "$PROJECT_NAME v$VERSION"
    echo "Copyright (c) 2024 1cbyc"
    echo "MIT License"
}

main() {
    local action=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--install)
                action="install"
                shift
                ;;
            -u|--uninstall)
                action="uninstall"
                shift
                ;;
            -c|--check)
                action="check"
                shift
                ;;
            -v|--version)
                show_version
                exit 0
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
    
    case "$action" in
        "install")
            validate_root_privileges
            check_dependencies
            check_bash_version
            create_directories
            install_scripts
            setup_logging
            setup_configuration
            create_symlinks
            create_man_pages
            create_completion_scripts
            echo
            echo "Installation completed successfully!"
            echo "You can now use the following commands:"
            echo "  user-make, user-delete, user-list, user-modify, user-backup, user-config, user-logging"
            echo
            echo "For help, run: user-make --help"
            ;;
        "uninstall")
            validate_root_privileges
            uninstall_system
            ;;
        "check")
            check_installation
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 