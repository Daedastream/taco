#\!/bin/bash

# Simplified debug to test variable capture
debug_simple() {
    local spec_file="$1"
    
    while IFS= read -r line; do
        # Strip ANSI codes and trim whitespace
        line=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        [ -z "$line" ] && continue
        
        if [[ "$line" =~ ^AGENT:([0-9]+):([^:]+):(.*)$ ]]; then
            local original_window="${BASH_REMATCH[1]}"
            local agent_name="${BASH_REMATCH[2]}"
            local agent_role="${BASH_REMATCH[3]}"
            echo "FOUND: window='$original_window' name='$agent_name' role='$agent_role'"
        fi
        
    done < <(awk '/⏺ AGENT_SPEC_START/,/AGENT_SPEC_END/' "$spec_file")
}

debug_simple "/Users/louisxsheid/dev/daedastream/test/cm2/.orchestrator/mother_output_debug.txt"
