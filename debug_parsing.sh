#!/bin/bash

# Simple test of the parsing function
source /Users/louisxsheid/.local/share/taco/lib/taco-common.sh
source /Users/louisxsheid/.local/share/taco/lib/taco-agents.sh

echo "Testing agent specification parsing..."

# Test the basic awk extraction
echo "=== AWK EXTRACTION ==="
awk '/AGENT_SPEC_START/,/AGENT_SPEC_END/' test_spec.txt

echo -e "\n=== TESTING REGEX MATCH ==="
while IFS= read -r line; do
    echo "Line: '$line'"
    if [[ "$line" =~ AGENT_SPEC_START ]]; then
        echo "  -> MATCHED START"
    elif [[ "$line" =~ AGENT_SPEC_END ]]; then
        echo "  -> MATCHED END"
    elif [[ "$line" =~ ^AGENT: ]]; then
        echo "  -> MATCHED AGENT"
    fi
done < test_spec.txt

echo -e "\n=== PARSE FUNCTION ==="
parse_agent_specification test_spec.txt