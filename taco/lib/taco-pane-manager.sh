#!/usr/bin/env bash
# TACO - Tmux Agent Command Orchestrator
# Pane and Window Management

# Arrays to store pane mappings and agent info
# Use indexed arrays for broad Bash compatibility (Bash 3.2+)
# Keys are numeric window indices, which work with indexed arrays
pane_mapping=()
agent_roles=()
agent_addresses=()

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

# Create agent containers with enhanced robustness
create_agent_containers() {
    local agent_specs=("$@")
    
    if [ "$DISPLAY_MODE" = "panes" ]; then
        echo -e "${CYAN}Creating agent panes...${NC}"
        
        local agent_count=${#agent_specs[@]}
        if [ $agent_count -gt $MAX_PANES ]; then
            echo -e "${YELLOW}⚠️  You have $agent_count agents but pane mode supports max $MAX_PANES${NC}"
        fi
        
        # Ensure agents window exists before creating panes
        if ! tmux new-window -t "$SESSION_NAME:2" -n "agents" -c "$PROJECT_DIR" 2>/dev/null; then
            log "ERROR" "PANE-MODE" "Failed to create agents window"
            echo -e "${RED}❌ Failed to create agents window${NC}"
            return 1
        fi
        
        local pane_count=0
        for idx in "${!agent_specs[@]}"; do
            local spec="${agent_specs[$idx]}"
            IFS=':' read -r window_num agent_name agent_role <<< "$spec"
            
            if [ $window_num -le 1 ]; then
                continue
            fi
            
            if [ $pane_count -lt $MAX_PANES ]; then
                pane_mapping[$window_num]=$pane_count
                
                if [ $pane_count -gt 0 ]; then
                    # Try multiple times to create pane with different orientations
                    local pane_created=false
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
            local layout=$(calculate_pane_layout $pane_count)
            if ! tmux select-layout -t "$SESSION_NAME:2" "$layout" 2>/dev/null; then
                log "WARN" "PANE-MODE" "Failed to apply layout $layout, using default"
            fi
        fi
        
        sleep 1
    else
        echo -e "${CYAN}Creating agent windows...${NC}"
        for idx in "${!agent_specs[@]}"; do
            local spec="${agent_specs[$idx]}"
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
}
