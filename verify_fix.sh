#!/opt/homebrew/bin/bash
# Verify that the fix works correctly

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Verifying TACO Specification Detection Fix ===${NC}"
echo

# Test data file
DEBUG_FILE="/Users/louisxsheid/Dev/daedastream/test/cm2/.orchestrator/mother_output_debug.txt"

# Load the fixed function from the actual taco bin
TACO_BIN="/Users/louisxsheid/.local/taco/bin/taco"

# Extract just the check_for_complete_spec function
echo -e "${YELLOW}Extracting fixed function from TACO bin...${NC}"
awk '/^[[:space:]]*check_for_complete_spec\(\) {/,/^[[:space:]]*}$/' "$TACO_BIN" > temp_function.sh

# Add test scaffolding
cat > test_fixed_function.sh << 'EOF'
#!/opt/homebrew/bin/bash

# Mock variables needed by the function
SESSION_NAME="test"
ORCHESTRATOR_DIR="/tmp/test_orchestrator"
mkdir -p "$ORCHESTRATOR_DIR"

# Mock tmux capture-pane to return our test data
tmux() {
    if [[ "$1" == "capture-pane" ]]; then
        cat "/Users/louisxsheid/Dev/daedastream/test/cm2/.orchestrator/mother_output_debug.txt"
    fi
}

# Include the function
EOF

cat temp_function.sh >> test_fixed_function.sh

# Add test execution
cat >> test_fixed_function.sh << 'EOF'

# Run the test
if check_for_complete_spec; then
    echo "PASS: Specification detected"
    exit 0
else
    echo "FAIL: Specification not detected"
    exit 1
fi
EOF

chmod +x test_fixed_function.sh

echo -e "${YELLOW}Running fixed function test...${NC}"
if ./test_fixed_function.sh; then
    echo -e "${GREEN}✅ SUCCESS: The fixed function correctly detects the specification!${NC}"
else
    echo -e "${RED}❌ FAILURE: The fixed function still doesn't detect the specification${NC}"
fi

# Cleanup
rm -f temp_function.sh test_fixed_function.sh
rm -rf /tmp/test_orchestrator

echo
echo -e "${CYAN}=== Summary ===${NC}"
echo "The fix removes the requirement for 'PROJECT ANALYSIS' or 'AGENT SPECIFICATION'"
echo "markers and directly looks for AGENT_SPEC_START/END blocks."
echo
echo "This makes the detection more robust and works with the actual Mother output"
echo "format where the spec block is provided without those markers."
echo
echo -e "${YELLOW}Files updated:${NC}"
echo "  - /Users/louisxsheid/.local/taco/bin/taco (installed version)"
echo "  - /Users/louisxsheid/Dev/Daedastream/taco/taco/bin/taco (working copy)"