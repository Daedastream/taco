#!/opt/homebrew/bin/bash

# TACO - Test-Aware Coordinated Orchestrator
# Enhanced orchestrator with testing, debugging, and connection management

set -e

# Configuration
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
ORCHESTRATOR_DIR="$PROJECT_DIR/.orchestrator"
SESSION_NAME="${ORCHESTRATOR_SESSION:-taco}"
CONFIG_FILE="${HOME}/.orchestrator/config"

# Load configuration if exists
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

# Default configuration values
ORCHESTRATOR_TIMEOUT="${ORCHESTRATOR_TIMEOUT:-45}"
ORCHESTRATOR_MAX_RETRIES="${ORCHESTRATOR_MAX_RETRIES:-3}"
ORCHESTRATOR_LOG_LEVEL="${ORCHESTRATOR_LOG_LEVEL:-INFO}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

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

echo -e "${BLUE}🌮 TACO - Test-Aware Coordinated Orchestrator v1.0${NC}"

# Check for command line arguments
PROMPT_FILE=""
SKIP_INTERACTIVE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            PROMPT_FILE="$2"
            SKIP_INTERACTIVE=true
            shift 2
            ;;
        -p|--prompt)
            user_prompt="$2"
            SKIP_INTERACTIVE=true
            shift 2
            ;;
        -h|--help)
            echo -e "${CYAN}Usage: $0 [options]${NC}"
            echo -e "${YELLOW}Options:${NC}"
            echo "  -f, --file <path>     Load project description from file"
            echo "  -p, --prompt <text>   Provide project description directly"
            echo "  -h, --help           Show this help message"
            echo
            echo -e "${CYAN}Examples:${NC}"
            echo "  $0 -f project_spec.txt"
            echo "  $0 -p \"Build a React app with Express backend\""
            echo "  $0  # Interactive mode"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

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

# Arrays to store pane mappings and agent info
declare -A pane_mapping
declare -A agent_roles
declare -A agent_addresses

# Get pane address for agent with validation
get_pane_address() {
    local window_num=$1
    local agent_name=$2
    local pane_address
    
    if [ "$DISPLAY_MODE" = "panes" ]; then
        if [ "$window_num" -eq 0 ]; then
            pane_address="$SESSION_NAME:0.0"  # Mother
        elif [ "$window_num" -eq 1 ]; then
            pane_address="$SESSION_NAME:1.0"  # Monitor
        else
            # Agents in window 2
            if [ -n "${pane_mapping[$window_num]}" ]; then
                pane_address="$SESSION_NAME:2.${pane_mapping[$window_num]}"
            else
                # Fallback to window mode if pane mapping failed
                pane_address="$SESSION_NAME:$window_num.0"
            fi
        fi
    else
        pane_address="$SESSION_NAME:$window_num.0"
    fi
    
    # Validate pane exists
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        if ! tmux list-panes -t "$pane_address" >/dev/null 2>&1; then
            log "WARN" "PANE-ADDR" "Pane $pane_address does not exist for $agent_name"
            # Try fallback to window mode
            pane_address="$SESSION_NAME:$window_num.0"
        fi
    fi
    
    echo "$pane_address"
}

# Create connection registry for tracking ports and endpoints
create_connection_registry() {
    local registry_file="$ORCHESTRATOR_DIR/connections.json"
    cat > "$registry_file" << 'EOF'
{
    "services": {},
    "endpoints": {},
    "ports": {},
    "database_urls": {},
    "api_keys": {},
    "test_results": {},
    "build_status": {}
}
EOF
    log "INFO" "REGISTRY" "Created connection registry at $registry_file"
}

# Create message relay script for better agent-to-mother communication
create_message_relay() {
    local relay_script="$ORCHESTRATOR_DIR/message_relay.sh"
    cat > "$relay_script" << 'EOF'
#!/bin/bash
# Message Relay - Ensures messages to Mother are properly executed

send_to_mother() {
    local message="$1"
    local session_name="${2:-taco}"
    
    # Validate session exists
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        echo "ERROR: Session $session_name not found" >&2
        return 1
    fi
    
    # Validate Mother pane exists
    if ! tmux list-panes -t "$session_name:0.0" >/dev/null 2>&1; then
        echo "ERROR: Mother pane not found" >&2
        return 1
    fi
    
    # Clear any existing input in Mother's pane
    tmux send-keys -t "$session_name:0.0" C-u
    sleep 0.2
    
    # Send message using buffer method for reliability
    printf '%s' "$message" | tmux load-buffer -
    tmux paste-buffer -t "$session_name:0.0"
    
    # Send Enter to execute
    sleep 0.2
    tmux send-keys -t "$session_name:0.0" Enter
    
    # Log the message
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [RELAY] Sent to Mother: $message" >> "$(dirname "$0")/communication.log"
}

# Send message to specific agent with validation
send_to_agent() {
    local target_window="$1"
    local message="$2"
    local session_name="${3:-taco}"
    
    # Validate session exists
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        echo "ERROR: Session $session_name not found" >&2
        return 1
    fi
    
    # Determine target pane based on display mode
    local target_pane
    if grep -q 'DISPLAY_MODE="panes"' "$(dirname "$0")/state.json" 2>/dev/null; then
        if [ "$target_window" -eq 0 ]; then
            target_pane="$session_name:0.0"
        elif [ "$target_window" -eq 1 ]; then
            target_pane="$session_name:1.0"
        else
            # Try to find pane mapping
            local pane_idx=$((target_window - 2))
            target_pane="$session_name:2.$pane_idx"
        fi
    else
        target_pane="$session_name:$target_window.0"
    fi
    
    # Validate target pane exists
    if ! tmux list-panes -t "$target_pane" >/dev/null 2>&1; then
        echo "ERROR: Target pane $target_pane not found" >&2
        return 1
    fi
    
    # Send message
    printf '%s' "$message" | tmux load-buffer -
    tmux paste-buffer -t "$target_pane"
    tmux send-keys -t "$target_pane" Enter
    
    # Log the message
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [RELAY] Sent to Agent $target_window: $message" >> "$(dirname "$0")/communication.log"
}

# Usage: message_relay.sh "Your message here" [target_window]
if [ "$#" -eq 1 ]; then
    send_to_mother "$1"
elif [ "$#" -eq 2 ]; then
    send_to_agent "$2" "$1"
else
    echo "Usage: $0 \"message\" [target_window]"
    echo "Examples:"
    echo "  $0 \"[AGENT-2 → MOTHER]: Tests completed successfully\""
    echo "  $0 \"[AGENT-2 → AGENT-3]: API ready\" 3"
fi
EOF
    chmod +x "$relay_script"
    log "INFO" "RELAY" "Created enhanced message relay script"
}

# Create test coordinator script
create_test_coordinator() {
    local test_script="$ORCHESTRATOR_DIR/test_coordinator.sh"
    cat > "$test_script" << 'EOF'
#!/bin/bash
# Test Coordinator - Manages test execution and result distribution

ORCHESTRATOR_DIR="$(dirname "$0")"
CONNECTIONS_FILE="$ORCHESTRATOR_DIR/connections.json"
TEST_LOG="$ORCHESTRATOR_DIR/test_results.log"

# Run tests and capture results
run_tests() {
    local test_type="$1"
    local agent="$2"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    echo "[$timestamp] Running $test_type tests for $agent" >> "$TEST_LOG"
    
    # Capture test output based on type
    case $test_type in
        unit)
            npm test 2>&1 | tee -a "$TEST_LOG"
            ;;
        integration)
            npm run test:integration 2>&1 | tee -a "$TEST_LOG"
            ;;
        e2e)
            npm run test:e2e 2>&1 | tee -a "$TEST_LOG"
            ;;
        api)
            # Test all registered endpoints
            jq -r '.endpoints | to_entries[] | "\(.key) \(.value)"' "$CONNECTIONS_FILE" | while read name url; do
                echo "Testing endpoint: $name at $url"
                curl -s -o /dev/null -w "%{http_code}" "$url" | tee -a "$TEST_LOG"
            done
            ;;
    esac
}

# Parse test failures and notify responsible agents
notify_test_failures() {
    local failures=$(grep -E "FAIL|ERROR|Failed" "$TEST_LOG" | tail -20)
    if [ -n "$failures" ]; then
        # Determine which agent should fix based on failure type
        if echo "$failures" | grep -q "frontend\|component\|ui"; then
            tmux send-keys -t taco:2.0 "TEST FAILURES DETECTED: $failures"
            tmux send-keys -t taco:2.0 Enter
        fi
        if echo "$failures" | grep -q "backend\|api\|endpoint"; then
            tmux send-keys -t taco:2.1 "TEST FAILURES DETECTED: $failures"
            tmux send-keys -t taco:2.1 Enter
        fi
        if echo "$failures" | grep -q "database\|schema\|migration"; then
            tmux send-keys -t taco:2.2 "TEST FAILURES DETECTED: $failures"
            tmux send-keys -t taco:2.2 Enter
        fi
    fi
}

# Monitor build processes
monitor_builds() {
    while true; do
        # Check for build errors in common locations
        for build_log in */build.log */logs/build.log .next/build-error.log; do
            if [ -f "$build_log" ] && grep -q "ERROR\|FAIL" "$build_log"; then
                echo "Build error detected in $build_log"
                notify_test_failures
            fi
        done
        sleep 5
    done
}

# Start monitoring based on arguments
case "$1" in
    test) run_tests "$2" "$3" ;;
    monitor) monitor_builds ;;
    notify) notify_test_failures ;;
    *) echo "Usage: $0 {test|monitor|notify}" ;;
