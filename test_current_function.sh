#\!/bin/bash
source taco/lib/taco-common.sh
source taco/lib/taco-agents.sh

# Test the actual parse_agent_specification function with some debug output
test_parse() {
    # Create a simple test file
    cat > test_spec.txt << 'TESTEOF'
⏺ AGENT_SPEC_START

AGENT:3:test_agent:This is a test role
description that spans multiple lines
DEPENDS_ON:none
NOTIFIES:none
WAIT_FOR:none

AGENT:4:another_agent:Another test role
DEPENDS_ON:test_agent
NOTIFIES:none
WAIT_FOR:test_agent

AGENT_SPEC_END
TESTEOF

    echo "=== Testing parse_agent_specification ==="
    result=$(parse_agent_specification test_spec.txt)
    echo "Result: '$result'"
    echo "Number of agents found: $(echo "$result" | wc -w)"
    rm test_spec.txt
}

test_parse
