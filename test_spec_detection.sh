#!/opt/homebrew/bin/bash
# Test script for TACO specification detection logic

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== TACO Specification Detection Test ===${NC}"
echo

# Test file paths
DEBUG_FILE="/Users/louisxsheid/Dev/daedastream/test/cm2/.orchestrator/mother_output_debug.txt"
TEST_OUTPUT="test_spec_output.txt"

# Function to check for complete specification (copied from TACO)
check_for_complete_spec_original() {
    local capture="$1"
    local clean_capture=$(echo "$capture" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/│//g; s/╰//g; s/─//g; s/╯//g; s/⏺//g' | sed 's/[[:space:]]*$//')
    
    # Look for the last AGENT_SPEC_START that appears after Mother's analysis
    # Find position of "PROJECT ANALYSIS" or "AGENT SPECIFICATION" to ensure we get Mother's output
    local analysis_marker=$(echo "$clean_capture" | grep -n -E "(PROJECT ANALYSIS|AGENT SPECIFICATION)" | tail -1 | cut -d: -f1)
    
    if [ -n "$analysis_marker" ]; then
        # Extract content after the analysis marker
        local mother_output=$(echo "$clean_capture" | tail -n +$analysis_marker)
        
        if echo "$mother_output" | grep -i "AGENT_SPEC_START" && echo "$mother_output" | grep -i "AGENT_SPEC_END"; then
            # Get the last AGENT_SPEC block (in case there are examples before)
            local spec_content=$(echo "$mother_output" | awk '/AGENT_SPEC_START/{p=1} p; /AGENT_SPEC_END/{p=0}' | tail -n +2)
            if echo "$spec_content" | grep -E "AGENT:[0-9]+:"; then
                return 0
            fi
        fi
    fi
    return 1
}

# Test 1: Direct grep patterns
echo -e "${YELLOW}Test 1: Testing grep patterns on debug file${NC}"
echo -n "  Checking for AGENT_SPEC_START: "
if grep -i "AGENT_SPEC_START" "$DEBUG_FILE" > /dev/null; then
    echo -e "${GREEN}FOUND${NC}"
    grep -n -i "AGENT_SPEC_START" "$DEBUG_FILE" | head -3
else
    echo -e "${RED}NOT FOUND${NC}"
fi

echo -n "  Checking for AGENT_SPEC_END: "
if grep -i "AGENT_SPEC_END" "$DEBUG_FILE" > /dev/null; then
    echo -e "${GREEN}FOUND${NC}"
    grep -n -i "AGENT_SPEC_END" "$DEBUG_FILE" | head -3
else
    echo -e "${RED}NOT FOUND${NC}"
fi

echo -n "  Checking for AGENT: entries: "
if grep -E "AGENT:[0-9]+:" "$DEBUG_FILE" > /dev/null; then
    echo -e "${GREEN}FOUND${NC}"
    grep -n -E "AGENT:[0-9]+:" "$DEBUG_FILE" | head -3
else
    echo -e "${RED}NOT FOUND${NC}"
fi

echo

# Test 2: Check for PROJECT ANALYSIS or AGENT SPECIFICATION markers
echo -e "${YELLOW}Test 2: Testing analysis markers${NC}"
echo -n "  Checking for PROJECT ANALYSIS or AGENT SPECIFICATION: "
if grep -E "(PROJECT ANALYSIS|AGENT SPECIFICATION)" "$DEBUG_FILE" > /dev/null; then
    echo -e "${GREEN}FOUND${NC}"
    grep -n -E "(PROJECT ANALYSIS|AGENT SPECIFICATION)" "$DEBUG_FILE" | head -3
else
    echo -e "${RED}NOT FOUND (this might be the issue!)${NC}"
fi

echo

# Test 3: Run the original function
echo -e "${YELLOW}Test 3: Running original detection function${NC}"
capture=$(cat "$DEBUG_FILE")
if check_for_complete_spec_original "$capture"; then
    echo -e "  Result: ${GREEN}SPECIFICATION DETECTED${NC}"
else
    echo -e "  Result: ${RED}SPECIFICATION NOT DETECTED${NC}"
fi

echo

# Test 4: Simplified detection without analysis marker
echo -e "${YELLOW}Test 4: Testing simplified detection (no analysis marker)${NC}"
check_for_complete_spec_simple() {
    local capture="$1"
    local clean_capture=$(echo "$capture" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/│//g; s/╰//g; s/─//g; s/╯//g; s/⏺//g' | sed 's/[[:space:]]*$//')
    
    if echo "$clean_capture" | grep -i "AGENT_SPEC_START" > /dev/null && echo "$clean_capture" | grep -i "AGENT_SPEC_END" > /dev/null; then
        # Get the last AGENT_SPEC block
        local spec_content=$(echo "$clean_capture" | awk '/AGENT_SPEC_START/{p=1} p; /AGENT_SPEC_END/{p=0}')
        if echo "$spec_content" | grep -E "AGENT:[0-9]+:" > /dev/null; then
            return 0
        fi
    fi
    return 1
}

if check_for_complete_spec_simple "$capture"; then
    echo -e "  Result: ${GREEN}SPECIFICATION DETECTED${NC}"
else
    echo -e "  Result: ${RED}SPECIFICATION NOT DETECTED${NC}"
fi

echo

# Test 5: Extract and display the spec block
echo -e "${YELLOW}Test 5: Extracting specification block${NC}"
clean_capture=$(cat "$DEBUG_FILE" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/│//g; s/╰//g; s/─//g; s/╯//g; s/⏺//g' | sed 's/[[:space:]]*$//')
spec_block=$(echo "$clean_capture" | awk '/AGENT_SPEC_START/,/AGENT_SPEC_END/')

if [ -n "$spec_block" ]; then
    echo -e "  ${GREEN}Successfully extracted spec block:${NC}"
    echo "$spec_block" | head -10
    echo "  ..."
    agent_count=$(echo "$spec_block" | grep -E "AGENT:[0-9]+:" | wc -l)
    echo -e "  ${CYAN}Found $agent_count agents in specification${NC}"
else
    echo -e "  ${RED}Failed to extract spec block${NC}"
fi

echo

# Test 6: Debug the analysis marker issue
echo -e "${YELLOW}Test 6: Debugging analysis marker detection${NC}"
echo "  Looking for markers in file:"

# Show context around where we'd expect markers
echo "  First 50 lines of file:"
head -50 "$DEBUG_FILE" | grep -n -E "(PROJECT|ANALYSIS|SPECIFICATION|AGENT_SPEC)" | head -10

echo
echo -e "${CYAN}=== DIAGNOSIS ===${NC}"
echo
echo "The issue appears to be that the detection function is looking for"
echo "'PROJECT ANALYSIS' or 'AGENT SPECIFICATION' markers that don't exist"
echo "in the output. The Mother output starts directly with the spec block"
echo "without these markers."
echo
echo -e "${YELLOW}RECOMMENDATION:${NC} Modify the check_for_complete_spec() function to:"
echo "1. Make the analysis marker optional"
echo "2. Or remove the analysis marker requirement entirely"
echo "3. Or look for different markers that actually exist in the output"