esac
EOF
    chmod +x "$test_script"
    log "INFO" "TEST-COORD" "Created test coordinator script"
}

# Create connection validator
create_connection_validator() {
    local validator_script="$ORCHESTRATOR_DIR/validate_connections.sh"
    cat > "$validator_script" << 'EOF'
#!/bin/bash
# Connection Validator - Ensures all services can communicate

ORCHESTRATOR_DIR="$(dirname "$0")"
CONNECTIONS_FILE="$ORCHESTRATOR_DIR/connections.json"
VALIDATION_LOG="$ORCHESTRATOR_DIR/validation.log"

validate_all_connections() {
    echo "=== CONNECTION VALIDATION REPORT ===" > "$VALIDATION_LOG"
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$VALIDATION_LOG"
    echo >> "$VALIDATION_LOG"
    
    # Validate all registered services
    jq -r '.services | to_entries[] | "\(.key) \(.value)"' "$CONNECTIONS_FILE" | while read service url; do
        echo "Checking $service at $url..." >> "$VALIDATION_LOG"
        if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|201\|204"; then
            echo "✓ $service is accessible" >> "$VALIDATION_LOG"
        else
            echo "✗ $service is NOT accessible" >> "$VALIDATION_LOG"
            # Notify Mother about connection issue
            tmux send-keys -t taco:0.0 "CONNECTION ISSUE: $service at $url is not accessible"
            tmux send-keys -t taco:0.0 Enter
        fi
    done
    
    # Check for port conflicts
    echo >> "$VALIDATION_LOG"
    echo "Port Usage:" >> "$VALIDATION_LOG"
    jq -r '.ports | to_entries[] | "\(.key): \(.value)"' "$CONNECTIONS_FILE" >> "$VALIDATION_LOG"
    
    # Check for localhost vs docker networking issues
    if jq -r '.services | to_entries[].value' "$CONNECTIONS_FILE" | grep -q "localhost"; then
        if docker ps -q 2>/dev/null | wc -l | grep -q "[1-9]"; then
            echo "⚠️  WARNING: Using 'localhost' with Docker containers running!" >> "$VALIDATION_LOG"
            echo "Consider using 'host.docker.internal' or container names instead." >> "$VALIDATION_LOG"
        fi
    fi
}

# Run validation
validate_all_connections

# Show results
cat "$VALIDATION_LOG"
EOF
    chmod +x "$validator_script"
    log "INFO" "VALIDATOR" "Created connection validator script"
}

# Enhanced monitor with test results, connection status, and elapsed time
create_enhanced_monitor() {
    cat > "$ORCHESTRATOR_DIR/show_status.sh" << 'EOF'
#!/bin/bash
ORCHESTRATOR_DIR="$(dirname "$0")"
STATE_FILE="$ORCHESTRATOR_DIR/state.json"
SESSION_NAME="taco"

# Calculate elapsed time
calculate_elapsed_time() {
    if [ -f "$STATE_FILE" ]; then
        if command -v jq >/dev/null 2>&1; then
            local start_time=$(jq -r '.start_time' "$STATE_FILE" 2>/dev/null)
            if [ "$start_time" != "null" ] && [ -n "$start_time" ]; then
                local start_epoch=$(date -d "$start_time" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$start_time" +%s 2>/dev/null)
                local current_epoch=$(date +%s)
                local elapsed=$((current_epoch - start_epoch))
                
                local hours=$((elapsed / 3600))
                local minutes=$(((elapsed % 3600) / 60))
                local seconds=$((elapsed % 60))
                
                printf "%02d:%02d:%02d" $hours $minutes $seconds
            else
                echo "00:00:00"
            fi
        else
            # Fallback without jq - extract timestamp from file
            local start_time=$(grep -o '"start_time": *"[^"]*"' "$STATE_FILE" | cut -d'"' -f4)
            if [ -n "$start_time" ]; then
                local start_epoch=$(date -d "$start_time" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$start_time" +%s 2>/dev/null)
                local current_epoch=$(date +%s)
                local elapsed=$((current_epoch - start_epoch))
                
                local hours=$((elapsed / 3600))
                local minutes=$(((elapsed % 3600) / 60))
                local seconds=$((elapsed % 60))
                
                printf "%02d:%02d:%02d" $hours $minutes $seconds
            else
                echo "00:00:00"
            fi
        fi
    else
        echo "00:00:00"
    fi
}

# Check if session exists
if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    clear
    echo "=== TACO STATUS MONITOR ==="
    echo
    echo "❌ TACO session not found"
    echo "   Session '$SESSION_NAME' is not running"
    echo
    echo "To start TACO, run: ./taco.sh"
    exit 1
fi

clear
echo "=== TACO STATUS MONITOR ==="
echo "⏱️  Elapsed Time: $(calculate_elapsed_time)"
echo "📅 Current Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo

# Show session info
echo "SESSION INFO:"
tmux_info=$(tmux display-message -t "$SESSION_NAME" -p "#{session_name} (#{session_windows} windows, #{session_clients} clients)")
echo "  Session: $tmux_info"
echo

echo "WINDOWS:"
if tmux list-windows -t "$SESSION_NAME" >/dev/null 2>&1; then
    tmux list-windows -t "$SESSION_NAME" -F "  #I: #W#{?window_active, (active),} - #{pane_current_command}"
else
    echo "  No windows found"
fi
echo

echo "RECENT MESSAGES:"
if [ -f "$ORCHESTRATOR_DIR/communication.log" ]; then
    tail -8 "$ORCHESTRATOR_DIR/communication.log" | sed 's/^/  /' | cut -c1-80
else
    echo "  No messages yet"
fi
echo

echo "TEST STATUS:"
if [ -f "$ORCHESTRATOR_DIR/test_results.log" ]; then
    echo "  Recent test results:"
    tail -5 "$ORCHESTRATOR_DIR/test_results.log" | sed 's/^/    /' | cut -c1-80
    
    # Count test results
    local passed=$(grep -c "PASS\|✓\|passed" "$ORCHESTRATOR_DIR/test_results.log" 2>/dev/null || echo 0)
    local failed=$(grep -c "FAIL\|✗\|failed\|ERROR" "$ORCHESTRATOR_DIR/test_results.log" 2>/dev/null || echo 0)
    echo "  Summary: $passed passed, $failed failed"
else
    echo "  No tests run yet"
fi
echo

echo "CONNECTION REGISTRY:"
if [ -f "$ORCHESTRATOR_DIR/connections.json" ]; then
    echo "  Services:"
    if command -v jq >/dev/null 2>&1; then
        if jq -e '.services | length > 0' "$ORCHESTRATOR_DIR/connections.json" >/dev/null 2>&1; then
            jq -r '.services | to_entries[] | "    \(.key): \(.value)"' "$ORCHESTRATOR_DIR/connections.json" 2>/dev/null | head -5
        else
            echo "    No services registered"
        fi
    else
        # Fallback parsing without jq
        grep -o '"services":[^}]*}' "$ORCHESTRATOR_DIR/connections.json" | head -3 | sed 's/^/    /'
    fi
    
    echo "  Ports:"
    if command -v jq >/dev/null 2>&1; then
        if jq -e '.ports | length > 0' "$ORCHESTRATOR_DIR/connections.json" >/dev/null 2>&1; then
            jq -r '.ports | to_entries[] | "    \(.key): \(.value)"' "$ORCHESTRATOR_DIR/connections.json" 2>/dev/null | head -5
        else
            echo "    No ports registered"
        fi
    else
        # Fallback parsing without jq
        grep -o '"ports":[^}]*}' "$ORCHESTRATOR_DIR/connections.json" | head -3 | sed 's/^/    /'
    fi
else
    echo "  Connection registry not found"
fi
echo

echo "BUILD STATUS:"
if [ -f "$ORCHESTRATOR_DIR/connections.json" ]; then
    if command -v jq >/dev/null 2>&1; then
        if jq -e '.build_status | length > 0' "$ORCHESTRATOR_DIR/connections.json" >/dev/null 2>&1; then
            jq -r '.build_status | to_entries[] | "  \(.key): \(.value)"' "$ORCHESTRATOR_DIR/connections.json" 2>/dev/null
        else
            echo "  No build status available"
        fi
    else
        # Fallback parsing without jq
        if grep -q '"build_status"' "$ORCHESTRATOR_DIR/connections.json"; then
            grep -o '"build_status":[^}]*}' "$ORCHESTRATOR_DIR/connections.json" | head -3 | sed 's/^/  /'
        else
            echo "  No build status available"
        fi
    fi
else
    echo "  Build status not available"
fi
echo

# Show project info
if [ -f "$STATE_FILE" ]; then
    echo "PROJECT INFO:"
    if command -v jq >/dev/null 2>&1; then
        local project_name=$(jq -r '.project' "$STATE_FILE" 2>/dev/null)
        local project_dir=$(jq -r '.project_dir' "$STATE_FILE" 2>/dev/null)
        local agent_count=$(jq -r '.agent_count' "$STATE_FILE" 2>/dev/null)
        
        [ "$project_name" != "null" ] && echo "  Project: $project_name"
        [ "$project_dir" != "null" ] && echo "  Directory: $project_dir"
        [ "$agent_count" != "null" ] && echo "  Agents: $agent_count"
    else
        # Fallback parsing without jq
        local project_name=$(grep -o '"project": *"[^"]*"' "$STATE_FILE" | cut -d'"' -f4)
        local project_dir=$(grep -o '"project_dir": *"[^"]*"' "$STATE_FILE" | cut -d'"' -f4)
        local agent_count=$(grep -o '"agent_count": *[0-9]*' "$STATE_FILE" | cut -d':' -f2 | tr -d ' ')
        
        [ -n "$project_name" ] && echo "  Project: $project_name"
        [ -n "$project_dir" ] && echo "  Directory: $project_dir"
        [ -n "$agent_count" ] && echo "  Agents: $agent_count"
    fi
fi

echo
echo "💡 Press Ctrl+C to exit monitor, Ctrl+b + d to detach from session"
EOF
    chmod +x "$ORCHESTRATOR_DIR/show_status.sh"
    log "INFO" "MONITOR" "Created enhanced status monitor with elapsed time"
}

# Save orchestrator state
save_state() {
    local state_file="$ORCHESTRATOR_DIR/state.json"
    cat > "$state_file" << EOF
{
    "project": "$user_prompt",
    "project_dir": "$PROJECT_DIR",
    "session": "$SESSION_NAME",
    "start_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "agent_count": ${#agent_specs[@]},
    "testing_enabled": true,
    "connection_validation": true,
    "agents": [
EOF
    
    local first=true
    for spec in "${agent_specs[@]}"; do
        IFS=':' read -r window_num agent_name agent_role <<< "$spec"
        [ "$first" = true ] && first=false || echo "," >> "$state_file"
        cat >> "$state_file" << EOF
        {
            "window": $window_num,
            "name": "$agent_name",
            "role": "$agent_role"
        }
EOF
    done
    
    echo -e "\n    ]\n}" >> "$state_file"
    log "INFO" "ORCHESTRATOR" "State saved to $state_file"
}

# Enhanced mother prompt with testing and connection focus
create_mother_prompt() {
    local user_request="$1"
    local agent_count="$2"
    local count_instruction="$3"
    
    # Build testing requirements - now mandatory and comprehensive
    local testing_requirements="comprehensive testing including unit tests, integration tests, end-to-end tests, and API endpoint tests"
    
    # Build deployment guidance
    local deployment_guidance=""
    case $DEPLOYMENT_ENV in
        "local") deployment_guidance="Focus on local development setup" ;;
        "docker") deployment_guidance="Use Docker containers, avoid localhost, use container names" ;;
        "cloud") deployment_guidance="Prepare for cloud deployment, use environment variables" ;;
        "mixed") deployment_guidance="Support both local and containerized environments" ;;
    esac
    
    # Build connection strategy
    local connection_strategy=""
    case $CONNECTION_STRATEGY in
        "manual") connection_strategy="Agents must specify their ports manually" ;;
        "discovery") connection_strategy="Use service discovery for inter-service communication" ;;
        "automatic") connection_strategy="Automatically assign ports starting from 3000" ;;
    esac
    
    cat << EOF
