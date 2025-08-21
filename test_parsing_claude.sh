#!/bin/bash

# Test parsing of actual Claude output with decorations
source /Users/louisxsheid/.local/share/taco/lib/taco-common.sh
source /Users/louisxsheid/.local/share/taco/lib/taco-agents.sh

echo "Testing parsing of Claude output with decorations..."
echo "=================================================="
echo

echo "1. Testing basic AWK extraction..."
echo "-----------------------------------"
awk '/AGENT_SPEC_START/,/AGENT_SPEC_END/' test_claude_output.txt
echo

echo "2. Testing with decorated marker (⏺ AGENT_SPEC_START)..."
echo "--------------------------------------------------------"
awk '/⏺ AGENT_SPEC_START/,/AGENT_SPEC_END/' test_claude_output.txt
echo

echo "3. Testing flexible pattern for start marker..."
echo "-----------------------------------------------"
awk '/AGENT_SPEC_START/,/AGENT_SPEC_END/' test_claude_output.txt | sed 's/^[>⏺⎿☐✽⏵│╭╮╰╯ ]*//; s/^[[:space:]]*//'
echo

echo "4. Running parse_agent_specification..."
echo "---------------------------------------"
parse_agent_specification test_claude_output.txt