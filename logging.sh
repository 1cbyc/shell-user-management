#!/bin/bash

set -euo pipefail

SCRIPT_NAME=$(basename "$0")
LOG_FILE="/var/log/user_management.log"
LOG_DIR="/var/log/user_management"
LOG_LEVEL="INFO"
LOG_MAX_SIZE="10MB"
LOG_RETENTION_DAYS=30

declare -A LOG_LEVELS=(
    ["DEBUG"]=0
    ["INFO"]=1
    ["WARN"]=2
    ["ERROR"]=3
)

log_message() {
    local level="$1"
    local message="$2"
    local script_name="${3:-$SCRIPT_NAME}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S %Z')
    local log_entry="[$timestamp] [$level] [$script_name] $message"
    
    if [[ ${LOG_LEVELS[$level]:-0} -ge ${LOG_LEVELS[$LOG_LEVEL]:-1} ]]; then
        echo "$log_entry" >> "$LOG_FILE"
        
        if [[ "$level" == "ERROR" ]]; then
            echo "$log_entry" >&2
        elif [[ "$level" == "WARN" ]]; then
            echo "$log_entry" >&2
        fi
    fi
}

setup_logging() {
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR"
        chmod 755 "$LOG_DIR"
    fi
    
    if [[ ! -f "$LOG_FILE" ]]; then
        touch "$LOG_FILE"
        chmod 644 "$LOG_FILE"
    fi
    
    log_message "INFO" "Logging system initialized"
}

rotate_logs() {
    local log_file="$1"
    local max_size="$2"
    
    if [[ ! -f "$log_file" ]]; then
        return
    fi
    
    local current_size=$(stat -c%s "$log_file" 2>/dev/null || echo 0)
    local max_size_bytes=$(convert_size_to_bytes "$max_size")
    
    if [[ "$current_size" -gt "$max_size_bytes" ]]; then
        local timestamp=$(date '+%Y%m%d_%H%M%S')
        local rotated_file="${log_file}.${timestamp}"
        
        mv "$log_file" "$rotated_file"
        touch "$log_file"
        chmod 644 "$log_file"
        
        log_message "INFO" "Log file rotated: $rotated_file"
        compress_log_file "$rotated_file"
    fi
}

convert_size_to_bytes() {
    local size="$1"
    local number=$(echo "$size" | sed 's/[^0-9]//g')
    local unit=$(echo "$size" | sed 's/[0-9]//g' | tr '[:lower:]' '[:upper:]')
    
    case "$unit" in
        "B")
            echo "$number"
            ;;
        "KB")
            echo $((number * 1024))
            ;;
        "MB")
            echo $((number * 1024 * 1024))
            ;;
        "GB")
            echo $((number * 1024 * 1024 * 1024))
            ;;
        *)
            echo "$number"
            ;;
    esac
}

compress_log_file() {
    local log_file="$1"
    
    if command -v gzip &>/dev/null; then
        gzip "$log_file" &
        log_message "INFO" "Log file compressed: ${log_file}.gz"
    fi
}

