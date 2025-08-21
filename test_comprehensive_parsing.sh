#!/bin/bash

# Comprehensive test of the agent specification parser fixes
source /Users/louisxsheid/.local/share/taco/lib/taco-common.sh
source /Users/louisxsheid/Dev/Daedastream/taco/taco/lib/taco-agents.sh

echo "=========================================="
echo "COMPREHENSIVE AGENT PARSING TEST SUITE"
echo "=========================================="
echo

# Test 1: Clean specification
echo "TEST 1: Clean specification (test_spec.txt)"
echo "Expected: 3 agents (frontend_dev, backend_dev, tester)"
echo "Result:"
parse_agent_specification test_spec.txt | grep -E "^[0-9]+:" | wc -l
echo

# Test 2: Claude UI decorated output
echo "TEST 2: Claude UI decorated output (test_claude_output.txt)"
echo "Expected: 2 agents (frontend_architect, ui_developer)"
echo "Result:"
parse_agent_specification test_claude_output.txt | grep -E "^[0-9]+:" | wc -l
echo

# Test 3: Placeholder agents (should be filtered)
echo "TEST 3: Placeholder agents (test_problematic_output.txt)"
echo "Expected: 0 agents (placeholder should be skipped)"
echo "Result:"
parse_agent_specification test_problematic_output.txt 2>/dev/null | grep -E "^[0-9]+:" | wc -l
echo

# Test 4: V1 Church website specification
echo "TEST 4: V1 Church website (church_website_taco_prompt.txt)"
echo "Expected: 7 agents"
echo "Result:"
parse_agent_specification church_website_taco_prompt.txt | grep -E "^[0-9]+:" | wc -l
echo

# Test 5: V2 Church website with :claude suffix and extra fields
echo "TEST 5: V2 Church website (church_website_taco_v2.txt)"
echo "Expected: 7 agents with clean role descriptions"
echo "Result:"
count=$(parse_agent_specification church_website_taco_v2.txt | grep -E "^[0-9]+:" | wc -l)
echo "Count: $count"
# Check that V2 fields are not in role descriptions
if parse_agent_specification church_website_taco_v2.txt | grep -q "MEMORY_SHARE\|PARALLEL_WITH\|SUB_AGENTS\|THINKING_MODE"; then
    echo "ERROR: V2 fields found in role descriptions!"
else
    echo "SUCCESS: V2 fields properly filtered"
fi
echo

echo "=========================================="
echo "TEST SUITE COMPLETE"
echo "==========================================