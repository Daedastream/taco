#\!/bin/bash
source taco/lib/taco-common.sh

# Full debug version
debug_full_parse() {
    local spec_file="$1"
    local current_agent_name=""
    local current_agent_role=""
    local current_original_window=""
    local collecting_role=false
    local used_names=""
    
    echo "Starting parsing..."
    
    while IFS= read -r line; do
        echo "RAW LINE: '$line'"
        line=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        echo "CLEAN LINE: '$line'"
        [ -z "$line" ] && continue
        
        if [[ "$line" =~ ^AGENT:([0-9]+):([^:]+):(.*)$ ]]; then
            echo "MATCHED AGENT\! BASH_REMATCH[1]='${BASH_REMATCH[1]}' BASH_REMATCH[2]='${BASH_REMATCH[2]}' BASH_REMATCH[3]='${BASH_REMATCH[3]}'"
            
            # First, finalize any previous agent being collected
            if [ "$collecting_role" = true ]; then
                echo "FINALIZING PREVIOUS AGENT: name='$current_agent_name' window='$current_original_window' role='$current_agent_role'"
            fi
            
            # Now start processing the new agent
            original_window="${BASH_REMATCH[1]}"
            agent_name="${BASH_REMATCH[2]}"
            current_agent_role="${BASH_REMATCH[3]}"
            collecting_role=true
            
            echo "NEW AGENT VARS: original_window='$original_window' agent_name='$agent_name' current_agent_role='$current_agent_role'"
            
            # Check for duplicates
            if [ -n "$used_names" ] && [[ " $used_names " == *" $agent_name "* ]]; then
                echo "DUPLICATE DETECTED: $agent_name"
                collecting_role=false
                continue
            fi
            
            # Store current agent info
            current_original_window="$original_window"
            current_agent_name="$agent_name"
            
            echo "STORED: current_original_window='$current_original_window' current_agent_name='$current_agent_name'"
            used_names="$used_names $agent_name"
            echo "USED_NAMES: '$used_names'"
            
        elif [ "$collecting_role" = true ]; then
            echo "COLLECTING ROLE: adding '$line'"
            current_agent_role="$current_agent_role $line"
        fi
        
    done < <(awk '/⏺ AGENT_SPEC_START/,/AGENT_SPEC_END/' "$spec_file")
    
    echo "FINAL AGENT: name='$current_agent_name' window='$current_original_window' role='$current_agent_role'"
}

debug_full_parse "/Users/louisxsheid/dev/daedastream/test/cm2/.orchestrator/mother_output_debug.txt"