cleanup_old_logs() {
    local retention_days="$1"
    local deleted_count=0
    
    if [[ ! -d "$LOG_DIR" ]]; then
        return
    fi
    
    local current_time=$(date +%s)
    local cutoff_time=$((current_time - retention_days * 24 * 60 * 60))
    
    for log_file in "$LOG_DIR"/*.log.* "$LOG_DIR"/*.log.*.gz; do
        if [[ -f "$log_file" ]]; then
            local file_time=$(stat -c%Y "$log_file" 2>/dev/null || echo 0)
            if [[ "$file_time" -lt "$cutoff_time" ]]; then
                rm -f "$log_file"
                ((deleted_count++))
            fi
        fi
    done
    
    if [[ "$deleted_count" -gt 0 ]]; then
        log_message "INFO" "Cleaned up $deleted_count old log file(s)"
    fi
}

get_log_statistics() {
    local log_file="$1"
    
    if [[ ! -f "$log_file" ]]; then
        echo "Log file not found: $log_file"
        return 1
    fi
    
    local total_lines=$(wc -l < "$log_file")
    local debug_count=$(grep -c "\[DEBUG\]" "$log_file" || echo 0)
    local info_count=$(grep -c "\[INFO\]" "$log_file" || echo 0)
    local warn_count=$(grep -c "\[WARN\]" "$log_file" || echo 0)
    local error_count=$(grep -c "\[ERROR\]" "$log_file" || echo 0)
    local file_size=$(du -h "$log_file" | cut -f1)
    local last_modified=$(stat -c%y "$log_file")
    
    echo "Log File Statistics: $log_file"
    echo "========================"
    echo "Total Lines: $total_lines"
    echo "File Size: $file_size"
    echo "Last Modified: $last_modified"
    echo
    echo "Log Levels:"
    echo "  DEBUG: $debug_count"
    echo "  INFO:  $info_count"
    echo "  WARN:  $warn_count"
    echo "  ERROR: $error_count"
}

search_logs() {
    local pattern="$1"
    local log_file="$2"
    local max_results="${3:-50}"
    
    if [[ ! -f "$log_file" ]]; then
        echo "Log file not found: $log_file"
        return 1
    fi
    
    echo "Searching logs for pattern: $pattern"
    echo "===================================="
    
    grep -i "$pattern" "$log_file" | tail -n "$max_results" || echo "No matches found"
}

tail_logs() {
    local log_file="$1"
    local lines="${2:-50}"
    local follow="${3:-false}"
    
    if [[ ! -f "$log_file" ]]; then
        echo "Log file not found: $log_file"
        return 1
    fi
    
    if [[ "$follow" == "true" ]]; then
        tail -f -n "$lines" "$log_file"
    else
        tail -n "$lines" "$log_file"
    fi
}

export_logs() {
    local log_file="$1"
    local output_file="$2"
    local format="${3:-text}"
    
    if [[ ! -f "$log_file" ]]; then
        echo "Log file not found: $log_file"
        return 1
    fi
    
    case "$format" in
        "json")
            export_logs_json "$log_file" "$output_file"
            ;;
        "csv")
            export_logs_csv "$log_file" "$output_file"
            ;;
        "xml")
            export_logs_xml "$log_file" "$output_file"
            ;;
        "text"|*)
            cp "$log_file" "$output_file"
            ;;
    esac
    
    log_message "INFO" "Logs exported to: $output_file (format: $format)"
}

export_logs_json() {
    local log_file="$1"
    local output_file="$2"
    
    echo "[" > "$output_file"
    local first=true
    
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            if [[ "$first" == "true" ]]; then
                first=false
            else
                echo "," >> "$output_file"
            fi
            
            local timestamp=$(echo "$line" | sed -n 's/^\[\([^]]*\)\].*/\1/p')
            local level=$(echo "$line" | sed -n 's/.*\[\([A-Z]*\)\].*/\1/p')
            local script=$(echo "$line" | sed -n 's/.*\[\([^]]*\)\].*/\1/p' | tail -1)
            local message=$(echo "$line" | sed -n 's/.*\] \[[A-Z]*\] \[[^]]*\] \(.*\)/\1/p')
            
            echo "  {" >> "$output_file"
            echo "    \"timestamp\": \"$timestamp\"," >> "$output_file"
            echo "    \"level\": \"$level\"," >> "$output_file"
            echo "    \"script\": \"$script\"," >> "$output_file"
            echo "    \"message\": \"$message\"" >> "$output_file"
            echo "  }" >> "$output_file"
        fi
    done < "$log_file"
    
    echo "]" >> "$output_file"
}

export_logs_csv() {
    local log_file="$1"
    local output_file="$2"
    
    echo "timestamp,level,script,message" > "$output_file"
    
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            local timestamp=$(echo "$line" | sed -n 's/^\[\([^]]*\)\].*/\1/p')
            local level=$(echo "$line" | sed -n 's/.*\[\([A-Z]*\)\].*/\1/p')
            local script=$(echo "$line" | sed -n 's/.*\[\([^]]*\)\].*/\1/p' | tail -1)
            local message=$(echo "$line" | sed -n 's/.*\] \[[A-Z]*\] \[[^]]*\] \(.*\)/\1/p')
            
            echo "\"$timestamp\",\"$level\",\"$script\",\"$message\"" >> "$output_file"
        fi
    done < "$log_file"
}

export_logs_xml() {
    local log_file="$1"
    local output_file="$2"
    
    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > "$output_file"
    echo "<logs>" >> "$output_file"
    
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            local timestamp=$(echo "$line" | sed -n 's/^\[\([^]]*\)\].*/\1/p')
            local level=$(echo "$line" | sed -n 's/.*\[\([A-Z]*\)\].*/\1/p')
            local script=$(echo "$line" | sed -n 's/.*\[\([^]]*\)\].*/\1/p' | tail -1)
            local message=$(echo "$line" | sed -n 's/.*\] \[[A-Z]*\] \[[^]]*\] \(.*\)/\1/p')
            
            echo "  <log>" >> "$output_file"
            echo "    <timestamp>$timestamp</timestamp>" >> "$output_file"
            echo "    <level>$level</level>" >> "$output_file"
            echo "    <script>$script</script>" >> "$output_file"
            echo "    <message>$message</message>" >> "$output_file"
            echo "  </log>" >> "$output_file"
        fi
    done < "$log_file"
    
    echo "</logs>" >> "$output_file"
}

monitor_logs() {
    local log_file="$1"
    local interval="${2:-5}"
    
    if [[ ! -f "$log_file" ]]; then
        echo "Log file not found: $log_file"
        return 1
    fi
    
    echo "Monitoring log file: $log_file"
    echo "Check interval: ${interval} seconds"
    echo "Press Ctrl+C to stop"
    echo
    
    local last_size=0
    
    while true; do
        local current_size=$(stat -c%s "$log_file" 2>/dev/null || echo 0)
        
        if [[ "$current_size" -gt "$last_size" ]]; then
            local new_lines=$(tail -c +$((last_size + 1)) "$log_file" 2>/dev/null || echo "")
            if [[ -n "$new_lines" ]]; then
                echo "$new_lines"
            fi
            last_size=$current_size
        fi
        
        sleep "$interval"
    done
}

