#!/usr/bin/env bash
# TACO - Tmux Agent Command Orchestrator
# Common functions and configuration

# Configuration
export TACO_VERSION="1.0"
export PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
export ORCHESTRATOR_DIR="$PROJECT_DIR/.orchestrator"
export SESSION_NAME="${ORCHESTRATOR_SESSION:-taco}"
export CONFIG_FILE="${HOME}/.orchestrator/config"

# Load configuration if exists
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

# Default configuration values
export ORCHESTRATOR_TIMEOUT="${ORCHESTRATOR_TIMEOUT:-45}"
export ORCHESTRATOR_MAX_RETRIES="${ORCHESTRATOR_MAX_RETRIES:-3}"
export ORCHESTRATOR_LOG_LEVEL="${ORCHESTRATOR_LOG_LEVEL:-INFO}"

# Colors for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export BLUE='\033[0;34m'
export YELLOW='\033[1;33m'
export CYAN='\033[0;36m'
export MAGENTA='\033[0;35m'
export NC='\033[0m'

# Structured logging function
log() {
    local level="$1"
    local component="$2"
    local message="$3"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Log to file
    echo "$timestamp [$level] [$component] $message" >> "$ORCHESTRATOR_DIR/orchestrator.log"
    
    # Log to console based on level
    case "$level" in
        ERROR) echo -e "${RED}[$component] $message${NC}" ;;
        WARN)  echo -e "${YELLOW}[$component] $message${NC}" ;;
        INFO)  echo -e "${CYAN}[$component] $message${NC}" ;;
        DEBUG) [ "$ORCHESTRATOR_LOG_LEVEL" = "DEBUG" ] && echo -e "[$component] $message" ;;
    esac
}

# Safety check for critical processes
check_critical_processes() {
    local has_critical=false

    if command -v docker >/dev/null 2>&1; then
        local docker_count=$(docker ps -q 2>/dev/null | wc -l || echo 0)
        if [ "$docker_count" -gt 0 ]; then
            echo -e "${YELLOW}⚠️  Found running Docker containers${NC}"
            has_critical=true
        fi
    fi

    if pgrep -f "npm.*start|yarn.*start|python.*manage.py.*runserver" >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Found running development servers${NC}"
        has_critical=true
    fi

    if pgrep -f "claude.*--dangerously-skip" >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Found running Claude agents${NC}"
        has_critical=true
    fi

    if [ "$has_critical" = true ]; then
        echo -e "${CYAN}The orchestrator will NOT affect these processes.${NC}"
        echo
        read -r -p "Continue? (Y/n): " continue_choice
        if [[ "$continue_choice" =~ ^[Nn]$ ]]; then
            echo -e "${GREEN}Exiting safely.${NC}"
            exit 0
        fi
    fi
}

# Calculate optimal pane layout for given number of panes
calculate_pane_layout() {
    local num_panes=$1
    case $num_panes in
        2) echo "even-horizontal" ;;
        3) echo "main-vertical" ;;
        4) echo "tiled" ;;
        5|6) echo "tiled" ;;
        *) echo "tiled" ;;
    esac
}

# Function to read multi-line input
read_multiline_input() {
    local input=""
    local line=""
    local line_count=0
    
    while true; do
        if [ $line_count -eq 0 ]; then
            read -r -p "> " line
        else
            read -r -p "  " line
        fi
        
        # If first line is empty, exit
        if [ $line_count -eq 0 ] && [ -z "$line" ]; then
            break
        fi
        
        # If line is empty and we have content, finish
        if [ -z "$line" ] && [ -n "$input" ]; then
            break
        fi
        
        # Add line to input
        if [ -n "$input" ]; then
            input="$input
$line"
        else
            input="$line"
        fi
        
        line_count=$((line_count + 1))
        
        # Safety limit to prevent infinite input
        if [ $line_count -gt 100 ]; then
            echo -e "${YELLOW}⚠️  Input limit reached (100 lines). Proceeding with current input.${NC}"
            break
        fi
    done
    
    echo "$input"
}

# Show usage
show_usage() {
    echo -e "${CYAN}Usage: taco [options]${NC}"
    echo -e "${YELLOW}Options:${NC}"
    echo "  -f, --file <path>     Load project description from file"
    echo "  -p, --prompt <text>   Provide project description directly"
    echo "  -h, --help           Show this help message"
    echo "  -v, --version        Show version information"
    echo
    echo -e "${CYAN}Examples:${NC}"
    echo "  taco -f project_spec.txt"
    echo "  taco -p \"Build a React app with Express backend\""
    echo "  taco  # Interactive mode"
}

# Show version
show_version() {
    echo -e "${BLUE}🌮 TACO - Tmux Agent Command Orchestrator v${TACO_VERSION}${NC}"
}