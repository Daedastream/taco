#\!/bin/bash
source taco/lib/taco-common.sh

# Debug version of the parsing with echo statements
debug_parse() {
    local spec_file="$1"
    
    while IFS= read -r line; do
        echo "DEBUG: Processing line: '$line'"
        # Strip ANSI codes and trim whitespace
        line=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        echo "DEBUG: After cleaning: '$line'"
        [ -z "$line" ] && continue
        
        if [[ "$line" =~ ^AGENT:([0-9]+):([^:]+):(.*)$ ]]; then
            echo "DEBUG: MATCH\! window='${BASH_REMATCH[1]}' name='${BASH_REMATCH[2]}' role='${BASH_REMATCH[3]}'"
        else
            echo "DEBUG: No match"
        fi
        
    done < <(awk '/AGENT_SPEC_START/,/AGENT_SPEC_END/' "$spec_file")
}

debug_parse "/Users/louisxsheid/dev/daedastream/test/cm2/.orchestrator/mother_output_debug.txt"