analyze_logs() {
    local log_file="$1"
    
    if [[ ! -f "$log_file" ]]; then
        echo "Log file not found: $log_file"
        return 1
    fi
    
    echo "Log Analysis Report"
    echo "=================="
    echo "Log File: $log_file"
    echo "Analysis Date: $(date)"
    echo
    
    local total_lines=$(wc -l < "$log_file")
    echo "Total Log Entries: $total_lines"
    
    local error_count=$(grep -c "\[ERROR\]" "$log_file" || echo 0)
    local warn_count=$(grep -c "\[WARN\]" "$log_file" || echo 0)
    local error_percentage=$(echo "scale=2; $error_count * 100 / $total_lines" | bc 2>/dev/null || echo "0")
    local warn_percentage=$(echo "scale=2; $warn_count * 100 / $total_lines" | bc 2>/dev/null || echo "0")
    
    echo "Error Rate: $error_count ($error_percentage%)"
    echo "Warning Rate: $warn_count ($warn_percentage%)"
    echo
    
    echo "Top Error Messages:"
    grep "\[ERROR\]" "$log_file" | sed 's/.*\] \[ERROR\] \[[^]]*\] //' | sort | uniq -c | sort -nr | head -10
    echo
    
    echo "Top Warning Messages:"
    grep "\[WARN\]" "$log_file" | sed 's/.*\] \[WARN\] \[[^]]*\] //' | sort | uniq -c | sort -nr | head -10
    echo
    
    echo "Most Active Scripts:"
    grep -o "\[[^]]*\]" "$log_file" | grep -v "\[[A-Z]*\]" | sort | uniq -c | sort -nr | head -10
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -s, --setup                 Setup logging system"
    echo "  -r, --rotate                Rotate log files"
    echo "  -c, --cleanup [DAYS]        Clean up old logs (default: 30 days)"
    echo "  -t, --tail [LINES]          Show last N lines (default: 50)"
    echo "  -f, --follow                Follow log file in real-time"
    echo "  -g, --grep PATTERN          Search logs for pattern"
    echo "  -e, --export FILE [FORMAT]  Export logs (format: text, json, csv, xml)"
    echo "  -m, --monitor [INTERVAL]    Monitor logs for changes"
    echo "  -a, --analyze               Analyze log statistics"
    echo "  -S, --stats                 Show log statistics"
    echo "  -h, --help                  Show this help message"
    echo
    echo "Examples:"
    echo "  $0 --setup"
    echo "  $0 --tail 100"
    echo "  $0 --follow"
    echo "  $0 --grep 'ERROR'"
    echo "  $0 --export logs.json json"
    echo "  $0 --analyze"
}

main() {
    local action=""
    local log_file="$LOG_FILE"
    local pattern=""
    local output_file=""
    local format="text"
    local lines=50
    local follow=false
    local interval=5
    local cleanup_days=30
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--setup)
                action="setup"
                shift
                ;;
            -r|--rotate)
                action="rotate"
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
            -t|--tail)
                action="tail"
                if [[ $# -gt 1 && ! "$2" =~ ^- ]]; then
                    lines="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            -f|--follow)
                follow=true
                shift
                ;;
            -g|--grep)
                action="grep"
                pattern="$2"
                shift 2
                ;;
            -e|--export)
                action="export"
                output_file="$2"
                if [[ $# -gt 2 && ! "$3" =~ ^- ]]; then
                    format="$3"
                    shift 3
                else
                    shift 2
                fi
                ;;
            -m|--monitor)
                action="monitor"
                if [[ $# -gt 1 && ! "$2" =~ ^- ]]; then
                    interval="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            -a|--analyze)
                action="analyze"
                shift
                ;;
            -S|--stats)
                action="stats"
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
    
    case "$action" in
        "setup")
            setup_logging
            echo "Logging system setup completed"
            ;;
        "rotate")
            rotate_logs "$log_file" "$LOG_MAX_SIZE"
            echo "Log rotation completed"
            ;;
        "cleanup")
            cleanup_old_logs "$cleanup_days"
            echo "Log cleanup completed"
            ;;
        "tail")
            if [[ "$follow" == "true" ]]; then
                tail_logs "$log_file" "$lines" "true"
            else
                tail_logs "$log_file" "$lines"
            fi
            ;;
        "grep")
            if [[ -z "$pattern" ]]; then
                echo "Error: Search pattern not specified" >&2
                exit 1
            fi
            search_logs "$pattern" "$log_file"
            ;;
        "export")
            if [[ -z "$output_file" ]]; then
                echo "Error: Output file not specified" >&2
                exit 1
            fi
            export_logs "$log_file" "$output_file" "$format"
            echo "Logs exported to: $output_file"
            ;;
        "monitor")
            monitor_logs "$log_file" "$interval"
            ;;
        "analyze")
            analyze_logs "$log_file"
            ;;
        "stats")
            get_log_statistics "$log_file"
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 