#!/usr/bin/env bash
# TACO - Tmux Agent Command Orchestrator
# Monitoring and Status Display

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
    echo "To start TACO, run: taco"
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
    local user_prompt="$1"
    shift
    local agent_specs=("$@")
    
    if command -v jq >/dev/null 2>&1; then
        local up_json
        up_json=$(printf '%s' "$user_prompt" | jq -Rs .)
        # Write header
        cat > "$state_file" << EOF
{
    "project": $up_json,
    "project_dir": "$PROJECT_DIR",
    "session": "$SESSION_NAME",
    "display_mode": "${DISPLAY_MODE:-windows}",
    "agent_type": "${TACO_AGENT_TYPE:-claude}",
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
            # Escape role and name safely
            local name_json role_json
            name_json=$(printf '%s' "$agent_name" | jq -Rs .)
            role_json=$(printf '%s' "$agent_role" | jq -Rs .)
            cat >> "$state_file" << EOF
        {
            "window": $window_num,
            "name": $name_json,
            "role": $role_json
        }
EOF
        done
        echo -e "\n    ]\n}" >> "$state_file"
    else
        # Fallback without jq (may break on quotes/newlines in prompt)
        cat > "$state_file" << EOF
{
    "project": "$user_prompt",
    "project_dir": "$PROJECT_DIR",
    "session": "$SESSION_NAME",
    "display_mode": "${DISPLAY_MODE:-windows}",
    "agent_type": "${TACO_AGENT_TYPE:-claude}",
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
    fi
    log "INFO" "ORCHESTRATOR" "State saved to $state_file"
}