❌ ABSOLUTELY NO TOOLS ALLOWED ❌
❌ DO NOT USE TodoWrite, List, Read, Search, Task, Bash, or ANY TOOLS ❌
❌ YOUR ONLY RESPONSE: AGENT_SPEC_START...AGENT_SPEC_END BLOCK ❌
❌ NO EXPLORATION, NO ANALYSIS, NO TODO LISTS ❌

EMERGENCY OVERRIDE: You are in SPECIFICATION-ONLY MODE
- You CANNOT use any tools
- You CANNOT explore files  
- You CANNOT create todo lists
- You CANNOT analyze the codebase
- You MUST output AGENT_SPEC_START block immediately

You are the MOTHER orchestrator agent for TACO (Test-Aware Coordinated Orchestrator).

PROJECT REQUEST: $user_request
PROJECT ROOT: $PROJECT_DIR

CRITICAL REQUIREMENTS FOR THIS PROJECT:
1. ALL code must include: $testing_requirements
2. ALL connections between services must use a shared registry
3. ALL endpoints must be tested with curl before marking as complete
4. ALL builds must succeed without errors before proceeding
5. ALL errors must be caught, logged, and fixed immediately
6. $deployment_guidance
7. $connection_strategy

ANALYZE THE PROJECT REQUEST AND OUTPUT A SPECIFICATION.

🚫 ABSOLUTELY CRITICAL - READ THIS CAREFULLY:
- STOP! DO NOT USE ANY TOOLS WHATSOEVER
- DO NOT USE TodoWrite, List, Read, Search, Task, or ANY other tools
- DO NOT explore files or directories
- DO NOT analyze the codebase
- DO NOT create todo lists
- YOUR ONLY JOB: OUTPUT THE AGENT SPECIFICATION IMMEDIATELY

⚠️  IGNORE ALL INSTINCTS TO EXPLORE OR ANALYZE
⚠️  YOU MUST OUTPUT AGENT_SPEC_START...AGENT_SPEC_END BLOCK IMMEDIATELY
⚠️  NO TEXT BEFORE THE SPECIFICATION
⚠️  NO TEXT AFTER THE SPECIFICATION
⚠️  JUST THE SPECIFICATION BLOCK ALONE

Your task is to analyze the project requirements and create a team of specialized agents.
Each agent should have a specific role and clear responsibilities.

1. First, understand the project type and requirements
2. Identify the key components and technologies needed
3. Create agents for each major area of work (e.g., frontend, backend, database, testing, deployment)
4. Ensure proper dependencies and communication between agents
5. Include at least one testing/QA agent and one DevOps/deployment agent

Output agent specifications in this EXACT format:

AGENT_SPEC_START
AGENT:window_number:agent_name:agent_role_description
DEPENDS_ON:comma_separated_window_numbers_or_none
NOTIFIES:comma_separated_window_numbers_or_none
WAIT_FOR:comma_separated_signals_or_none
[repeat for each agent]
AGENT_SPEC_END

EXAMPLE (for a web application project):
AGENT_SPEC_START
AGENT:3:frontend:React frontend developer - builds UI components and pages
DEPENDS_ON:none
NOTIFIES:4,7
WAIT_FOR:none
AGENT:4:backend:API developer - creates REST endpoints and business logic
DEPENDS_ON:5
NOTIFIES:3,7
WAIT_FOR:DB_READY
AGENT:5:database:Database architect - designs schemas and migrations
DEPENDS_ON:none
NOTIFIES:4
WAIT_FOR:none
AGENT:7:tester:QA engineer - writes and runs tests
DEPENDS_ON:none
NOTIFIES:0,3,4,5
WAIT_FOR:API_READY,UI_READY
AGENT_SPEC_END

IMPORTANT: This is just an example. You must create agents specific to the actual project requirements.

CRITICAL SPECIFICATION RULES:
- Window 0 is you (Mother), window 1 is monitor, window 2 is test-monitor
- Start agents at window 3 and increment sequentially (3, 4, 5, 6, etc.)
- NEVER reuse window numbers - each agent gets a unique number
- NEVER create duplicate agent names - each must be unique and have distinct responsibilities
- Create 2-15 agents total (optimal range for parallel development)
- Include a dedicated testing agent and deployment/DevOps agent
- Each agent should handle a specific, well-defined domain of work
- Agents should be designed for maximum parallel development with minimal conflicts
- Design dependencies carefully - avoid circular dependencies
- Agent names should clearly reflect their unique function (e.g., 'webui', 'mobileapp', 'apiserver', 'userauth', 'database', 'testing', 'deployment')

AGENT DESIGN PRINCIPLES:
- Analyze the project type first (web app, CLI tool, library, mobile app, etc.)
- Identify the technology stack from the request (React, Vue, Express, Django, etc.)
- Create agents based on the actual components needed, not a fixed template
- Consider the project complexity when deciding agent count
- For simple projects: fewer agents with broader responsibilities
- For complex projects: more specialized agents with focused roles
- Always include testing and deployment agents, but adapt their roles to the project
- Divide work by functional boundaries, not arbitrary splits
- Ensure each agent can work independently on their domain
- Use DEPENDS_ON and WAIT_FOR to coordinate between agents
- Design for parallel work - minimize bottlenecks

$count_instruction

CONNECTION REGISTRY:
After creating agents, you MUST establish a connection registry by having each agent register their services:

Example:
tmux send-keys -t taco:3.0 "echo '{\"services\": {\"api\": \"http://localhost:3001\"}, \"ports\": {\"api\": 3001}}' | jq -s '.[0] * .[1]' $PROJECT_DIR/.orchestrator/connections.json - > /tmp/conn.json && mv /tmp/conn.json $PROJECT_DIR/.orchestrator/connections.json"
tmux send-keys -t taco:3.0 Enter

🚨 FINAL WARNING: OUTPUT AGENT_SPEC_START BLOCK NOW! NO TOOLS! NO ANALYSIS! JUST THE SPECIFICATION!
EOF
}

# Run safety check
check_critical_processes

# Get project description
if [ "$SKIP_INTERACTIVE" = false ]; then
    echo -e "${CYAN}🎯 PROJECT SETUP${NC}"
    echo
    echo -e "${YELLOW}What would you like to build?${NC}"
    echo -e "${CYAN}💡 You can provide a detailed description. Press Enter on empty line to finish.${NC}"
    echo -e "${CYAN}💡 Or type a single line and press Enter.${NC}"
    echo -e "${CYAN}💡 Or type 'file:' followed by a path to load from file.${NC}"
    echo
    
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
    
    user_prompt=$(read_multiline_input)
