#!/usr/bin/env bash
# TACO - Tmux Agent Command Orchestrator
# Common functions and configuration

# Configuration
export TACO_VERSION="2.0.0"
export PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
export ORCHESTRATOR_DIR="$PROJECT_DIR/.orchestrator"
export SESSION_NAME="${ORCHESTRATOR_SESSION:-taco}"
export CONFIG_FILE="${HOME}/.orchestrator/config"

# Load configuration if exists
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

# Default configuration values
export ORCHESTRATOR_TIMEOUT="${ORCHESTRATOR_TIMEOUT:-90}"
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

# Safe tmux send-keys with delay and Enter
send_tmux_command() {
    local target="$1"
    local command="$2"
    local delay="${3:-0.1}"
    
    tmux send-keys -t "$target" "$command"
    sleep "$delay"
    tmux send-keys -t "$target" Enter
}

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

    if pgrep -f "claude.*--dangerously-skip|codex.*--full-auto|gemini.*--yolo|codex|gemini" >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Found running CLI agents (Claude/Codex/Gemini)${NC}"
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
    echo -e "${CYAN}TACO v2.0.0 - Tmux Agent Command Orchestrator${NC}"
    echo
    echo -e "${YELLOW}Usage:${NC} taco [options]"
    echo
    echo -e "${GREEN}Core Options:${NC}"
    echo "  -f, --file <path>       Load project from file"
    echo "  -p, --prompt <text>     Direct project description"
    echo "  -m, --model <name>      Claude model (sonnet|opus)"
    echo "  -h, --help              Show this help"
    echo "  -v, --version           Show version"
    echo
    echo -e "${GREEN}Orchestration:${NC}"
    echo "  --hybrid                Enable parallel multi-agent execution"
    echo "  --cache                 Enable prompt caching for efficiency"
    echo "  --think <mode>          Set thinking mode (think|think_hard|ultrathink)"
    echo "  --mcp-servers <list>    Enable MCP servers (filesystem,git,postgres,etc)"
    echo
    echo -e "${GREEN}Agent Selection:${NC}"
    echo "  --claude                Use Claude (default)"
    echo "  --openai                Use OpenAI GPT-4"
    echo "  --gemini                Use Google Gemini"
    echo "  --codex                 Use GitHub Copilot (OpenAI Codex)"
    echo "  --llama                 Use local Llama"
    echo
    echo -e "${GREEN}Feature Toggles:${NC}"
    echo "  --no-mcp                Disable MCP servers"
    echo "  --no-subagents          Disable Claude sub-agents"
    echo "  --no-cache              Disable caching"
    echo
    echo -e "${CYAN}Examples:${NC}"
    echo "  taco --hybrid --cache -f spec.txt"
    echo "  taco --think ultrathink -p \"Complex architecture\""
    echo "  taco --mcp-servers filesystem,git,postgres -f project.txt"
    echo "  taco  # Interactive mode"
}

# Show version
show_version() {
    echo -e "${BLUE}🌮 TACO - Tmux Agent Command Orchestrator v${TACO_VERSION}${NC}"
}

# Get agent command based on type and flags
get_agent_command() {
    # Optional first arg: explicit agent type
    local explicit_type="$1"
    local agent_type
    if [ -n "$explicit_type" ]; then
        agent_type="$explicit_type"
    else
        agent_type="${TACO_AGENT_TYPE:-claude}"
    fi
    local agent_flags="${TACO_AGENT_FLAGS:-}"
    local model_flag=""
    # Guard against unset or literal "null" model
    if [ -n "$TACO_CLAUDE_MODEL" ] && [ "$TACO_CLAUDE_MODEL" != "null" ]; then
        model_flag="--model $TACO_CLAUDE_MODEL"
    fi
    
    case "$agent_type" in
        claude)
            # Safe default; rely on interactive continuation for steady state
            echo "claude --continue $model_flag"
            ;;
        codex)
            if [ -n "$agent_flags" ]; then
                echo "codex $agent_flags"
            else
                echo "codex"
            fi
            ;;
        gemini)
            if [ -n "$agent_flags" ]; then
                echo "gemini $agent_flags"
            else
                echo "gemini"
            fi
            ;;
        openai)
            echo "openai"  # assumes an installed CLI; otherwise use multi-agent wrappers
            ;;
        anthropic_api)
            echo "claude"  # fallback to Claude CLI for interactive; API wrapper available in multi-agent
            ;;
        llama)
            echo "ollama run llama3:70b"
            ;;
        mistral)
            echo "mistral-cli"
            ;;
        *)
            # Default to Claude if unknown
            echo "claude --continue $model_flag"
            ;;
    esac
}
