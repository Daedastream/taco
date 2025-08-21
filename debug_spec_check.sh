#!/bin/bash

echo "Checking for AGENT_SPEC markers in test_problematic_output.txt"
echo "============================================================="

while IFS= read -r line; do
    trimmed_line=$(echo "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    echo "Original: [$line]"
    echo "Trimmed:  [$trimmed_line]"
    
    if [[ "$trimmed_line" =~ AGENT_SPEC_START ]]; then
        echo "  -> FOUND START"
    elif [[ "$trimmed_line" =~ AGENT_SPEC_END ]]; then
        echo "  -> FOUND END"
    fi
    echo
done < test_problematic_output.txt