elif [ -n "$PROMPT_FILE" ]; then
    # Load from file specified via command line
    if [ -f "$PROMPT_FILE" ]; then
        echo -e "${CYAN}📄 Loading project description from: $PROMPT_FILE${NC}"
        user_prompt=$(cat "$PROMPT_FILE")
        echo -e "${GREEN}✅ Loaded $(echo "$user_prompt" | wc -l) lines from file${NC}"
    else
        echo -e "${RED}❌ File not found: $PROMPT_FILE${NC}"
        exit 1
    fi
elif [ -n "$user_prompt" ]; then
    # Prompt provided via command line
    echo -e "${CYAN}📋 Using provided project description${NC}"
fi

# Check if user wants to load from file (interactive mode only)
if [ "$SKIP_INTERACTIVE" = false ] && [[ "$user_prompt" =~ ^file:(.+)$ ]]; then
    file_path="${BASH_REMATCH[1]}"
    file_path="${file_path# }"  # Remove leading space
    
    if [ -f "$file_path" ]; then
        echo -e "${CYAN}📄 Loading from file: $file_path${NC}"
        user_prompt=$(cat "$file_path")
        echo -e "${GREEN}✅ Loaded $(echo "$user_prompt" | wc -l) lines from file${NC}"
    else
        echo -e "${RED}❌ File not found: $file_path${NC}"
        echo -e "${YELLOW}Let's try again...${NC}"
        echo
        user_prompt=$(read_multiline_input)
    fi
fi

if [ -z "$user_prompt" ]; then
    echo -e "${RED}❌ No project description provided. Exiting.${NC}"
    exit 1
fi

# Show confirmation of the input (interactive mode only)
if [ "$SKIP_INTERACTIVE" = false ]; then
    echo
    echo -e "${CYAN}📋 Project Description:${NC}"
    line_count=$(echo "$user_prompt" | wc -l)
    char_count=$(echo "$user_prompt" | wc -c)

    if [ $line_count -gt 10 ] || [ $char_count -gt 500 ]; then
        echo -e "${YELLOW}   📊 Large input detected: $line_count lines, $char_count characters${NC}"
        echo -e "${YELLOW}   First 10 lines preview:${NC}"
        echo "$user_prompt" | head -10 | sed 's/^/   /'
        [ $line_count -gt 10 ] && echo -e "${YELLOW}   ... (and $((line_count - 10)) more lines)${NC}"
    else
        echo "$user_prompt" | sed 's/^/   /'
    fi

    echo
    echo -e "${YELLOW}Is this correct? (Y/n/v to view full text):${NC}"
    read -r -p "> " confirm_prompt

    case "$confirm_prompt" in
        [Vv]*)
            echo
            echo -e "${CYAN}📋 Full Project Description:${NC}"
            echo "$user_prompt" | sed 's/^/   /'
            echo
            echo -e "${YELLOW}Is this correct? (Y/n):${NC}"
            read -r -p "> " confirm_prompt
            ;;
    esac

    if [[ "$confirm_prompt" =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}Let's try again...${NC}"
        echo
        user_prompt=$(read_multiline_input)
        
        # Check for file input again
        if [[ "$user_prompt" =~ ^file:(.+)$ ]]; then
            file_path="${BASH_REMATCH[1]}"
            file_path="${file_path# }"
            
            if [ -f "$file_path" ]; then
                echo -e "${CYAN}📄 Loading from file: $file_path${NC}"
                user_prompt=$(cat "$file_path")
                echo -e "${GREEN}✅ Loaded $(echo "$user_prompt" | wc -l) lines from file${NC}"
            else
                echo -e "${RED}❌ File not found: $file_path${NC}"
                echo -e "${RED}❌ No project description provided. Exiting.${NC}"
                exit 1
            fi
        fi
        
        if [ -z "$user_prompt" ]; then
            echo -e "${RED}❌ No project description provided. Exiting.${NC}"
            exit 1
        fi
    fi
fi

# Configuration with intelligent defaults
echo
echo -e "${CYAN}🔧 DEVELOPMENT CONFIGURATION${NC}"
echo -e "${GREEN}✅ Using optimized defaults for robust development${NC}"
echo

# Set comprehensive testing as non-negotiable
TESTING_STRATEGY="comprehensive"
echo -e "${YELLOW}Testing Strategy: ${GREEN}Comprehensive (unit + integration + e2e + api tests)${NC}"

# Detect Docker environment and set smart defaults
if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
    DEPLOYMENT_ENV="docker"
    echo -e "${YELLOW}Deployment Environment: ${GREEN}Docker containers (auto-detected)${NC}"
else
    DEPLOYMENT_ENV="local"
    echo -e "${YELLOW}Deployment Environment: ${GREEN}Local development (auto-detected)${NC}"
fi

# Always use automatic port assignment for simplicity
CONNECTION_STRATEGY="automatic"
echo -e "${YELLOW}Connection Management: ${GREEN}Automatic port assignment (recommended)${NC}"

# Set comprehensive debugging and testing as mandatory
ERROR_HANDLING="comprehensive"
CURL_TESTING="true"
BUILD_VALIDATION="true"
LOG_MONITORING="true"

echo -e "${YELLOW}Error Handling: ${GREEN}Comprehensive debugging (mandatory)${NC}"
echo -e "${YELLOW}Endpoint Testing: ${GREEN}Enabled with curl (mandatory)${NC}"
echo -e "${YELLOW}Build Validation: ${GREEN}Enabled (mandatory)${NC}"
echo -e "${YELLOW}Log Monitoring: ${GREEN}Enabled (mandatory)${NC}"
echo
echo -e "${CYAN}💡 All settings optimized for best practices. Manual override available via environment variables.${NC}"

# Ask if user wants to create a new folder
echo
echo -e "${YELLOW}Create project in a new folder? (Y/n)${NC}"
read -r -p "> " create_folder

if [[ ! "$create_folder" =~ ^[Nn]$ ]]; then
    echo -e "${YELLOW}Enter folder name (or press Enter for auto-generated):${NC}"
    read -r -p "> " project_folder
    
    if [ -z "$project_folder" ]; then
        project_folder=$(echo "$user_prompt" | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]' | cut -c1-20)
    fi
    
    PROJECT_DIR="$(pwd)/$project_folder-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    echo -e "${GREEN}✅ Created project directory: $PROJECT_DIR${NC}"
fi

# Update orchestrator directory
ORCHESTRATOR_DIR="$PROJECT_DIR/.orchestrator"
mkdir -p "$ORCHESTRATOR_DIR"

# Create port allocation helper with deployment awareness
create_port_helper() {
    local helper_script="$ORCHESTRATOR_DIR/port_helper.sh"
    cat > "$helper_script" << 'EOF'
#!/bin/bash
# Port Helper - Manages port allocation and conflicts with deployment awareness

ORCHESTRATOR_DIR="$(dirname "$0")"
CONNECTIONS_FILE="$ORCHESTRATOR_DIR/connections.json"

# Get deployment environment
get_deployment_env() {
    if command -v jq >/dev/null 2>&1; then
        jq -r '.deployment_env // "local"' "$CONNECTIONS_FILE" 2>/dev/null
    else
        echo "local"
    fi
}

# Get next available port based on deployment environment
get_next_port() {
    local start_port=${1:-3010}
    local deployment_env=$(get_deployment_env)
    
    # Adjust port range based on deployment environment
    case $deployment_env in
        "docker")
            start_port=${start_port:-8010}  # Higher ports for Docker
            ;;
        "cloud")
            start_port=${start_port:-8010}  # Higher ports for cloud
            ;;
        *)
            start_port=${start_port:-3010}  # Standard ports for local
            ;;
    esac
    
    local reserved_ports
    if command -v jq >/dev/null 2>&1; then
        reserved_ports=$(jq -r '.port_allocation.reserved[]' "$CONNECTIONS_FILE" 2>/dev/null | tr '\n' ' ')
    else
        reserved_ports="3000 3001 3002 3003 5432 6379 8080 9090"
    fi
    
    for port in $(seq $start_port 9999); do
        if ! echo "$reserved_ports" | grep -q "$port" && ! netstat -ln 2>/dev/null | grep -q ":$port "; then
            echo $port
            return
        fi
    done
    echo $start_port
}

# Allocate port to service with deployment-specific logic
allocate_port() {
    local service="$1"
    local preferred_port="$2"
    local deployment_env=$(get_deployment_env)
    
    # Apply deployment-specific port mapping
    if [ -z "$preferred_port" ]; then
        case $deployment_env in
            "docker")
                case $service in
                    "frontend") preferred_port=80 ;;
                    "backend") preferred_port=8000 ;;
                    "api") preferred_port=8001 ;;
                    "testing") preferred_port=8002 ;;
                    *) preferred_port=$(get_next_port) ;;
                esac
                ;;
            "cloud")
                case $service in
                    "frontend") preferred_port=80 ;;
                    "backend") preferred_port=8000 ;;
                    "api") preferred_port=8001 ;;
                    "testing") preferred_port=8002 ;;
                    *) preferred_port=$(get_next_port) ;;
                esac
                ;;
            *)
                case $service in
                    "frontend") preferred_port=3000 ;;
                    "backend") preferred_port=3001 ;;
                    "api") preferred_port=3002 ;;
                    "testing") preferred_port=3003 ;;
                    *) preferred_port=$(get_next_port) ;;
                esac
                ;;
        esac
    fi
    
    # Check if preferred port is available
    if netstat -ln 2>/dev/null | grep -q ":$preferred_port "; then
        echo "Port $preferred_port is already in use, finding alternative" >&2
        preferred_port=$(get_next_port)
    fi
    
    # Update registry
    if command -v jq >/dev/null 2>&1; then
        jq ".ports.\"$service\" = $preferred_port | .port_allocation.reserved += [$preferred_port]" "$CONNECTIONS_FILE" > /tmp/conn_update.json
        mv /tmp/conn_update.json "$CONNECTIONS_FILE"
    else
        echo "Port $preferred_port allocated to $service" >> "$ORCHESTRATOR_DIR/port_allocation.log"
    fi
    
    echo $preferred_port
}

