#!/bin/bash

# Test V2 field parsing
source /Users/louisxsheid/Dev/Daedastream/taco/taco/lib/taco-common.sh
source /Users/louisxsheid/Dev/Daedastream/taco/taco/lib/taco-agents.sh

echo "Testing V2 field parsing..."
echo "=========================="
echo

# Create a test file with V2 fields
cat > test_v2_spec.txt << 'EOF'
AGENT_SPEC_START
AGENT:3:frontend_dev:Build React UI components
DEPENDS_ON:none
NOTIFIES:backend_dev,tester
WAIT_FOR:none
MEMORY_SHARE:backend_dev,tester
PARALLEL_WITH:backend_dev
SUB_AGENTS:react-expert,css-specialist
THINKING_MODE:think
MEMORY_KEYS:ui_components,routes

AGENT:4:backend_dev:Create API endpoints
DEPENDS_ON:database_dev
NOTIFIES:frontend_dev,tester
WAIT_FOR:schema_ready
MEMORY_SHARE:frontend_dev,database_dev
PARALLEL_WITH:frontend_dev
SUB_AGENTS:api-expert,auth-specialist
THINKING_MODE:think_hard
MEMORY_KEYS:api_endpoints,auth_tokens
AGENT_SPEC_END
EOF

echo "Parsing V2 specification..."
parse_agent_specification test_v2_spec.txt

echo
echo "Checking if V2 fields are captured..."
result=$(parse_agent_specification test_v2_spec.txt 2>/dev/null)

if echo "$result" | grep -q "MEMORY_SHARE"; then
    echo "✅ MEMORY_SHARE field captured"
else
    echo "❌ MEMORY_SHARE field missing"
fi

if echo "$result" | grep -q "PARALLEL_WITH"; then
    echo "✅ PARALLEL_WITH field captured"
else
    echo "❌ PARALLEL_WITH field missing"
fi

if echo "$result" | grep -q "SUB_AGENTS"; then
    echo "✅ SUB_AGENTS field captured"
else
    echo "❌ SUB_AGENTS field missing"
fi

if echo "$result" | grep -q "THINKING_MODE"; then
    echo "✅ THINKING_MODE field captured"
else
    echo "❌ THINKING_MODE field missing"
fi

echo
echo "Full output:"
echo "$result"

# Clean up
rm -f test_v2_spec.txt