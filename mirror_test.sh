#\!/bin/bash
source taco/lib/taco-common.sh

test_exact_logic() {
    local current_agent_name=""
    local current_agent_role=""  
    local current_original_window=""
    local collecting_role=false
    
    # Simulate processing first line: AGENT:3:frontend_optimizer:...
    line="AGENT:3:frontend_optimizer:Analyze and optimize Next.js frontend"
    
    echo "Processing line: '$line'"
    echo "collecting_role before check: '$collecting_role'"
    
    if [[ "$line" =~ ^AGENT:([0-9]+):([^:]+):(.*)$ ]]; then
        echo "MATCHED AGENT REGEX\!"
        
        # This is the problematic check
        if [ "$collecting_role" = true ]; then
            echo "ERROR: Trying to finalize previous agent, but there shouldn't be one\!"
            echo "  current_agent_name='$current_agent_name'"
            echo "  current_original_window='$current_original_window'" 
            # This would log empty values\!
            log "INFO" "PARSER" "Found agent: $current_agent_name (window 99, originally $current_original_window)"
        else
            echo "GOOD: No previous agent to finalize"
        fi
        
        # Now start new agent
        original_window="${BASH_REMATCH[1]}"
        agent_name="${BASH_REMATCH[2]}"
        current_agent_role="${BASH_REMATCH[3]}"
        collecting_role=true
        
        echo "New agent: original_window='$original_window' agent_name='$agent_name'"
        
        current_original_window="$original_window"
        current_agent_name="$agent_name"
        
        echo "Stored: current_original_window='$current_original_window' current_agent_name='$current_agent_name'"
    fi
}

test_exact_logic