# Show port usage with deployment context
show_ports() {
    local deployment_env=$(get_deployment_env)
    echo "=== PORT ALLOCATION ($deployment_env) ==="
    
    if command -v jq >/dev/null 2>&1; then
        jq -r '.ports | to_entries[] | "\(.key): \(.value)"' "$CONNECTIONS_FILE"
    else
        echo "jq not available - check $CONNECTIONS_FILE manually"
    fi
    
    echo
    echo "Next available: $(get_next_port)"
    echo "Deployment environment: $deployment_env"
}

# Generate Docker-compatible URLs
generate_docker_urls() {
    local service="$1"
    local port="$2"
    local deployment_env=$(get_deployment_env)
    
    case $deployment_env in
        "docker")
            echo "http://$service:$port"
            ;;
        "cloud")
            echo "https://$service.your-domain.com"
            ;;
        *)
            echo "http://localhost:$port"
            ;;
    esac
}

case "$1" in
    next) get_next_port "$2" ;;
    allocate) allocate_port "$2" "$3" ;;
    show) show_ports ;;
    docker-url) generate_docker_urls "$2" "$3" ;;
    *) echo "Usage: $0 {next|allocate|show|docker-url} [service] [port]" ;;
esac
EOF
    chmod +x "$helper_script"
    log "INFO" "PORT-HELPER" "Created deployment-aware port allocation helper"
}

# Create Docker compose generator for containerized deployments
create_docker_generator() {
    local docker_script="$ORCHESTRATOR_DIR/docker_generator.sh"
    cat > "$docker_script" << 'EOF'
#!/bin/bash
# Docker Generator - Creates docker-compose.yml based on services

ORCHESTRATOR_DIR="$(dirname "$0")"
CONNECTIONS_FILE="$ORCHESTRATOR_DIR/connections.json"
DOCKER_COMPOSE_FILE="docker-compose.yml"

# Generate docker-compose.yml from connection registry
generate_docker_compose() {
    local deployment_env
    if command -v jq >/dev/null 2>&1; then
        deployment_env=$(jq -r '.deployment_env // "local"' "$CONNECTIONS_FILE" 2>/dev/null)
    else
        deployment_env="local"
    fi
    
    if [ "$deployment_env" != "docker" ]; then
        echo "Deployment environment is not Docker, skipping compose generation"
        return 0
    fi
    
    cat > "$DOCKER_COMPOSE_FILE" << COMPOSE_EOF
version: '3.8'

services:
COMPOSE_EOF
    
    # Add services from registry
    if command -v jq >/dev/null 2>&1; then
        jq -r '.services | to_entries[] | "\(.key) \(.value)"' "$CONNECTIONS_FILE" | while read service_name service_url; do
            # Extract port from URL
            port=$(echo "$service_url" | grep -o ':[0-9]*' | tr -d ':')
            
            cat >> "$DOCKER_COMPOSE_FILE" << COMPOSE_EOF
  $service_name:
    build: ./$service_name
    ports:
      - "$port:$port"
    environment:
      - NODE_ENV=production
      - PORT=$port
    networks:
      - taco_network
    depends_on:
      - database
    restart: unless-stopped

COMPOSE_EOF
        done
    fi
    
    # Add common services
    cat >> "$DOCKER_COMPOSE_FILE" << COMPOSE_EOF
  database:
    image: postgres:15
    environment:
      - POSTGRES_DB=taco_db
      - POSTGRES_USER=taco_user
      - POSTGRES_PASSWORD=taco_pass
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - taco_network
    restart: unless-stopped

  redis:
    image: redis:7
    ports:
      - "6379:6379"
    networks:
      - taco_network
    restart: unless-stopped

networks:
  taco_network:
    driver: bridge

volumes:
  postgres_data:
COMPOSE_EOF
    
    echo "Docker Compose file generated: $DOCKER_COMPOSE_FILE"
}

# Generate Dockerfile for a service
generate_dockerfile() {
    local service_name="$1"
    local service_dir="$service_name"
    
    if [ ! -d "$service_dir" ]; then
        echo "Service directory $service_dir does not exist"
        return 1
    fi
    
    # Detect service type and generate appropriate Dockerfile
    if [ -f "$service_dir/package.json" ]; then
        # Node.js service
        cat > "$service_dir/Dockerfile" << DOCKERFILE_EOF
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE \$PORT

CMD ["npm", "start"]
DOCKERFILE_EOF
    elif [ -f "$service_dir/requirements.txt" ]; then
        # Python service
        cat > "$service_dir/Dockerfile" << DOCKERFILE_EOF
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE \$PORT

CMD ["python", "app.py"]
DOCKERFILE_EOF
    elif [ -f "$service_dir/go.mod" ]; then
        # Go service
        cat > "$service_dir/Dockerfile" << DOCKERFILE_EOF
FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN go build -o main .

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/

COPY --from=builder /app/main .

EXPOSE \$PORT

CMD ["./main"]
DOCKERFILE_EOF
    else
        echo "Unknown service type for $service_name, creating generic Dockerfile"
        cat > "$service_dir/Dockerfile" << DOCKERFILE_EOF
FROM alpine:latest

WORKDIR /app
COPY . .

EXPOSE \$PORT

CMD ["echo", "Configure this Dockerfile for your service"]
DOCKERFILE_EOF
    fi
    
    echo "Dockerfile generated for $service_name"
}

case "$1" in
    compose) generate_docker_compose ;;
    dockerfile) generate_dockerfile "$2" ;;
    all) 
        generate_docker_compose
        if command -v jq >/dev/null 2>&1; then
            jq -r '.services | keys[]' "$CONNECTIONS_FILE" | while read service; do
                generate_dockerfile "$service"
            done
        fi
        ;;
    *) echo "Usage: $0 {compose|dockerfile|all} [service_name]" ;;
esac
EOF
    chmod +x "$docker_script"
    log "INFO" "DOCKER-GEN" "Created Docker compose generator"
}

# Initialize enhanced components
create_connection_registry
create_message_relay
create_test_coordinator
create_connection_validator
create_port_helper
create_docker_generator
create_enhanced_monitor

# Initialize logging
log "INFO" "ORCHESTRATOR" "Starting TACO session for: $user_prompt"

# Ask about agent count
echo
echo -e "${YELLOW}How many agents should I create? (Enter for auto, or 2-10):${NC}"
read -r -p "> " agent_count

if [ -n "$agent_count" ] && ! [[ "$agent_count" =~ ^[2-9]$|^10$ ]]; then
    echo -e "${YELLOW}Invalid count. Using auto mode.${NC}"
    agent_count="auto"
fi

# Ask about display mode
echo
echo -e "${YELLOW}How should agents be displayed?${NC}"
echo "1. Separate windows (traditional mode)"
echo "2. Single window with panes (up to 4 agents)"
read -r -p "Choose option (1-2, default 1): " display_mode

DISPLAY_MODE="windows"
MAX_PANES=4  # Reduced to prevent "no space for new pane" errors

case $display_mode in
    2)
        DISPLAY_MODE="panes"
        echo -e "${GREEN}✓ Using pane mode (max $MAX_PANES agents in panes)${NC}"
        ;;
    *)
        DISPLAY_MODE="windows"
        echo -e "${GREEN}✓ Using traditional window mode${NC}"
        ;;
esac

# Check for existing session
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Found existing TACO session${NC}"
    echo "1. Kill it and start fresh"
    echo "2. Exit without changes"
    read -r -p "Choose option (1-2): " choice
    
    case $choice in
        1)
            echo -e "${YELLOW}Killing existing session...${NC}"
            tmux kill-session -t "$SESSION_NAME"
            ;;
        *)
            echo -e "${GREEN}Exiting without changes.${NC}"
            exit 0
            ;;
    esac
fi

# Create tmux session with Mother in window 0
echo -e "${GREEN}🖥️  Creating TACO session...${NC}"
tmux new-session -d -s "$SESSION_NAME" -n "mother" -c "$PROJECT_DIR"

# Create monitor window (window 1)
tmux new-window -t "$SESSION_NAME:1" -n "monitor" -c "$PROJECT_DIR"

# Initialize communication files
touch "$ORCHESTRATOR_DIR/communication.log"
mkdir -p "$ORCHESTRATOR_DIR/messages"

# Start enhanced monitor
tmux send-keys -t "$SESSION_NAME:1.0" "cd '$PROJECT_DIR' && watch -n 2 '$ORCHESTRATOR_DIR/show_status.sh'" Enter

# Start Mother agent
log "INFO" "MOTHER" "Starting Mother orchestrator"
echo -e "${MAGENTA}👑 Starting Mother Orchestrator...${NC}"

# Determine agent count instruction
if [ "$agent_count" != "auto" ]; then
    count_instruction="You should create exactly $agent_count main agents (including tester and devops)."
else
    count_instruction="Decide how many agents are needed (2-10 main agents, must include tester and devops)."
fi

