#\!/bin/bash
source taco/lib/taco-common.sh

# Trace just the first agent processing
trace_first() {
    local spec_file="/Users/louisxsheid/dev/daedastream/test/cm2/.orchestrator/mother_output_debug.txt"
    local current_agent_name=""
    local current_agent_role=""
    local current_original_window=""
    local collecting_role=false
    local count=0
    
    while IFS= read -r line; do
        count=$((count + 1))
        line=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        [ -z "$line" ] && continue
        
        echo "Line $count: '$line'"
        
        if [[ "$line" =~ ^AGENT:([0-9]+):([^:]+):(.*)$ ]]; then
            echo "  -> AGENT MATCH\!"
            
            # First agent - should trigger this logic
            if [ "$collecting_role" = true ]; then
                echo "  -> Previous agent being finalized: name='$current_agent_name' window='$current_original_window'"
                # This should be empty for first agent
            fi
            
            # Capture new agent  
            original_window="${BASH_REMATCH[1]}"
            agent_name="${BASH_REMATCH[2]}"
            current_agent_role="${BASH_REMATCH[3]}"
            collecting_role=true
            
            echo "  -> New agent captured: original_window='$original_window' agent_name='$agent_name'"
            
            # Store
            current_original_window="$original_window"
            current_agent_name="$agent_name"
            
            echo "  -> Stored: current_original_window='$current_original_window' current_agent_name='$current_agent_name'"
            
            # Only process first 2 agents
            if [ $count -gt 10 ]; then
                break
            fi
        fi
        
    done < <(awk '/⏺ AGENT_SPEC_START/,/AGENT_SPEC_END/' "$spec_file")
    
    echo "Final state: current_agent_name='$current_agent_name' current_original_window='$current_original_window'"
}

trace_first
