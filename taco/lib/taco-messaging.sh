#!/usr/bin/env bash
# TACO - Tmux Agent Command Orchestrator
# Messaging and Communication

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
    
    # Clear any existing input first
    tmux send-keys -t "$target_pane" C-u
    sleep 0.1
    
    # Send message using reliable method
    printf '%s' "$message" | tmux load-buffer -
    tmux paste-buffer -t "$target_pane"
    
    # Longer delay for Claude to process
    sleep 0.5
    tmux send-keys -t "$target_pane" Enter
    
    # Verify message was sent
    local sent_ok=true
    if ! tmux capture-pane -t "$target_pane" -p | tail -1 | grep -q "$message" 2>/dev/null; then
        echo "WARNING: Message may not have been delivered to $target_pane" >&2
        sent_ok=false
    fi
    
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