# Create mother prompt
mother_prompt_file="$ORCHESTRATOR_DIR/mother_prompt.txt"
create_mother_prompt "$user_prompt" "$agent_count" "$count_instruction" > "$mother_prompt_file"

# Launch Mother Claude
echo -e "${YELLOW}Starting Claude for Mother...${NC}"
tmux send-keys -t "$SESSION_NAME:0.0" "cd '$PROJECT_DIR' && clear" Enter
tmux send-keys -t "$SESSION_NAME:0.0" "claude --dangerously-skip-permissions" Enter

# Wait for Claude to start
echo -e "${YELLOW}Waiting for Claude to initialize...${NC}"
sleep 5

# Send the mother prompt
echo -e "${YELLOW}Sending project requirements to Mother...${NC}"
tmux send-keys -t "$SESSION_NAME:0.0" C-u
sleep 0.5

# Send prompt line by line
while IFS= read -r line; do
    printf '%s\n' "$line" | tmux load-buffer -
    tmux paste-buffer -t "$SESSION_NAME:0.0"
    tmux send-keys -t "$SESSION_NAME:0.0" Enter
done < "$mother_prompt_file"

sleep 0.5
tmux send-keys -t "$SESSION_NAME:0.0" Enter

# Wait for specification
echo -e "${CYAN}Waiting for Mother to output specification...${NC}"
sleep 15

