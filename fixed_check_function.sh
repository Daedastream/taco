#!/opt/homebrew/bin/bash
# Fixed version of check_for_complete_spec function

# Fixed function that doesn't require analysis markers
check_for_complete_spec() {
    local capture=$(tmux capture-pane -t "$SESSION_NAME:0.0" -p -S -3000)
    local clean_capture=$(echo "$capture" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/│//g; s/╰//g; s/─//g; s/╯//g; s/⏺//g' | sed 's/[[:space:]]*$//')
    
    echo "$clean_capture" > "$ORCHESTRATOR_DIR/mother_output_debug.txt"
    
    # Simply check if we have both START and END markers
    if echo "$clean_capture" | grep -i "AGENT_SPEC_START" > /dev/null && \
       echo "$clean_capture" | grep -i "AGENT_SPEC_END" > /dev/null; then
        
        # Get the last AGENT_SPEC block (in case there are examples in the prompt)
        local spec_content=$(echo "$clean_capture" | awk '
            /AGENT_SPEC_START/ { delete lines; i=0; capturing=1 }
            capturing { lines[i++] = $0 }
            /AGENT_SPEC_END/ { capturing=0; for(j=0; j<i; j++) final_lines[j] = lines[j] }
            END { for(j=0; j in final_lines; j++) print final_lines[j] }
        ')
        
        # Check if we have actual agent definitions
        if echo "$spec_content" | grep -E "AGENT:[0-9]+:" > /dev/null; then
            return 0
        fi
    fi
    return 1
}

# Alternative version that's more robust and provides better debugging
check_for_complete_spec_v2() {
    local capture=$(tmux capture-pane -t "$SESSION_NAME:0.0" -p -S -3000)
    local clean_capture=$(echo "$capture" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/│//g; s/╰//g; s/─//g; s/╯//g; s/⏺//g' | sed 's/[[:space:]]*$//')
    
    echo "$clean_capture" > "$ORCHESTRATOR_DIR/mother_output_debug.txt"
    
    # Count occurrences for debugging
    local start_count=$(echo "$clean_capture" | grep -i "AGENT_SPEC_START" | wc -l)
    local end_count=$(echo "$clean_capture" | grep -i "AGENT_SPEC_END" | wc -l)
    local agent_count=$(echo "$clean_capture" | grep -E "AGENT:[0-9]+:" | wc -l)
    
    log "DEBUG" "SPEC_CHECK" "Found $start_count START markers, $end_count END markers, $agent_count AGENT definitions"
    
    # Check if we have a complete spec
    if [ $start_count -gt 0 ] && [ $end_count -gt 0 ] && [ $agent_count -gt 0 ]; then
        # Extract the last complete spec block
        local spec_block=$(echo "$clean_capture" | awk '
            /AGENT_SPEC_START/ { in_spec=1; spec="" }
            in_spec { spec = spec "\n" $0 }
            /AGENT_SPEC_END/ { in_spec=0; last_spec=spec }
            END { if (last_spec != "") print last_spec }
        ')
        
        # Validate the spec has required components
        if echo "$spec_block" | grep -E "AGENT:[0-9]+:" > /dev/null; then
            log "INFO" "SPEC_CHECK" "Valid specification detected with $agent_count agents"
            return 0
        else
            log "WARN" "SPEC_CHECK" "Spec block found but no valid AGENT entries"
        fi
    else
        log "WARN" "SPEC_CHECK" "Incomplete spec: START=$start_count END=$end_count AGENTS=$agent_count"
    fi
    
    return 1
}

# The actual fix for the TACO bin file would be to replace lines 352-375 with:
echo "
# Function to check for complete specification
check_for_complete_spec() {
    local capture=\$(tmux capture-pane -t \"\$SESSION_NAME:0.0\" -p -S -3000)
    local clean_capture=\$(echo \"\$capture\" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/│//g; s/╰//g; s/─//g; s/╯//g; s/⏺//g' | sed 's/[[:space:]]*\$//')
    
    echo \"\$clean_capture\" > \"\$ORCHESTRATOR_DIR/mother_output_debug.txt\"
    
    # Simply check if we have both START and END markers
    if echo \"\$clean_capture\" | grep -i \"AGENT_SPEC_START\" > /dev/null && \\
       echo \"\$clean_capture\" | grep -i \"AGENT_SPEC_END\" > /dev/null; then
        
        # Get the last AGENT_SPEC block (in case there are examples in the prompt)
        local spec_content=\$(echo \"\$clean_capture\" | awk '
            /AGENT_SPEC_START/ { delete lines; i=0; capturing=1 }
            capturing { lines[i++] = \$0 }
            /AGENT_SPEC_END/ { capturing=0; for(j=0; j<i; j++) final_lines[j] = lines[j] }
            END { for(j=0; j in final_lines; j++) print final_lines[j] }
        ')
        
        # Check if we have actual agent definitions
        if echo \"\$spec_content\" | grep -E \"AGENT:[0-9]+:\" > /dev/null; then
            return 0
        fi
    fi
    return 1
}
"