# Function to check for complete specification
check_for_complete_spec() {
    local capture=$(tmux capture-pane -t "$SESSION_NAME:0.0" -p -S -3000)
    local clean_capture=$(echo "$capture" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/│//g; s/╰//g; s/─//g; s/╯//g' | sed 's/[[:space:]]*$//')
    
    echo "$clean_capture" > "$ORCHESTRATOR_DIR/mother_output_debug.txt"
    
    if echo "$clean_capture" | grep -i "AGENT_SPEC_START" && echo "$clean_capture" | grep -i "AGENT_SPEC_END"; then
        local spec_content=$(echo "$clean_capture" | sed -n '/AGENT_SPEC_START/,/AGENT_SPEC_END/p')
        if echo "$spec_content" | grep -E "AGENT:[0-9]+:"; then
            return 0
        fi
    fi
    return 1
}

# Wait with exponential backoff
wait_for_spec_with_backoff() {
    local wait_time=2
    local total_wait=0
    local max_wait=$ORCHESTRATOR_TIMEOUT
    
    while [ $total_wait -lt $max_wait ]; do
        if check_for_complete_spec; then
            echo -e "${GREEN}✓ Found complete agent specification!${NC}"
            log "INFO" "MOTHER" "Specification generated successfully"
            return 0
        fi
        
        echo -ne "\r${CYAN}Waiting for specification... ${total_wait}s${NC}"
        sleep $wait_time
        total_wait=$((total_wait + wait_time))
        wait_time=$((wait_time < 16 ? wait_time * 2 : 16))
    done
    
    echo
    return 1
}

if ! wait_for_spec_with_backoff; then
    log "ERROR" "MOTHER" "Failed to generate specification"
    echo -e "${RED}❌ Mother failed to generate specification${NC}"
    exit 1
fi

# Capture and process specification
echo -e "${CYAN}Capturing specification...${NC}"
sleep 2
spec_file="$ORCHESTRATOR_DIR/agent_spec.txt"
tmux capture-pane -t "$SESSION_NAME:0.0" -p -S -3000 > "$spec_file"

# Clean and extract specification
cleaned_file="$ORCHESTRATOR_DIR/cleaned_spec.txt"
sed 's/│//g; s/╰//g; s/─//g; s/╯//g; s/^[[:space:]]*//; s/[[:space:]]*$//' "$spec_file" > "$cleaned_file"

# Parse specification with smart window reassignment
echo -e "${CYAN}Parsing agent specification...${NC}"
agent_specs=()
agent_deps=()
agent_notifies=()
agent_waits=()
declare -A used_windows
declare -A used_names
next_window=3  # Start from window 3 (0=mother, 1=monitor, 2=test-monitor)

current_agent_idx=-1
while IFS= read -r line; do
    line=$(echo "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    [ -z "$line" ] && continue
    
    if [[ "$line" =~ ^AGENT:([0-9]+):([^:]+):(.+)$ ]]; then
        original_window="${BASH_REMATCH[1]}"
        agent_name="${BASH_REMATCH[2]}"
        agent_role="${BASH_REMATCH[3]}"
        
        # Reject duplicate agent names - they indicate poor specification
        if [ -n "${used_names[$agent_name]}" ]; then
            echo -e "${RED}❌ DUPLICATE AGENT NAME: $agent_name${NC}"
            echo -e "${RED}   This indicates Mother created a poor specification.${NC}"
            echo -e "${RED}   Each agent should have a unique name and distinct role.${NC}"
            echo -e "${YELLOW}   Skipping duplicate agent. Mother should create better specifications.${NC}"
            log "ERROR" "PARSER" "Rejected duplicate agent name: $agent_name"
            continue
        fi
        
        # Assign next available window (skip 0=mother, 1=monitor, 2=test-monitor)
        while [ -n "${used_windows[$next_window]}" ] || [ $next_window -eq 0 ] || [ $next_window -eq 1 ] || [ $next_window -eq 2 ]; do
            next_window=$((next_window + 1))
            # Safety check to prevent infinite loop
            if [ $next_window -gt 50 ]; then
                echo -e "${RED}❌ Too many agents - exceeded window limit${NC}"
                log "ERROR" "PARSER" "Exceeded maximum window limit"
                break
            fi
        done
        window_num=$next_window
        
        echo -e "${GREEN}Found agent: Window $window_num - $agent_name (was $original_window)${NC}"
        log "INFO" "PARSER" "Found agent: $agent_name (window $window_num, originally $original_window)"
        
        used_windows[$window_num]="$agent_name"
        used_names[$agent_name]="$window_num"
        agent_specs+=("$window_num:$agent_name:$agent_role")
        current_agent_idx=$((${#agent_specs[@]} - 1))
        
        next_window=$((next_window + 1))
    elif [[ "$line" =~ ^DEPENDS_ON:(.+)$ ]] && [ $current_agent_idx -ge 0 ]; then
        agent_deps[$current_agent_idx]="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^NOTIFIES:(.+)$ ]] && [ $current_agent_idx -ge 0 ]; then
        agent_notifies[$current_agent_idx]="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^WAIT_FOR:(.+)$ ]] && [ $current_agent_idx -ge 0 ]; then
        agent_waits[$current_agent_idx]="${BASH_REMATCH[1]}"
    fi
done < <(awk '/AGENT_SPEC_START/,/AGENT_SPEC_END/' "$cleaned_file")

if [ ${#agent_specs[@]} -eq 0 ]; then
    log "ERROR" "PARSER" "No agents found in specification"
    echo -e "${RED}❌ Failed to parse agent specification${NC}"
    exit 1
fi

# Validate specification quality
min_agents=2
max_agents=15
agent_count=${#agent_specs[@]}

if [ $agent_count -lt $min_agents ]; then
    echo -e "${RED}❌ Too few agents ($agent_count). Need at least $min_agents for proper coordination.${NC}"
    echo -e "${YELLOW}   Mother should create more specialized agents for better parallel development.${NC}"
    exit 1
fi

if [ $agent_count -gt $max_agents ]; then
    echo -e "${RED}❌ Too many agents ($agent_count). Maximum is $max_agents to avoid complexity.${NC}"
    echo -e "${YELLOW}   Mother should consolidate similar roles into fewer, well-defined agents.${NC}"
    exit 1
fi

# Check for essential agent types
has_tester=false
has_devops=false
for spec in "${agent_specs[@]}"; do
    IFS=':' read -r window_num agent_name agent_role <<< "$spec"
    if echo "$agent_role" | grep -qi "test\\|qa\\|quality"; then
        has_tester=true
    fi
    if echo "$agent_role" | grep -qi "devops\\|deploy\\|docker\\|infrastructure"; then
        has_devops=true
    fi
done

if [ "$has_tester" = false ]; then
    echo -e "${YELLOW}⚠️  Warning: No dedicated testing agent found. This may impact quality assurance.${NC}"
fi

if [ "$has_devops" = false ]; then
    echo -e "${YELLOW}⚠️  Warning: No dedicated DevOps/deployment agent found. This may impact deployment.${NC}"
fi

echo -e "${GREEN}Creating ${#agent_specs[@]} agents...${NC}"
log "INFO" "ORCHESTRATOR" "Creating ${#agent_specs[@]} agents"

# Show final agent list
echo -e "${CYAN}Final agent assignments:${NC}"
for spec in "${agent_specs[@]}"; do
    IFS=':' read -r window_num agent_name agent_role <<< "$spec"
    echo "  Window $window_num: $agent_name - $agent_role"
done
echo

# Save state
save_state

# Create agent containers with enhanced robustness
if [ "$DISPLAY_MODE" = "panes" ]; then
    echo -e "${CYAN}Creating agent panes...${NC}"
    
    agent_count=${#agent_specs[@]}
    if [ $agent_count -gt $MAX_PANES ]; then
        echo -e "${YELLOW}⚠️  You have $agent_count agents but pane mode supports max $MAX_PANES${NC}"
    fi
    
    # Ensure agents window exists before creating panes
    if ! tmux new-window -t "$SESSION_NAME:2" -n "agents" -c "$PROJECT_DIR" 2>/dev/null; then
        log "ERROR" "PANE-MODE" "Failed to create agents window"
        echo -e "${RED}❌ Failed to create agents window${NC}"
        exit 1
    fi
    
    pane_count=0
    for idx in "${!agent_specs[@]}"; do
        spec="${agent_specs[$idx]}"
        IFS=':' read -r window_num agent_name agent_role <<< "$spec"
        
        if [ $window_num -le 1 ]; then
            continue
        fi
        
        if [ $pane_count -lt $MAX_PANES ]; then
            pane_mapping[$window_num]=$pane_count
            
            if [ $pane_count -gt 0 ]; then
                # Try multiple times to create pane with different orientations
                pane_created=false
                for attempt in 1 2 3; do
                    if tmux split-window -t "$SESSION_NAME:2" -c "$PROJECT_DIR" 2>/dev/null; then
                        pane_created=true
                        break
                    elif tmux split-window -t "$SESSION_NAME:2" -h -c "$PROJECT_DIR" 2>/dev/null; then
                        pane_created=true
                        break
                    fi
                    sleep 0.5
                done
                
                if [ "$pane_created" = false ]; then
                    echo -e "${YELLOW}⚠️  Cannot create more panes. Using separate window for $agent_name${NC}"
                    if ! tmux new-window -t "$SESSION_NAME:$window_num" -n "$agent_name" -c "$PROJECT_DIR" 2>/dev/null; then
                        log "ERROR" "PANE-MODE" "Failed to create window for $agent_name"
                        echo -e "${RED}❌ Failed to create window for $agent_name${NC}"
                        continue
                    fi
                    log "WARN" "PANE-MODE" "Pane creation failed for $agent_name, using window $window_num"
                    continue
                fi
            fi
            
            log "INFO" "PANE-MODE" "Mapped window $window_num ($agent_name) to pane 2.$pane_count"
            pane_count=$((pane_count + 1))
        else
            if ! tmux new-window -t "$SESSION_NAME:$window_num" -n "$agent_name" -c "$PROJECT_DIR" 2>/dev/null; then
                log "ERROR" "PANE-MODE" "Failed to create window for $agent_name"
                echo -e "${RED}❌ Failed to create window for $agent_name${NC}"
                continue
            fi
            log "INFO" "PANE-MODE" "Agent $agent_name exceeds pane limit, using window $window_num"
        fi
    done
    
    if [ $pane_count -gt 1 ]; then
        layout=$(calculate_pane_layout $pane_count)
        if ! tmux select-layout -t "$SESSION_NAME:2" "$layout" 2>/dev/null; then
            log "WARN" "PANE-MODE" "Failed to apply layout $layout, using default"
        fi
    fi
    
    sleep 1
else
    echo -e "${CYAN}Creating agent windows...${NC}"
    for idx in "${!agent_specs[@]}"; do
        spec="${agent_specs[$idx]}"
        IFS=':' read -r window_num agent_name agent_role <<< "$spec"
        
        # Check if window already exists
        if tmux list-windows -t "$SESSION_NAME" -F "#I" 2>/dev/null | grep -q "^$window_num$"; then
            log "WARN" "WINDOW-MODE" "Window $window_num already exists, skipping $agent_name"
            echo -e "${YELLOW}⚠️  Window $window_num already exists, skipping $agent_name${NC}"
        else
            # Ensure window creation succeeds
            if ! tmux new-window -t "$SESSION_NAME:$window_num" -n "$agent_name" -c "$PROJECT_DIR" 2>/dev/null; then
                log "ERROR" "WINDOW-MODE" "Failed to create window for $agent_name"
                echo -e "${RED}❌ Failed to create window for $agent_name${NC}"
            else
                log "INFO" "WINDOW-MODE" "Created window $window_num for $agent_name"
            fi
        fi &
    done
    wait
fi
sleep 1

# Initialize all Claude instances with validation
echo -e "${CYAN}Initializing Claude instances...${NC}"
for idx in "${!agent_specs[@]}"; do
    spec="${agent_specs[$idx]}"
    IFS=':' read -r window_num agent_name agent_role <<< "$spec"
    
    pane_address=$(get_pane_address $window_num "$agent_name")
    
    echo -e "${CYAN}Starting Claude for $agent_name at $pane_address${NC}"
    log "INFO" "AGENT-$agent_name" "Starting Claude instance at $pane_address"
    
    # Validate pane exists and check if Claude is already running
    if tmux list-panes -t "$pane_address" >/dev/null 2>&1; then
        # Check if Claude is already running in this pane
        if tmux capture-pane -t "$pane_address" -p | grep -q "claude"; then
            log "INFO" "AGENT-$agent_name" "Claude already running in $pane_address, skipping"
        else
            tmux send-keys -t "$pane_address" "claude --dangerously-skip-permissions" Enter &
        fi
    else
        log "ERROR" "AGENT-$agent_name" "Cannot start Claude - pane $pane_address not found"
        echo -e "${RED}❌ Cannot start Claude for $agent_name - pane not found${NC}"
    fi
done
wait
sleep 5

# Send prompts to all agents with enhanced testing focus
echo -e "${CYAN}Sending prompts to agents...${NC}"
for idx in "${!agent_specs[@]}"; do
    spec="${agent_specs[$idx]}"
    IFS=':' read -r window_num agent_name agent_role <<< "$spec"
    depends_on="${agent_deps[$idx]:-none}"
    notifies="${agent_notifies[$idx]:-none}"
    wait_for="${agent_waits[$idx]:-none}"
    
    echo -e "${CYAN}Configuring $agent_name...${NC}"
    log "INFO" "AGENT-$agent_name" "Sending initial prompt"
    
    # Store agent information for validation
    agent_roles[$window_num]="$agent_role"
    agent_addresses[$window_num]="$pane_address"
    
    # Create agent prompt with testing focus
    agent_prompt="You are an AI development agent in TACO (Test-Aware Coordinated Orchestrator).

PROJECT: $user_prompt
PROJECT ROOT: $PROJECT_DIR

YOUR ROLE: $agent_role
YOUR WINDOW NUMBER: $window_num
YOUR AGENT NAME: $agent_name

YOUR WORKSPACE:
Wait for Mother to tell you: \"Your workspace is $PROJECT_DIR/[your-area]\"
Create ALL your files only in your assigned workspace

MANDATORY REQUIREMENTS (NON-NEGOTIABLE):
1. ALL code must include comprehensive tests (unit, integration, e2e, API)
2. Register your service endpoints and ports in the connection registry:
   # Get your port allocation first:
   PORT=$($PROJECT_DIR/.orchestrator/port_helper.sh allocate your-service)
   # Then register it (deployment-aware URL):
   URL=$($PROJECT_DIR/.orchestrator/port_helper.sh docker-url your-service $PORT)
   echo '{\"services\": {\"your-service\": \"'$URL'\"}, \"ports\": {\"your-service\": '$PORT'}}' | jq -s '.[0] * .[1]' $PROJECT_DIR/.orchestrator/connections.json - > /tmp/conn.json && mv /tmp/conn.json $PROJECT_DIR/.orchestrator/connections.json
3. Test ALL endpoints with curl before marking complete
4. Smart Docker networking: Use deployment-aware URLs (localhost for local, container names for Docker)
   - Local development: http://localhost:PORT
   - Docker environment: http://service-name:PORT
   - Use port_helper.sh docker-url to generate correct URLs automatically
5. Report ALL test failures immediately
6. ALL builds must succeed without errors
7. ALL errors must be caught, logged, and fixed immediately
8. NO code can be marked complete without passing all tests

YOUR COMMUNICATION PLAN:
- DEPENDENCIES: $depends_on
- YOU MUST NOTIFY: $notifies
- WAIT_FOR: $wait_for

COMMUNICATION PROTOCOL:"
    
    # Build agent directory for role-based messaging
    agent_directory="\nACTIVE AGENTS:"
    for other_idx in "${!agent_specs[@]}"; do
        other_spec="${agent_specs[$other_idx]}"
        IFS=':' read -r other_window other_name other_role <<< "$other_spec"
        agent_directory+="\n- Window $other_window: $other_name ($other_role)"
    done
    
    if [ "$DISPLAY_MODE" = "panes" ]; then
        agent_prompt+="
Note: Agents are running in PANE MODE.
- Mother is at taco:0.0
- Monitor is at taco:1.0  
- Agents are in window 2, different panes

$agent_directory

COMMUNICATION METHODS:
1. Report to Mother (RECOMMENDED):
$PROJECT_DIR/.orchestrator/message_relay.sh \"[AGENT-$window_num → MOTHER]: Test results - 5 passed, 0 failed\"

2. Message another agent by window number:
$PROJECT_DIR/.orchestrator/message_relay.sh \"[AGENT-$window_num → AGENT-3]: API endpoints ready at port 3001\" 3

3. Direct tmux method (fallback only):
tmux send-keys -t taco:0.0 \"[AGENT-$window_num → MOTHER]: Test results - 5 passed, 0 failed\"
tmux send-keys -t taco:0.0 Enter

IMPORTANT: Use window numbers from the agent directory above for accurate messaging."
    else
        agent_prompt+="
$agent_directory

COMMUNICATION METHODS:
1. Report to Mother (RECOMMENDED):
$PROJECT_DIR/.orchestrator/message_relay.sh \"[WINDOW-$window_num → MOTHER]: Test results - 5 passed, 0 failed\"

2. Message another agent by window number:
$PROJECT_DIR/.orchestrator/message_relay.sh \"[WINDOW-$window_num → WINDOW-3]: API endpoints ready at port 3001\" 3

3. Direct tmux method (fallback only):
tmux send-keys -t taco:3.0 \"[WINDOW-$window_num → WINDOW-3]: API endpoints ready at port 3001\"
tmux send-keys -t taco:3.0 Enter

IMPORTANT: Use window numbers from the agent directory above for accurate messaging."
    fi
    
    agent_prompt+="

TESTING COMMANDS:
- Run your tests: npm test, pytest, go test, etc.
- Test endpoints: curl -X GET http://localhost:PORT/endpoint
- Validate connections: $PROJECT_DIR/.orchestrator/validate_connections.sh

PORT MANAGEMENT:
- Get next available port: $PROJECT_DIR/.orchestrator/port_helper.sh next
- Allocate port for service: $PROJECT_DIR/.orchestrator/port_helper.sh allocate service-name [preferred-port]
- Show all ports: $PROJECT_DIR/.orchestrator/port_helper.sh show
- Generate Docker URL: $PROJECT_DIR/.orchestrator/port_helper.sh docker-url service-name port

CONNECTION REGISTRY SHARING:
- ALWAYS check existing ports before allocating new ones
- ALWAYS update the registry when you start a service
- ALWAYS notify other agents when ports change
- Use the registry to discover other services: jq -r '.services | to_entries[] | \"\\(.key): \\(.value)\"' $PROJECT_DIR/.orchestrator/connections.json

Wait for Mother's initial instructions to begin."
    
    pane_address=$(get_pane_address $window_num "$agent_name")
    
    echo -e "${CYAN}Sending prompt to $agent_name at $pane_address${NC}"
    log "INFO" "AGENT-$agent_name" "Sending prompt to $pane_address"
    
    # Validate pane exists before sending prompt
    if tmux list-panes -t "$pane_address" >/dev/null 2>&1; then
        echo "$agent_prompt" | while IFS= read -r line; do
            printf '%s\n' "$line" | tmux load-buffer -
            tmux paste-buffer -t "$pane_address"
            tmux send-keys -t "$pane_address" Enter
        done
        tmux send-keys -t "$pane_address" Enter
    else
        log "ERROR" "AGENT-$agent_name" "Cannot send prompt - pane $pane_address not found"
        echo -e "${RED}❌ Cannot send prompt to $agent_name - pane not found${NC}"
    fi
    
    echo "[SYSTEM]: Created $agent_name in window $window_num" >> "$ORCHESTRATOR_DIR/communication.log"
done

echo -e "${GREEN}✅ All agents created successfully!${NC}"
log "INFO" "ORCHESTRATOR" "All agents initialized successfully"

# Notify Mother that all agents are ready with enhanced instructions
sleep 3
echo -e "${CYAN}Notifying Mother that all agents are ready...${NC}"

mother_complete_msg="

=== ALL AGENTS CREATED AND READY ===

The following agents are now active and waiting for instructions:
"

for idx in "${!agent_specs[@]}"; do
    spec="${agent_specs[$idx]}"
    IFS=':' read -r window_num agent_name agent_role <<< "$spec"
    mother_complete_msg+="Window $window_num: $agent_name - $agent_role
"
done

mother_complete_msg+="

CRITICAL - YOU MUST NOW EXECUTE THESE TASKS:

1. Create workspace directories:
   mkdir -p frontend backend database testing infrastructure docker

2. Initialize the connection registry for all agents

3. Send DETAILED instructions to each agent including:
   - Their workspace assignment
   - Specific tasks with test requirements
   - Port assignments (avoid conflicts)
   - Connection details they need

EXAMPLE COMMANDS (adapt based on your agents and configuration):

For frontend agent:
tmux send-keys -t taco:2.0 \"Your workspace is \$PROJECT_DIR/frontend. Create frontend components with: $testing_requirements. $deployment_guidance. $connection_strategy\"
tmux send-keys -t taco:2.0 Enter

For backend agent:
tmux send-keys -t taco:2.1 \"Your workspace is \$PROJECT_DIR/backend. Create backend services with: $testing_requirements. $deployment_guidance. Register endpoints in connection registry. $connection_strategy\"
tmux send-keys -t taco:2.1 Enter

For tester agent:
tmux send-keys -t taco:2.3 \"Your workspace is \$PROJECT_DIR/testing. Execute: $testing_requirements. $([ "$CURL_TESTING" = "true" ] && echo "Test all endpoints with curl." || echo "Test endpoints as configured.") Report failures immediately.\"
tmux send-keys -t taco:2.3 Enter

MANDATORY REQUIREMENTS (NON-NEGOTIABLE):
- Testing Strategy: $testing_requirements
- Deployment: $deployment_guidance  
- Connections: $connection_strategy
- Test ALL endpoints with curl before marking complete
- ALL builds must succeed without errors before proceeding
- Enable comprehensive logging and monitoring
- ALL errors must be caught, logged, and immediately fixed
- NO code can be marked complete without passing all tests

Connection Registry: $ORCHESTRATOR_DIR/connections.json
Message Relay: $ORCHESTRATOR_DIR/message_relay.sh
Test Coordinator: $ORCHESTRATOR_DIR/test_coordinator.sh
Validation Script: $ORCHESTRATOR_DIR/validate_connections.sh
Port Helper: $ORCHESTRATOR_DIR/port_helper.sh

PORT COMMUNICATION PROTOCOL:
1. All agents MUST use port_helper.sh to allocate ports
2. All agents MUST update the connection registry when starting services
3. All agents MUST check the registry before making connections
4. All agents MUST notify others when ports change
5. Use 'jq' to read from the registry: jq -r '.services.SERVICE_NAME' $ORCHESTRATOR_DIR/connections.json

BEGIN COORDINATING THE PROJECT NOW!"

printf '%s' "$mother_complete_msg" | tmux load-buffer -
tmux paste-buffer -t "$SESSION_NAME:0.0"

sleep 0.5
tmux send-keys -t "$SESSION_NAME:0.0" Enter

# Start test monitor in background
tmux new-window -t "$SESSION_NAME:2" -n "test-monitor" -c "$PROJECT_DIR"
tmux send-keys -t "$SESSION_NAME:2.0" "$ORCHESTRATOR_DIR/test_coordinator.sh monitor" Enter

# Display final status
clear
echo -e "${GREEN}✅ TACO FULLY INITIALIZED!${NC}"
echo
echo -e "${MAGENTA}Project: $user_prompt${NC}"
echo -e "${CYAN}Project Directory: $PROJECT_DIR${NC}"
echo -e "${CYAN}Session: $SESSION_NAME${NC}"
echo
echo -e "${YELLOW}Display Mode: ${DISPLAY_MODE}${NC}"
echo
echo -e "${YELLOW}Created Agents:${NC}"
for idx in "${!agent_specs[@]}"; do
    spec="${agent_specs[$idx]}"
    IFS=':' read -r window_num agent_name agent_role <<< "$spec"
    if [ "$DISPLAY_MODE" = "panes" ] && [ $window_num -gt 1 ]; then
        pane_idx=$((window_num - 2))
        echo "  Window 2, Pane $pane_idx: $agent_name"
    else
        echo "  Window $window_num: $agent_name"
    fi
done
echo
echo -e "${YELLOW}Configuration:${NC}"
echo "  • Testing Strategy: $TESTING_STRATEGY"
echo "  • Deployment Environment: $DEPLOYMENT_ENV"
echo "  • Connection Management: $CONNECTION_STRATEGY"
echo "  • Error Handling: $ERROR_HANDLING"
echo "  • Curl Testing: $CURL_TESTING"
echo "  • Build Validation: $BUILD_VALIDATION"
echo "  • Log Monitoring: $LOG_MONITORING"
echo
echo -e "${YELLOW}Enhanced Features:${NC}"
echo "  • Configurable test coordination and failure routing"
echo "  • Dynamic connection registry and validation"
echo "  • Intelligent build error detection and recovery"
echo "  • Automated endpoint testing (configurable)"
echo "  • Smart Docker/localhost conflict detection"
echo "  • Reliable agent-to-mother message relay"
echo
echo -e "${YELLOW}Key Files:${NC}"
echo "  • Connection Registry: $ORCHESTRATOR_DIR/connections.json"
echo "  • Message Relay: $ORCHESTRATOR_DIR/message_relay.sh"
echo "  • Port Helper: $ORCHESTRATOR_DIR/port_helper.sh"
echo "  • Test Results: $ORCHESTRATOR_DIR/test_results.log"
echo "  • Validation Log: $ORCHESTRATOR_DIR/validation.log"
echo
echo -e "${YELLOW}Navigation:${NC}"
if [ "$DISPLAY_MODE" = "panes" ]; then
    echo "  • Ctrl+b + 2: Jump to agents window"
    echo "  • Ctrl+b + arrow keys: Navigate between panes"
else
    echo "  • Ctrl+b + [0-9]: Jump to specific window"
fi
echo "  • Ctrl+b + 2: Test monitor window"
echo "  • Ctrl+b + d: Detach (everything keeps running)"
echo
echo -e "${GREEN}🌮 Attaching to TACO session in 3 seconds...${NC}"
echo -e "${CYAN}You'll start in the Mother window (0)${NC}"

sleep 3

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    tmux attach -t "$SESSION_NAME:0"
else
    echo -e "${RED}❌ Failed to create TACO session${NC}"
    echo -e "${YELLOW}Check logs at: $ORCHESTRATOR_DIR/orchestrator.log${NC}"
    exit 1
fi